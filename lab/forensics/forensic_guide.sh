#!/bin/bash
# ============================================================
# FORENSIC GUIDE — Sakura Tech Email Incident
# Automated forensics workflow script
# Run on: 113 jump-kali
# ============================================================

FORENSIC_DIR="/opt/forensics/cases/sakura_incident"
EVIDENCE_DIR="${FORENSIC_DIR}/evidence"
REPORT_DIR="${FORENSIC_DIR}/reports"
TIMELINE_DIR="${FORENSIC_DIR}/timeline"
LAB_ROOT="/tmp/lab"

# --- Step 1: Setup directory structure ---
setup() {
    echo "[FORENSIC] Setting up directory structure..."
    mkdir -p "$EVIDENCE_DIR" "$REPORT_DIR" "$TIMELINE_DIR"
    echo "[FORENSIC] Directory structure created at $FORENSIC_DIR"
}

# --- Step 2: Evidence Collection ---
collect() {
    echo "[FORENSIC] === EVIDENCE COLLECTION ==="
    echo ""

    echo "[1] Collecting mail.log..."
    mkdir -p "$EVIDENCE_DIR"
    scp -o StrictHostKeyChecking=no root@10.71.119.51:/var/log/mail.log "$EVIDENCE_DIR/mail.log" 2>/dev/null \
        || echo "[WARN] Could not collect mail.log via scp"

    echo "[2] Collecting dovecot.log..."
    scp -o StrictHostKeyChecking=no root@10.71.119.51:/var/log/dovecot.log "$EVIDENCE_DIR/dovecot.log" 2>/dev/null \
        || echo "[WARN] Could not collect dovecot.log"

    echo "[3] Collecting nginx access log..."
    scp -o StrictHostKeyChecking=no root@10.71.119.51:/var/log/nginx/access.log "$EVIDENCE_DIR/nginx_access.log" 2>/dev/null \
        || echo "[WARN] Could not collect nginx_access.log"

    echo "[4] Collecting Wazuh alerts..."
    scp -o StrictHostKeyChecking=no root@10.71.120.103:/var/ossec/logs/alerts/alerts.json "$EVIDENCE_DIR/wazuh_alerts.json" 2>/dev/null \
        || echo "[WARN] Could not collect wazuh_alerts.json"

    echo "[5] Collecting iRedAdmin audit log..."
    scp -o StrictHostKeyChecking=no root@10.71.119.51:/var/www/iredadmin/logs/iredadmin.log "$EVIDENCE_DIR/iredadmin.log" 2>/dev/null \
        || echo "[WARN] Could not collect iredadmin.log"

    echo "[6] Collecting simulation evidence files..."
    scp -o StrictHostKeyChecking=no -r root@10.71.119.51:/tmp/phishing_evidence/ "$EVIDENCE_DIR/simulation/" 2>/dev/null \
        || echo "[WARN] Could not collect simulation evidence"

    echo "[7] Hashing all evidence..."
    cd "$EVIDENCE_DIR"
    for f in *.log *.json *.eml *.txt 2>/dev/null; do
        [ -f "$f" ] || continue
        md5sum "$f" > "${f}.md5"
        sha256sum "$f" > "${f}.sha256"
        echo "    Hashed: $f"
    done

    echo ""
    echo "[8] Evidence collection complete!"
    ls -lh "$EVIDENCE_DIR"
}

# --- Step 3: Email Header Analysis ---
analyze_header() {
    local eml="${1:-${EVIDENCE_DIR}/simulation/phase1_phishing_email.eml}"
    echo "[FORENSIC] === EMAIL HEADER ANALYSIS ==="
    echo ""

    if [ ! -f "$eml" ]; then
        echo "[ERR] Email file not found: $eml"
        return 1
    fi

    echo "--- Received Chain (read bottom to top) ---"
    grep "^Received:" "$eml" | tac

    echo ""
    echo "--- Key Headers ---"
    echo "From:    $(grep -m1 '^From:' "$eml")"
    echo "To:      $(grep -m1 '^To:' "$eml")"
    echo "Subject: $(grep -m1 '^Subject:' "$eml")"
    echo "Date:    $(grep -m1 '^Date:' "$eml")"
    echo "Message-ID: $(grep -m1 '^Message-ID:' "$eml")"
    echo "Return-Path: $(grep -m1 '^Return-Path:' "$eml")"

    echo ""
    echo "--- Authentication Results ---"
    grep -i "spf\|dkim\|dmarc\|authentication-results" "$eml"

    echo ""
    echo "--- IPs Found ---"
    grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "$eml" | sort -u

    echo ""
    echo "--- Analysis Summary ---"
    local from_domain=$(grep -m1 '^From:' "$eml" | grep -oE '@[^>]+' | tr -d '@> ')
    echo "Sender domain: $from_domain"
    echo "This is likely a typosquat if domain differs from legitimate domain."
}

# --- Step 4: IP Investigation ---
investigate_ip() {
    local ip="${1:-185.220.101.47}"
    echo "[FORENSIC] === IP INVESTIGATION: $ip ==="
    echo ""

    echo "--- WHOIS ---"
    whois "$ip" 2>/dev/null | grep -E "^(OrgName|Country|City|NetName|NetRange|OriginAS|Netblock|Origin)" | head -15 \
        || echo "WHOIS lookup failed"

    echo ""
    echo "--- GeoIP ---"
    curl -s "https://ipinfo.io/${ip}/json" 2>/dev/null | python3 -m json.tool 2>/dev/null \
        || curl -s "http://ip-api.com/json/${ip}" 2>/dev/null | python3 -m json.tool 2>/dev/null \
        || echo "GeoIP lookup failed"

    echo ""
    echo "--- Reputation Check ---"
    echo "VirusTotal: https://www.virustotal.com/gui/ip-address/${ip}"
    echo "AbuseIPDB: https://www.abuseipdb.com/check/${ip}"
    echo "Cisco Talos: https://talosintelligence.com/reputation_center/${ip}"
}

# --- Step 5: SPF/DKIM/DMARC Analysis ---
analyze_auth() {
    local domain="${1:-sakura-vendor.com}"
    echo "[FORENSIC] === EMAIL AUTHENTICATION: $domain ==="
    echo ""

    echo "--- SPF Record ---"
    dig TXT "$domain" +short 2>/dev/null || echo "No SPF record"
    echo ""
    echo "Analysis: $(dig TXT "$domain" +short 2>/dev/null | grep -q '~all\|-all' && echo 'STRICT policy — domain does not authorize senders' || echo 'WARNING: Domain may allow unauthorized senders')"

    echo ""
    echo "--- DKIM Record ---"
    dig TXT "default._domainkey.${domain}" +short 2>/dev/null || echo "No DKIM record found"

    echo ""
    echo "--- DMARC Record ---"
    dig TXT "_dmarc.${domain}" +short 2>/dev/null || echo "No DMARC record found"

    echo ""
    echo "--- Summary ---"
    echo "If SPF=FAIL, DKIM=FAIL, DMARC=NONE: Email is likely PHISHING"
}

# --- Step 6: Timeline Building ---
build_timeline() {
    echo "[FORENSIC] === BUILDING INCIDENT TIMELINE ==="
    echo ""

    echo "| Time | Phase | Event | Source | MITRE |" > "${TIMELINE_DIR}/timeline.csv"
    echo "|-----|-------|-------|--------|-------|" >> "${TIMELINE_DIR}/timeline.csv"

    # Phase 1
    if [ -f "${EVIDENCE_DIR}/mail.log" ]; then
        grep -i "sakura-vendor.com" "${EVIDENCE_DIR}/mail.log" 2>/dev/null | head -5 | \
            awk -v phase="Phase 1: Phishing Email" -v mitre="T1566.002" \
            '{gsub(/\[|\]/,""); gsub(/  +/," "); print "| " $1 " " $2 " | " phase " | " $0 " | Postfix mail.log | " mitre " |"}' \
            >> "${TIMELINE_DIR}/timeline.csv"
    fi

    # Phase 2
    if [ -f "${EVIDENCE_DIR}/nginx_access.log" ]; then
        grep "login-sakura-vendor" "${EVIDENCE_DIR}/nginx_access.log" 2>/dev/null | head -3 | \
            awk -v phase="Phase 2: User Click" -v mitre="T1598" \
            '{print "| " $1 " | " phase " | " $0 " | Nginx access.log | " mitre " |"}' \
            >> "${TIMELINE_DIR}/timeline.csv"
    fi

    # Phase 3
    if [ -f "${EVIDENCE_DIR}/dovecot.log" ]; then
        grep "linhntt" "${EVIDENCE_DIR}/dovecot.log" 2>/dev/null | grep "185.220" | head -5 | \
            awk -v phase="Phase 3: Account Compromise" -v mitre="T1078" \
            '{print "| " $1 " " $2 " | " phase " | " $0 " | Dovecot auth log | " mitre " |"}' \
            >> "${TIMELINE_DIR}/timeline.csv"
    fi

    # Phase 4
    if [ -f "${EVIDENCE_DIR}/dovecot.log" ]; then
        grep "sieve\|redirect\|fileinto" "${EVIDENCE_DIR}/dovecot.log" 2>/dev/null | head -3 | \
            awk -v phase="Phase 4: Persistence" -v mitre="T1114.003" \
            '{print "| " $1 " " $2 " | " phase " | " $0 " | Dovecot sieve log | " mitre " |"}' \
            >> "${TIMELINE_DIR}/timeline.csv"
    fi

    echo "[FORENSIC] Timeline saved to: ${TIMELINE_DIR}/timeline.csv"
    echo ""
    column -t -s '|' "${TIMELINE_DIR}/timeline.csv" 2>/dev/null || cat "${TIMELINE_DIR}/timeline.csv"
}

# --- Step 7: Wazuh Alert Analysis ---
analyze_wazuh() {
    echo "[FORENSIC] === WAZUH ALERT ANALYSIS ==="
    echo ""

    if [ ! -f "${EVIDENCE_DIR}/wazuh_alerts.json" ]; then
        echo "[ERR] Wazuh alerts not found"
        return 1
    fi

    echo "--- Alerts by Severity ---"
    python3 -c "
import json, sys
with open('${EVIDENCE_DIR}/wazuh_alerts.json') as f:
    alerts = [json.loads(line) for line in f if line.strip()]
print(f'Total alerts: {len(alerts)}')
levels = {}
for a in alerts:
    lvl = a.get('rule', {}).get('level', 0)
    levels[lvl] = levels.get(lvl, 0) + 1
for lvl in sorted(levels.keys(), reverse=True):
    print(f'  Level {lvl}: {levels[lvl]} alerts')
" 2>/dev/null || echo "Python analysis not available"

    echo ""
    echo "--- Critical Alerts (Level 12+) ---"
    python3 -c "
import json
with open('${EVIDENCE_DIR}/wazuh_alerts.json') as f:
    for line in f:
        if not line.strip(): continue
        try:
            a = json.loads(line)
            lvl = a.get('rule', {}).get('level', 0)
            if lvl >= 12:
                print(f'  [{lvl}] {a.get(\"rule\", {}).get(\"description\", \"?\")}')
                print(f'         IP: {a.get(\"srcip\", \"?\")} | Time: {a.get(\"timestamp\", \"?\")}')
                print(f'         MITRE: {a.get(\"mitre\", {}).get(\"id\", [\"?\"])}')
                print()
        except: pass
" 2>/dev/null || grep -E '"level":1[2-9]|"level":[2-9][0-9]' "${EVIDENCE_DIR}/wazuh_alerts.json" | head -20
}

# --- Step 8: Generate Report ---
generate_report() {
    echo "[FORENSIC] === GENERATING FORENSIC REPORT ==="

    local report="${REPORT_DIR}/incident_report_$(date +%Y%m%d).md"

    cat > "$report" <<'REPORT_EOF'
# FORENSIC REPORT — Sakura Tech Email Incident
# Case: "Cái Bẫy Hoàn Hảo"
# Date: $(date '+%Y-%m-%d')
# Examiner: [Your Name]
# Case ID: ST-$(date +%Y%m%d%H%M)

## 1. EXECUTIVE SUMMARY

This report documents a Business Email Compromise (BEC) attack targeting Sakura Tech Co., Ltd.
The attack followed a 6-phase chain: Phishing → Credential Theft → Account Compromise →
Persistence → BEC Fraud → Evidence Deletion.

**Key Finding**: An attacker compromised the account of Nguyen Thi Linh (linhntt@sakuratech.local)
through a phishing email, then used the account to request fraudulent bank account changes,
resulting in a potential financial loss.

## 2. INCIDENT TIMELINE

[Insert timeline from timeline.csv here]

## 3. EVIDENCE ANALYSIS

### 3.1 Email Header Analysis

**Phishing Email** (Phase 1):
- From: support@sakura-vendor.com (TYPOSQUAT)
- Domain: sakura-vendor.com (legitimate is .net)
- SPF: FAIL — sender IP not authorized
- DKIM: FAIL — no valid signature
- DMARC: NONE — no protection policy
- Source IP: 185.220.101.47 (Tor exit node, Germany)

**BEC Email** (Phase 5):
- From: linhntt@sakuratech.local (LEGITIMATE)
- SPF/DKIM/DMARC: PASS (because sent from legitimate server)
- BUT: Sent from attacker session at 185.220.101.47
- **This is why BEC is so dangerous — email appears legitimate**

### 3.2 IP Investigation

| IP | Type | Location | Reputation |
|----|------|----------|------------|
| 185.220.101.47 | Tor Exit | Germany | Malicious (AbuseIPDB 95%) |
| 10.71.121.100 | Internal | Victim workstation | Legitimate |
| 10.71.119.51 | Internal | Mail server | Legitimate |

### 3.3 Authentication Analysis

| Check | Domain | Result | Interpretation |
|-------|--------|--------|---------------|
| SPF | sakura-vendor.com | FAIL | Sender IP not authorized |
| DKIM | sakura-vendor.com | FAIL | No valid signature |
| DMARC | sakura-vendor.com | NONE | No protection policy |
| SPF | sakuratech.local | PASS | Legitimate sender |
| DKIM | sakuratech.local | PASS | Valid signature |
| DMARC | sakuratech.local | PASS | Protection active |

## 4. CHAIN OF CUSTODY

All evidence has been hashed for integrity:

| File | MD5 | SHA256 |
|------|-----|--------|
REPORT_EOF

    # Append hash table
    cd "$EVIDENCE_DIR"
    for f in *.md5 2>/dev/null; do
        base="${f%.md5}"
        echo "| $base | $(cat $f | awk '{print $1}') | $(cat ${base}.sha256 2>/dev/null | awk '{print $1}') |" >> "$report"
    done

    cat >> "$report" <<'REPORT_EOF'

## 5. ROOT CAUSE ANALYSIS

1. **Phishing Email Bypassed Gateway**: The email from sakura-vendor.com was not
   flagged because strict SPF/DKIM/DMARC filtering was not enabled on the mail gateway.

2. **User Interaction**: The victim clicked the phishing link without verifying
   the domain (sakura-vendor.com vs sakura-vendor.net).

3. **No MFA**: The compromised account did not have multi-factor authentication enabled,
   allowing the attacker to log in with just username + password.

4. **Mail Rule Persistence**: The attacker created a mail forwarding rule to
   automatically capture all financial-related emails before the victim could see them.

5. **BEC Exploitation**: The attacker used the legitimate email account to send
   credible financial requests, bypassing all technical controls.

## 6. RECOMMENDATIONS

### Immediate (0-24 hours)
- [ ] Disable compromised account and force password reset
- [ ] Remove malicious mail rules from all accounts
- [ ] Block IP 185.220.101.47 and Tor exit node ranges at firewall
- [ ] Review and revoke any suspicious sessions

### Short-term (1-7 days)
- [ ] Enable strict SPF/DKIM/DMARC on all domains
- [ ] Enable MFA for all mail accounts
- [ ] Configure email gateway to block typosquat domains
- [ ] Train all staff on phishing email identification
- [ ] Conduct a phishing simulation campaign

### Long-term (1-4 weeks)
- [ ] Implement SEG (Secure Email Gateway)
- [ ] Deploy DMARC with reject policy
- [ ] Set up continuous SIEM monitoring with BEC rules
- [ ] Establish BEC response procedure
- [ ] Regular security awareness training

## 7. CONCLUSION

The attack chain was technically sophisticated, leveraging typosquat domains, Tor
networks, and legitimate email infrastructure to bypass security controls. However,
the attack left extensive digital traces in server logs, SIEM alerts, and
authentication logs — demonstrating that with proper logging and monitoring,
such attacks CAN be detected and investigated.

The key lesson: Technical controls alone are not sufficient. Security awareness
training and multi-factor authentication are critical defenses against BEC.

---
**Report Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Examiner:** [Your Name]
**Classification:** INTERNAL USE ONLY
REPORT_EOF

    echo "[FORENSIC] Report saved to: $report"
}

# --- Main menu ---
case "${1:-menu}" in
    setup)    setup ;;
    collect)  collect ;;
    header)   analyze_header "${2:-}" ;;
    ip)      investigate_ip "${2:-185.220.101.47}" ;;
    auth)    analyze_auth "${2:-sakura-vendor.com}" ;;
    timeline) build_timeline ;;
    wazuh)   analyze_wazuh ;;
    report)  generate_report ;;
    all)
        setup
        collect
        build_timeline
        analyze_wazuh
        generate_report
        echo ""
        echo "[FORENSIC] Full forensics workflow complete!"
        echo "[FORENSIC] Reports in: $REPORT_DIR"
        echo "[FORENSIC] Evidence in: $EVIDENCE_DIR"
        echo "[FORENSIC] Timeline in: $TIMELINE_DIR"
        ;;
    *)
        echo "Forensic Toolkit — Sakura Tech Incident"
        echo "Usage: $0 {setup|collect|header|ip|auth|timeline|wazuh|report|all}"
        echo ""
        echo "  setup    - Create directory structure"
        echo "  collect  - Collect all evidence from mail servers"
        echo "  header   [file] - Analyze email header"
        echo "  ip      [IP]     - Investigate IP address"
        echo "  auth    [domain] - Check SPF/DKIM/DMARC"
        echo "  timeline          - Build incident timeline"
        echo "  wazuh             - Analyze Wazuh alerts"
        echo "  report            - Generate forensic report"
        echo "  all               - Run complete workflow"
        ;;
esac
