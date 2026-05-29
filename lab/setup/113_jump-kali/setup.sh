#!/bin/bash
# ============================================================
# SETUP: 113 jump-kali — Kali Linux Forensics Station
# OS: Kali Linux 2024.x (VM)
# Role: Forensic analyst workstation
# IP: 10.71.120.113
# ============================================================

set -e

echo "[113] === Kali Forensics Station Setup ==="

# --- Network ---
cat > /etc/netplan/99-cloud-init.yaml <<'NETCFG'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 10.71.120.113/24
      nameservers:
        addresses:
          - 10.71.120.1
          - 8.8.8.8
      routes:
        - to: default
          via: 10.71.120.1
NETCFG

netplan apply

# --- Update system ---
apt-get update && apt-get upgrade -y

# --- Install forensics tools ---
echo "[113] Installing forensics and analysis tools..."

apt-get install -y \
    wireshark tshark \
    volatility3 \
    autopsy \
    md5deep sha256deep \
    sleuthkit \
    autopsy \
    ghex binwalk \
    foremost \
    strings \
    grep sed awk \
    whois dnsutils \
    nmap netcat \
    tcpdump \
    curl wget \
    git \
    python3-pip \
    jq \
    hashcat \
    net-tools \
    iputils-ping

# --- Install GoPhish CLI tool ---
pip3 install gophish-cli 2>/dev/null || pip3 install requests || true

# --- Install email analysis tools ---
apt-get install -y \
    mhonarc mailutils \
    html2text

# --- Create forensics workspace ---
mkdir -p /opt/forensics/evidence
mkdir -p /opt/forensics/cases/sakura_incident
mkdir -p /opt/forensics/reports
mkdir -p /opt/forensics/timeline

# --- Create forensics script library ---
cat > /opt/forensics/forensic_toolkit.sh <<'FORENSIC_TOOLKIT'
#!/bin/bash
# ============================================================
# DIGITAL FORENSIC TOOLKIT — Sakura Tech Incident
# Run on: 113 jump-kali
# ============================================================

CASE_DIR="/opt/forensics/cases/sakura_incident"
EVIDENCE_DIR="${CASE_DIR}/evidence"
TIMELINE_DIR="${CASE_DIR}/timeline"
MAIL_SERVER="10.71.119.51"
MAIL_USER="postmaster"
MAIL_PASS="Intern#2026"

mkdir -p "$EVIDENCE_DIR" "$TIMELINE_DIR"

echo "=============================================="
echo " SAKURA TECH — EMAIL INCIDENT FORENSICS "
echo "=============================================="
echo ""

# --- Step 1: Collect Evidence from Mail Server ---
collect_evidence() {
    echo "[FORENSIC] Step 1: Collecting evidence from mail server..."

    echo "[FORENSIC]   Collecting Postfix mail log..."
    sshpass -p "$MAIL_PASS" scp -o StrictHostKeyChecking=no \
        "${MAIL_USER}@${MAIL_SERVER}:/var/log/mail.log" \
        "${EVIDENCE_DIR}/mail.log" 2>/dev/null || \
    ssh "${MAIL_USER}@${MAIL_SERVER}" "cat /var/log/mail.log" > "${EVIDENCE_DIR}/mail.log" 2>/dev/null

    echo "[FORENSIC]   Collecting Dovecot auth log..."
    ssh "${MAIL_USER}@${MAIL_SERVER}" "cat /var/log/dovecot.log" > "${EVIDENCE_DIR}/dovecot.log" 2>/dev/null

    echo "[FORENSIC]   Collecting Nginx access log..."
    ssh "${MAIL_USER}@${MAIL_SERVER}" "cat /var/log/nginx/access.log" > "${EVIDENCE_DIR}/nginx_access.log" 2>/dev/null

    echo "[FORENSIC]   Collecting Wazuh alerts..."
    curl -s -k "https://${MAIL_SERVER}/api/v1/alerts" -u "admin:WazuhLab2026!" \
        > "${EVIDENCE_DIR}/wazuh_alerts.json" 2>/dev/null || \
    ssh "${MAIL_USER}@${MAIL_SERVER}" "cat /var/ossec/logs/alerts/alerts.json" > "${EVIDENCE_DIR}/wazuh_alerts.json" 2>/dev/null || true

    echo "[FORENSIC]   Hashing all evidence files..."
    cd "$EVIDENCE_DIR"
    for f in *.log *.json; do
        [ -f "$f" ] || continue
        md5sum "$f" > "${f}.md5"
        sha256sum "$f" > "${f}.sha256"
        echo "[FORENSIC]   Hashed: $f"
    done

    echo "[FORENSIC] Evidence collection complete."
}

# --- Step 2: Analyze Email Header ---
analyze_email_header() {
    echo ""
    echo "[FORENSIC] Step 2: Analyzing email headers..."

    local eml_file="$1"
    if [ ! -f "$eml_file" ]; then
        echo "[FORENSIC] ERROR: Email file not found: $eml_file"
        return 1
    fi

    echo "[FORENSIC] === Email Header Analysis ==="

    # Extract Received chain
    echo ""
    echo "[FORENSIC] Received chain (read bottom to top):"
    grep -A 100 "^Received:" "$eml_file" | head -20

    # Extract key headers
    echo ""
    echo "[FORENSIC] From: $(grep -m1 '^From:' "$eml_file")"
    echo "[FORENSIC] To: $(grep -m1 '^To:' "$eml_file")"
    echo "[FORENSIC] Subject: $(grep -m1 '^Subject:' "$eml_file")"
    echo "[FORENSIC] Date: $(grep -m1 '^Date:' "$eml_file")"
    echo "[FORENSIC] Message-ID: $(grep -m1 '^Message-ID:' "$eml_file")"
    echo "[FORENSIC] Return-Path: $(grep -m1 '^Return-Path:' "$eml_file")"

    # Extract IP from Received headers
    echo ""
    echo "[FORENSIC] IPs found in Received headers:"
    grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "$eml_file" | sort -u
}

# --- Step 3: IP Investigation ---
investigate_ip() {
    local ip="$1"
    echo ""
    echo "[FORENSIC] Step 3: Investigating IP $ip..."

    # WHOIS lookup
    echo ""
    echo "[FORENSIC] WHOIS lookup:"
    whois "$ip" 2>/dev/null | grep -E "^(OrgName|Country|City|NetName|NetRange|OriginAS|Abuse)" | head -10

    # GeoIP lookup
    echo ""
    echo "[FORENSIC] GeoIP lookup:"
    curl -s "https://ipinfo.io/${ip}/json" 2>/dev/null | jq '.' || \
    curl -s "http://ip-api.com/json/${ip}" 2>/dev/null | jq '.'

    # VirusTotal check
    echo ""
    echo "[FORENSIC] VirusTotal reputation:"
    echo "[FORENSIC] (Add your VT API key to check)"
    echo "[FORENSIC] https://www.virustotal.com/gui/ip-address/${ip}"

    # AbuseIPDB
    echo ""
    echo "[FORENSIC] AbuseIPDB:"
    echo "[FORENSIC] https://www.abuseipdb.com/check/${ip}"
}

# --- Step 4: SPF/DKIM/DMARC Analysis ---
analyze_email_security() {
    local domain="$1"
    echo ""
    echo "[FORENSIC] Step 4: Email security analysis for $domain..."

    echo ""
    echo "[FORENSIC] SPF Record:"
    dig TXT "$domain" +short 2>/dev/null | grep -i spf || echo "No SPF record found"

    echo ""
    echo "[FORENSIC] DKIM Record:"
    dig TXT "default._domainkey.${domain}" +short 2>/dev/null || echo "No DKIM record found"

    echo ""
    echo "[FORENSIC] DMARC Record:"
    dig TXT "_dmarc.${domain}" +short 2>/dev/null || echo "No DMARC record found"

    echo ""
    echo "[FORENSIC] Analysis:"
    echo "[FORENSIC] - SPF FAIL: Email sender not authorized by domain"
    echo "[FORENSIC] - DKIM FAIL: Email not signed or signature invalid"
    echo "[FORENSIC] - DMARC NONE: Domain has no protection policy"
}

# --- Step 5: Build Timeline ---
build_timeline() {
    echo ""
    echo "[FORENSIC] Step 5: Building incident timeline..."

    echo "| Timestamp | Event | Source | Evidence |" > "${TIMELINE_DIR}/timeline.csv"
    echo "|---|---|---|---|" >> "${TIMELINE_DIR}/timeline.csv"

    # Parse mail log for phishing email
    if [ -f "${EVIDENCE_DIR}/mail.log" ]; then
        grep -i "sakura-vendor.com" "${EVIDENCE_DIR}/mail.log" | \
            awk '{print "| " $1 " " $2 " | Phishing email sent via " $6 " | Postfix mail.log | " $0 " |"}' \
            >> "${TIMELINE_DIR}/timeline.csv"
    fi

    # Parse dovecot for login events
    if [ -f "${EVIDENCE_DIR}/dovecot.log" ]; then
        grep "Login.*linhntt" "${EVIDENCE_DIR}/dovecot.log" | \
            awk '{print "| " $1 " " $2 " | Login attempt | Dovecot | " $0 " |"}' \
            >> "${TIMELINE_DIR}/timeline.csv"
    fi

    echo ""
    echo "[FORENSIC] Timeline saved to: ${TIMELINE_DIR}/timeline.csv"
    cat "${TIMELINE_DIR}/timeline.csv"
}

# --- Step 6: Generate Report ---
generate_report() {
    echo ""
    echo "[FORENSIC] Step 6: Generating forensic report..."

    cat > "${CASE_DIR}/forensic_report.md" <<'REPORT'
# FORENSIC REPORT — Sakura Tech Email Incident
# Case: "Cái Bẫy Hoàn Hảo"
# Date: 2026
# Examiner: [Your Name]

## Executive Summary
[Describe the incident overview]

## Timeline of Events

## Evidence Analysis

### Email Header Analysis
### IP Investigation
### SPF/DKIM/DMARC Findings

## Indicators of Compromise (IOC)

### Domains
### IP Addresses
### Email Addresses

## MITRE ATT&CK Mapping

## Chain of Custody

## Conclusions

## Recommendations
REPORT

    echo "[FORENSIC] Report generated: ${CASE_DIR}/forensic_report.md"
}

# Menu
case "${1:-menu}" in
    collect)   collect_evidence ;;
    header)    analyze_email_header "${2:-${EVIDENCE_DIR}/phishing_email.eml}" ;;
    ip)       investigate_ip "${2:-185.220.101.47}" ;;
    security) analyze_email_security "${2:-sakura-vendor.com}" ;;
    timeline) build_timeline ;;
    report)   generate_report ;;
    *)
        echo "Usage: $0 {collect|header|ip|security|timeline|report}"
        echo "  collect   - Collect evidence from mail server"
        echo "  header    - Analyze email header file"
        echo "  ip <IP>   - Investigate IP address"
        echo "  security  - Check SPF/DKIM/DMARC for domain"
        echo "  timeline  - Build incident timeline"
        echo "  report    - Generate forensic report"
        ;;
esac
FORENSIC_TOOLKIT

chmod +x /opt/forensics/forensic_toolkit.sh

# --- Install sshpass for automated SCP ---
apt-get install -y sshpass 2>/dev/null || true

# --- Create alias for easy access ---
echo 'alias forensic="/opt/forensics/forensic_toolkit.sh"' >> ~/.bashrc
echo 'alias case="cd /opt/forensics/cases/sakura_incident"' >> ~/.bashrc

echo "[113] === Setup Complete ==="
echo "[113] IP: 10.71.120.113"
echo "[113] Forensics toolkit: /opt/forensics/forensic_toolkit.sh"
echo "[113] Case directory: /opt/forensics/cases/sakura_incident"
echo ""
echo "[113] Usage:"
echo "[113]   forensic collect          # Collect all evidence"
echo "[113]   forensic header <file>     # Analyze email header"
echo "[113]   forensic ip <IP>           # Investigate IP"
echo "[113]   forensic security <domain> # Check SPF/DKIM/DMARC"
echo "[113]   forensic timeline          # Build event timeline"
echo "[113]   forensic report            # Generate report"
echo ""
echo "[113] NOTE: Change SSH passwords and Wazuh keys after setup!"
