#!/bin/bash
# ============================================================
# SIMULATION LAUNCHER — "Cái Bẫy Hoàn Hảo"
# Sakura Tech Co. — Email Phishing BEC Simulation
#
# Run this script from 107 dmz-mail (postmaster account)
# or from the attacker simulation node
#
# Usage: ./run_all_phases.sh [--phase N] [--delay SEC]
#   --phase N : Run from phase N only (1-6)
#   --delay SEC : Delay between phases in seconds (default: interactive)
#
# Prerequisites:
#   - iRedMail installed on 10.71.119.51
#   - GoPhish installed on 10.71.119.101
#   - Users created: linhntt, ducmh, hoangnt, phongketoan
#   - Wazuh agent running on 107 and 100
# ============================================================

set -e

# --- Configuration ---
MAIL_SERVER="10.71.119.51"
MAIL_USER="postmaster"
MAIL_PASS="Intern#2026"
GOPHISH_SERVER="10.71.119.101"
GOPHISH_PORT="3333"
GOPHISH_API_KEY=""  # Set after first login: ./gophish
VICTIM_EMAIL="linhntt@sakuratech.local"
VICTIM_PASS="Victim@2026!"
VICTIM_IP="10.71.121.100"
ATTACKER_IP="185.220.101.47"
ATTACKER_EMAIL="attacker@protonmail.com"
PHISHING_DOMAIN="sakura-vendor.com"
PHISHING_SENDER="support@sakura-vendor.com"
TRACKING_ID="sakura$(date +%s)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC} $1"; }
phase() { echo -e "\n${RED}==============================================${NC}"; echo -e "${RED}  PHASE $1: $2${NC}"; echo -e "${RED}==============================================${NC}\n"; }

# --- Parse arguments ---
START_PHASE=1
INTERACTIVE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --phase)
            START_PHASE="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --delay)
            PHASE_DELAY="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --api-key)
            GOPHISH_API_KEY="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║        PHISHLAB — SAKURA TECH INCIDENT SIMULATION       ║"
echo "║              'Cái Bẫy Hoàn Hảo'                       ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Mail Server : $MAIL_SERVER"
echo "║  GoPhish     : $GOPHISH_SERVER:$GOPHISH_PORT"
echo "║  Victim      : $VICTIM_EMAIL"
echo "║  Attacker IP : $ATTACKER_IP"
echo "║  Tracking ID : $TRACKING_ID"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

if [ -z "$GOPHISH_API_KEY" ]; then
    warn "GoPhish API key not set. Phase 1 will simulate SMTP only."
    warn "Set with: --api-key <your_gophish_api_key>"
fi

confirm() {
    if [ "$INTERACTIVE" = true ]; then
        read -p "  Press ENTER to start Phase $1 ($2)..."
    else
        log "Starting Phase $1: $2"
        [ -n "$PHASE_DELAY" ] && sleep "$PHASE_DELAY"
    fi
}

# ===========================================================
# PHASE 1: Email Phishing
# ===========================================================
phase 1 "EMAIL PHISHING — Gửi email từ domain giả sakura-vendor.com"

confirm 1 "Email Phishing"
log "Simulating phishing email sent from $PHISHING_DOMAIN..."
log "Target: $VICTIM_EMAIL"
log "Sender: $PHISHING_SENDER"

# Inject fake phishing email into mail log (simulating SPF/DKIM/DMARC failure)
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/log/mail.log" << 'MAILLOG_ENTRY'
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[$$]: NOQUEUE: reject: RCPT from unknown[185.220.101.47]: 450 4.7.1 Client host rejected: cannot find your reverse hostname, [185.220.101.47]; from=<support@sakura-vendor.com> to=<linhntt@sakuratech.local> proto=SMTP helo=<mail.sakura-vendor.com>
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[$$]: NOQUEUE: reject: RCPT from mail.sakura-vendor.com[185.220.101.47]: 454 4.7.1 <support@sakura-vendor.com>: Sender address rejected: not owned by user postmaster@sakuratech.local; from=<support@sakura-vendor.com> to=<linhntt@sakuratech.local> proto=SMTP
$(date '+%b %d %H:%M:%S') dmz-mail postfix/cleanup[$$]: message-id=<phish-$(date +%s)@sakura-vendor.com>
$(date '+%b %d %H:%M:%S') dmz-mail postfix/qmgr[$$]: mail queue entry created
$(date '+%b %d %H:%M:%S') dmz-mail postfix/qmgr[$$]: queue active
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[$$]: <mail.sakura-vendor.com>[185.220.101.47]: EHLO mail.sakura-vendor.com
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[$$]: EHLO from=<support@sakura-vendor.com>
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[$$]: mail from=<support@sakura-vendor.com> size=4280
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[$$]: rcpt to=<linhntt@sakuratech.local>
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[$$]: data
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[$$]: status=sent (delivered to mailbox)
MAILLOG_ENTRY

# Create a fake .eml file for forensics
mkdir -p /tmp/phishing_evidence
cat > "/tmp/phishing_evidence/phase1_phishing_email.eml" << 'EOT'
Return-Path: <support@sakura-vendor.com>
Received: from mail.sakura-vendor.com (mail.sakura-vendor.com [185.220.101.47])
        by dmz-mail.sakuratech.local with SMTP id ABC123DEF456
        for <linhntt@sakuratech.local>;
        Mon, 29 May 2026 09:00:00 +0700 (ICT)
Received-SPF: FAIL (domain does not designate 185.220.101.47 as permitted sender)
DKIM-Signature: v=1; a=rsa-sha256; d=sakura-vendor.com; s=default;
        h=from:to:subject:date:message-id;
Received: from [10.0.0.1] (mail.sakura-vendor.com [185.220.101.47])
        by mail.sakura-vendor.com with ESMTP id XYZ789
        for <linhntt@sakuratech.local>;
        Mon, 29 May 2026 09:00:00 +0000
From: "Sakura Vendor Support" <support@sakura-vendor.com>
To: linhntt@sakuratech.local
Subject: [KHẨN] Nâng cấp hệ thống thanh toán — Xác nhận ngay trước 17:00 hôm nay
Date: Mon, 29 May 2026 09:00:00 +0700
Message-ID: <phish-1716954000@sakura-vendor.com>
X-Mailer: PHPMailer 5.2.23
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="----=_Part_12345"

[Email body with phishing link: http://login-sakura-vendor.com/track/click/TRACKING_ID]
EOT

# Create SPF/DKIM/DMARC analysis results
cat > "/tmp/phishing_evidence/phase1_spf_dkim_dmarc.txt" << 'SPF_RESULT'
=== SPF RECORD CHECK ===
Domain: sakura-vendor.com
TXT Record: v=spf1 -all
Result: FAIL
Explanation: Domain has strict SPF policy (-all), 
            meaning NO server is authorized to send email on behalf of this domain.
            185.220.101.47 is NOT authorized.

=== DKIM RECORD CHECK ===
Domain: sakura-vendor.com
DKIM Selector: default._domainkey
Result: NONE / FAIL
Explanation: No DKIM record found or signature is invalid.
            Email was NOT signed by the domain.

=== DMARC RECORD CHECK ===
Domain: sakura-vendor.com
_dmarc TXT Record: (not found)
Result: NONE
Explanation: Domain has NO DMARC policy.
            This means no protection against email spoofing.

=== CONCLUSION ===
This email is PHISHING:
  - Sender domain is a typosquat (sakura-vendor.com vs sakura-vendor.net)
  - SPF: FAIL — sender IP not authorized
  - DKIM: FAIL — no valid signature
  - DMARC: NONE — no protection policy configured
SPF_RESULT

# Also inject into Wazuh alerts
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/ossec/logs/alerts/alerts.json" << 'WAZUH_ALERT'
{"timestamp":"2026-05-29T09:00:00Z","rule":{"level":10,"id":"100006","description":"[Sakura] PHISHING ALERT: Email from typosquat domain sakura-vendor.com detected"},"full_log":"May 29 09:00:00 dmz-mail postfix/smtp: NOQUEUE: reject: RCPT from mail.sakura-vendor.com[185.220.101.47]","srcip":"185.220.101.47","dstip":"10.71.119.51","src_port":12345,"dst_port":25,"srcuser":"support@sakura-vendor.com","dstuser":"linhntt@sakuratech.local","location":"10.71.119.51","mitre":{"id":["T1566.002"]}}
{"timestamp":"2026-05-29T09:00:00Z","rule":{"level":10,"id":"100007","description":"[Sakura] EMAIL SECURITY FAIL: SPF/DKIM/DMARC failure detected"},"full_log":"May 29 09:00:00 dmz-mail postfix/smtp: Received-SPF: FAIL"}
WAZUH_ALERT

ok "Phase 1: Phishing email simulated"
ok "Log entries injected into Postfix mail.log"
ok "Fake .eml file created for forensics: /tmp/phishing_evidence/phase1_phishing_email.eml"
ok "Wazuh alerts generated"
echo ""
info "GoPhish simulation (if API key available):"
info "  Campaign: Sakura Tech - Payment System Security Update"
info "  Template: Sakura Vendor Payment System Upgrade"
info "  Landing: http://10.71.119.101:8080/track/click/$TRACKING_ID"
info ""
info "DNS Query that would be logged:"
info "  Victim queries: login-sakura-vendor.com → 10.71.119.101"

# ===========================================================
# PHASE 2: User Interaction
# ===========================================================
if [ "$START_PHASE" -le 2 ]; then
phase 2 "USER INTERACTION — Victim clicks link"
confirm 2 "User Interaction"

log "Simulating victim clicking phishing link..."

# Simulate DNS query from victim
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/log/mail.log" << 'DNS_LOG'
$(date '+%b %d %H:%M:%S') dmz-mail named[PID]: query: login-sakura-vendor.com IN A + (10.71.121.1)
$(date '+%b %d %H:%M:%S') dmz-mail named[PID]: client @[10.71.121.100]: query: login-sakura-vendor.com IN A + (10.71.121.1)
DNS_LOG

# Simulate web proxy log entry
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/log/nginx/access.log" << 'NGINX_LOG'
10.71.121.100 - - [29/May/2026:09:15:00 +0700] "GET /track/click/$TRACKING_ID HTTP/1.1" 302 0 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "-"
10.71.121.100 - - [29/May/2026:09:15:02 +0700] "GET / HTTP/1.1" 200 4280 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "-"
10.71.121.100 - - [29/May/2026:09:15:30 +0700] "POST /submit HTTP/1.1" 200 256 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "-"
NGINX_LOG

# Inject Wazuh alerts for Phase 2
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/ossec/logs/alerts/alerts.json" << 'WAZUH_P2'
{"timestamp":"2026-05-29T09:15:00Z","rule":{"level":8,"id":"100006","description":"[Sakura] User clicked phishing link"},"full_log":"DNS query to suspicious domain: login-sakura-vendor.com","srcip":"10.71.121.100","mitre":{"id":["T1566.002"]}}
{"timestamp":"2026-05-29T09:15:00Z","rule":{"level":8,"id":"100008","description":"[Sakura] WEBMAIL ACCESS: User accessed phishing page"},"full_log":"GET /track/click/$TRACKING_ID from 10.71.121.100","srcip":"10.71.121.100"}
WAZUH_P2

# Browser history simulation on victim
ssh "root@$VICTIM_IP" "echo >> /root/.bash_history" << 'HISTORY'
echo "[$(date)] Opened email from support@sakura-vendor.com"
echo "[$(date)] Clicked link: http://login-sakura-vendor.com/track/click/$TRACKING_ID"
echo "[$(date)] Entered credentials on phishing page"
echo "[$(date)] Submitted form"
HISTORY

ok "Phase 2: User interaction simulated"
ok "DNS query logged: login-sakura-vendor.com"
ok "Web access logged in Nginx access.log"
ok "Wazuh alert generated: suspicious DNS query"
fi

# ===========================================================
# PHASE 3: Account Compromise
# ===========================================================
if [ "$START_PHASE" -le 3 ]; then
phase 3 "ACCOUNT COMPROMISE — Attacker login từ IP nước ngoài"
confirm 3 "Account Compromise"

log "Simulating attacker login from $ATTACKER_IP (Tor exit node, Germany)..."

# Inject attacker login into Dovecot log
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/log/dovecot.log" << 'DOVECOT_LOG'
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: imap-login: Info: Login: user=<linhntt@sakuratech.local>, method=PLAIN, rip=10.71.121.100, lip=10.71.119.51, mpid=1001, secured, session=<victim-session-001>
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: imap-login: Info: Login: user=<linhntt@sakuratech.local>, method=PLAIN, rip=185.220.101.47, lip=10.71.119.51, mpid=1002, secured, session=<attacker-session-002>
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: imap: Info: Disconnect: user=<linhntt@sakuratech.local>, method=PLAIN, rip=185.220.101.47, lip=10.71.119.51, mpid=1002, session=<attacker-session-002>
DOVECOT_LOG

# Inject Wazuh alert for Phase 3
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/ossec/logs/alerts/alerts.json" << 'WAZUH_P3'
{"timestamp":"2026-05-29T10:30:00Z","rule":{"level":12,"id":"100002","description":"[Sakura] Suspicious IMAP login from known Tor exit node"},"full_log":"May 29 10:30:00 dmz-mail dovecot: imap-login: Login: user=<linhntt@sakuratech.local>, method=PLAIN, rip=185.220.101.47","srcip":"185.220.101.47","dstip":"10.71.119.51","dstuser":"linhntt@sakuratech.local","location":"Germany (Tor exit node)","mitre":{"id":["T1078"]}}
{"timestamp":"2026-05-29T10:30:02Z","rule":{"level":14,"id":"100003","description":"[Sakura] POSSIBLE BEC: linhntt mailbox accessed from suspicious IP"},"full_log":"May 29 10:30:02 dmz-mail dovecot: imap-login: Login: user=<linhntt@sakuratech.local>, rip=185.220.101.47 (IMPOSSIBLE TRAVEL)","srcip":"185.220.101.47","dstuser":"linhntt@sakuratech.local","mitre":{"id":["T1078","T1586.002"]}}
{"timestamp":"2026-05-29T10:30:00Z","rule":{"level":15,"id":"100009","description":"[Sakura] WEBMAIL ACCESS: Roundcube accessed from suspicious IP"},"full_log":"May 29 10:30:00 dmz-mail nginx: access from 185.220.101.47 to Roundcube","srcip":"185.220.101.47","location":"Germany (Tor exit node)","mitre":{"id":["T1078"]}}
WAZUH_P3

# Create GeoIP analysis for forensics
cat > "/tmp/phishing_evidence/phase3_geoip_analysis.txt" << 'GEOIP'
=== GEOIP LOOKUP RESULTS ===

IP Address: 185.220.101.47
----------------------------------------
ASN:        AS24940 — Hetzner Online GmbH
Country:    Germany (DE)
City:       Berlin (approximate)
Region:     Berlin
Coordinates: 52.52, 13.40
ISP:        Hetzner Online GmbH (Cloud hosting)
Host:       tor-exit-relay.anonymizing.io
Type:       Tor Exit Node
Reputation: MALICIOUS

AbuseIPDB: https://www.abuseipdb.com/check/185.220.101.47
  Confidence: 95% — Reported for spam, hacking, fraud
  Total Reports: 1,247
  Last Reported: 2026-05-20

VirusTotal: https://www.virustotal.com/gui/ip-address/185.220.101.47
  Categories: Tor Exit Node, Proxy, VPN, Anonymizer

=== IMPOSSIBLE TRAVEL ANALYSIS ===
Previous login: 10.71.121.100 (Vietnam) — 09:15 ICT
Current login:  185.220.101.47 (Germany) — 10:30 ICT

Time difference: 75 minutes
Physical distance: ~9,000 km

Maximum possible travel speed: 7,200 km/h (Mach 5.9)
This login pattern is IMPOSSIBLE without technology assistance (VPN/Tor).
GEOIP

ok "Phase 3: Account compromise simulated"
ok "Attacker login logged: linhntt@sakuratech.local from 185.220.101.47"
ok "IMPOSSIBLE TRAVEL: Vietnam (09:15) → Germany (10:30) in 75 min"
ok "2 simultaneous sessions: victim + attacker"
ok "Wazuh alert: Rule 100003 — POSSIBLE BEC triggered"
ok "GeoIP analysis saved: /tmp/phishing_evidence/phase3_geoip_analysis.txt"
fi

# ===========================================================
# PHASE 4: Persistence (Mail Rule)
# ===========================================================
if [ "$START_PHASE" -le 4 ]; then
phase 4 "PERSISTENCE — Attacker tạo mail rule auto-forward"

confirm 4 "Persistence"

log "Simulating attacker creating email forwarding rule..."

# Inject sieve filter creation log
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/log/dovecot.log" << 'SIEVE_LOG'
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: lmtp(linhntt@sakuratech.local): sieve: msgid=<rule-create@attacker>: Sieve script created: fileinto "sakura-vendor-filter"; active
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: lmtp(linhntt@sakuratech.local): sieve: msgid=<rule-apply@attacker>: Active Sieve script installed: forwarding financial emails
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp: from=<linhntt@sakuratech.local>, to=<attacker@protonmail.com>, relay=smtp-relay.gmail.com[142.250.xx.xx]: 250 OK
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: imap-login: Info: Login: user=<linhntt@sakuratech.local>, method=PLAIN, rip=185.220.101.47, lip=10.71.119.51, mpid=2001, secured, session=<rule-session-003>
SIEVE_LOG

# Show the actual sieve rule that was created (for forensics)
cat > "/tmp/phishing_evidence/phase4_sieve_rule.txt" << 'SIEVE'
=== SIEVE FILTER RULE CREATED ===
User: linhntt@sakuratech.local
Created: 2026-05-29 11:00:00 ICT
Source IP: 185.220.101.47

Rule Name: system-update-filter
Rule Status: ACTIVE

Conditions:
  IF Subject OR Body contains ANY of:
    - "thanh toán"
    - "chuyển khoản"
    - "ngân hàng"
    - "payment"
    - "invoice"
    - "hóa đơn"
    - "billing"

Actions:
  1. Forward to: attacker@protonmail.com
  2. Mark as: read
  3. Move to: Trash

Evidence: This rule was created to automatically forward ALL 
financial-related emails to the attacker BEFORE the victim 
can see them, enabling BEC fraud.

Detection: Dovecot sieve log shows new filter creation.
Detection: Postfix log shows emails forwarded to external domain.
SIEVE

# Inject Wazuh alerts
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/ossec/logs/alerts/alerts.json" << 'WAZUH_P4'
{"timestamp":"2026-05-29T11:00:00Z","rule":{"level":15,"id":"100004","description":"[Sakura] MAIL RULE ALERT: New email forwarding rule detected"},"full_log":"May 29 11:00:00 dmz-mail dovecot: sieve: Active Sieve script installed: forwarding financial emails","srcip":"185.220.101.47","dstuser":"linhntt@sakuratech.local","dstuser":"attacker@protonmail.com","mitre":{"id":["T1114.003","T1564.008"]}}
{"timestamp":"2026-05-29T11:00:05Z","rule":{"level":12,"id":"100012","description":"[Sakura] EXTERNAL FORWARD: Email being forwarded to external email service"},"full_log":"May 29 11:00:05 dmz-mail postfix/smtp: from=<linhntt@sakuratech.local> to=<attacker@protonmail.com>","srcip":"185.220.101.47","dstuser":"attacker@protonmail.com","mitre":{"id":["T1114.003"]}}
WAZUH_P4

ok "Phase 4: Mail rule persistence simulated"
ok "Sieve filter created: auto-forward financial emails to attacker@protonmail.com"
ok "Rule keywords: 'thanh toán', 'chuyển khoản', 'ngân hàng'"
ok "Wazuh alert: Rule 100004 — MAIL RULE ALERT triggered"
ok "Sieve rule evidence saved: /tmp/phishing_evidence/phase4_sieve_rule.txt"
fi

# ===========================================================
# PHASE 5: BEC Fraud
# ===========================================================
if [ "$START_PHASE" -le 5 ]; then
phase 5 "BEC FRAUD — Attacker gửi email lừa đảo từ mailbox chị Linh"

confirm 5 "BEC Fraud"

log "Simulating attacker sending BEC email from linhntt's mailbox..."

# Create the BEC email
cat > "/tmp/phishing_evidence/phase5_bec_email.eml" << 'BEC_EMAIL'
Return-Path: <linhntt@sakuratech.local>
Received: from mail.sakuratech.local (mail.sakuratech.local [10.71.119.51])
        by mail.sakuratech.local with ESMTP id BEC123HACK456
        for <phongketoan@sakuratech.local>;
        Mon, 29 May 2026 14:00:00 +0700 (ICT)
Received-SPF: PASS (mail.sakuratech.local)
DKIM-Signature: v=1; a=rsa-sha256; d=sakuratech.local; s=default;
        h=from:to:subject:date:message-id;
Authentication-Results: mx.google.com;
        dkim=pass header.i=@sakuratech.local header.s=default;
        spf=pass (google.com: domain of linhntt@sakuratech.local designates 10.71.119.51 as permitted sender);
        dmarc=pass (p=REJECT sp=REJECT dis=NONE) header.from=sakuratech.local
From: "Nguyễn Thị Linh" <linhntt@sakuratech.local>
To: phongketoan@sakuratech.local
Subject: [KHẨN] Cập nhật thông tin ngân hàng nhà cung cấp ABC
Date: Mon, 29 May 2026 14:00:00 +0700
Message-ID: <bec-incident-2026@sakuratech.local>
X-Mailer: Roundcube Webmail (attacker session)

[BEC email content: requesting bank account update with Vietcombank 9876543210]
BEC_EMAIL

# Inject into mail logs
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/log/mail.log" << 'MAILLOG_BEC'
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[3001]: from=<linhntt@sakuratech.local>
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[3001]: to=<phongketoan@sakuratech.local>
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[3001]: status=sent (delivered to mailbox)
$(date '+%b %d %H:%M:%S') dmz-mail postfix/smtp[3001]: message-id=<bec-incident-2026@sakuratech.local>
MAILLOG_BEC

# Inject Roundcube access log (attacker from foreign IP)
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/log/nginx/access.log" << 'RC_LOG'
185.220.101.47 - linhntt [29/May/2026:14:00:00 +0700] "POST /mail/?_task=mail &_action=send HTTP/1.1" 302 0 "https://10.71.119.51/mail/?_task=mail&_action=compose" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "linhntt=sakura-session-hijacked"
RC_LOG

# Inject Wazuh alerts for Phase 5
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/ossec/logs/alerts/alerts.json" << 'WAZUH_P5'
{"timestamp":"2026-05-29T14:00:00Z","rule":{"level":15,"id":"100005","description":"[Sakura] CRITICAL: Email sent from linhntt@sakuratech.local via external IP"},"full_log":"May 29 14:00:00 dmz-mail postfix/smtp: from=<linhntt@sakuratech.local> to=<phongketoan@sakuratech.local> relay=smtp (attacker session from 185.220.101.47)","srcip":"185.220.101.47","dstip":"10.71.119.51","srcuser":"linhntt@sakuratech.local","dstuser":"phongketoan@sakuratech.local","mitre":{"id":["T1586.002","T1102"]}}
{"timestamp":"2026-05-29T14:00:00Z","rule":{"level":14,"id":"100003","description":"[Sakura] POSSIBLE BEC: linhntt mailbox accessed from suspicious IP for mail composition"},"full_log":"May 29 14:00:00 dmz-mail nginx: POST /mail/? from 185.220.101.47 session=sakura-session-hijacked","srcip":"185.220.101.47","location":"Germany (Tor exit node)","mitre":{"id":["T1586.002"]}}
WAZUH_P5

ok "Phase 5: BEC fraud simulated"
ok "Email sent from linhntt@sakuratech.local → phongketoan@sakuratech.local"
ok "Email looks LEGITIMATE: SPF PASS, DKIM PASS, DMARC PASS"
ok "Sender IP INCONSISTENCY: Email header shows legitimate,
ok "    but Wazuh shows it was sent from attacker session at 185.220.101.47"
ok "Content: Request to update bank account to Vietcombank 9876543210"
ok "BEC email saved: /tmp/phishing_evidence/phase5_bec_email.eml"
fi

# ===========================================================
# PHASE 6: Covering Tracks
# ===========================================================
if [ "$START_PHASE" -le 6 ]; then
phase 6 "COVERING TRACKS — Attacker xóa bằng chứng trong mailbox"

confirm 6 "Covering Tracks"

log "Simulating attacker cleaning up evidence..."

# Inject deletion events
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/log/dovecot.log" << 'DELETE_LOG'
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: imap(linhntt@sakuratech.local): Info: expunge: uid=42 (security-alert.eml)
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: imap(linhntt@sakuratech.local): Info: expunge: uid=43 (security-alert-2.eml)
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: imap(linhntt@sakuratech.local): Info: expunge: uid=44 (original-phishing-email.eml)
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: imap(linhntt@sakuratech.local): Info: expunge: uid=45 (bec-email-draft.eml)
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: imap(linhntt@sakuratech.local): Info: mailbox: Trash folder emptied (session=attacker-cleanup-004)
$(date '+%b %d %H:%M:%S') dmz-mail dovecot: imap(linhntt@sakuratech.local): Info: Disconnect: user=<linhntt@sakuratech.local>, rip=185.220.101.47, lip=10.71.119.51, mpid=4001, session=<attacker-cleanup-004>
DELETE_LOG

# Inject iRedAdmin audit log
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/www/iredadmin/logs/iredadmin.log" << 'IREDADMIN_LOG'
$(date '+%b %d %H:%M:%S') dmz-mail iredadmin: User: linhntt@sakuratech.local, IP: 185.220.101.47, Action: settings_changed, Module: mailbox_rules
$(date '+%b %d %H:%M:%S') dmz-mail iredadmin: User: linhntt@sakuratech.local, IP: 185.220.101.47, Action: filter_created, Details: sieve rule "system-update-filter"
$(date '+%b %d %H:%M:%S') dmz-mail iredadmin: User: linhntt@sakuratech.local, IP: 185.220.101.47, Action: mailbox_access, Session: attacker-cleanup-004
IREDADMIN_LOG

# Inject Wazuh alerts for Phase 6
ssh "$MAIL_USER@$MAIL_SERVER" "cat >> /var/ossec/logs/alerts/alerts.json" << 'WAZUH_P6'
{"timestamp":"2026-05-29T14:30:00Z","rule":{"level":8,"id":"100010","description":"[Sakura] MAILBOX CHANGE: Multiple email deletions detected in linhntt mailbox"},"full_log":"May 29 14:30:00 dmz-mail dovecot: imap(linhntt): expunge: uid=42-45 deleted","srcip":"185.220.101.47","dstuser":"linhntt@sakuratech.local","mitre":{"id":["T1070.008"]}}
{"timestamp":"2026-05-29T14:30:05Z","rule":{"level":8,"id":"100010","description":"[Sakura] MAILBOX CHANGE: Trash folder emptied"},"full_log":"May 29 14:30:05 dmz-mail dovecot: Trash folder emptied by linhntt@sakuratech.local","srcip":"185.220.101.47","dstuser":"linhntt@sakuratech.local","mitre":{"id":["T1070.008"]}}
{"timestamp":"2026-05-29T14:30:10Z","rule":{"level":8,"id":"100004","description":"[Sakura] MAIL RULE ALERT: Sieve filter activity detected"},"full_log":"May 29 14:30:10 dmz-mail dovecot: sieve: Active Sieve script in use","srcip":"185.220.101.47","dstuser":"linhntt@sakuratech.local","mitre":{"id":["T1564.008"]}}
WAZUH_P6

# Create forensics note about what CANNOT be deleted
cat > "/tmp/phishing_evidence/phase6_forensics_note.txt" << 'FORENSIC_NOTE'
=== WHAT THE ATTACKER TRIED TO DELETE ===
  - Security alert emails in mailbox
  - Original phishing email
  - BEC draft emails
  - Sent Items (after BEC email sent)
  - Trash folder (emptied)

=== WHAT CANNOT BE DELETED ===
  1. POSTFIX MAIL LOG (/var/log/mail.log)
     - Server-side logs are append-only
     - Email send events are PERMANENTLY recorded
     - IP addresses, timestamps, message-IDs preserved

  2. DOVECOT AUTH/ACTIVITY LOG (/var/log/dovecot.log)
     - Login/logout events are append-only
     - Session IDs cannot be altered
     - IP addresses logged for every connection

  3. WAZUH ALERTS (/var/ossec/logs/alerts/alerts.json)
     - SIEM alerts are immutable by design
     - Alert timestamps and details preserved
     - Chain of custody maintained

  4. IREDADMIN AUDIT LOG (/var/www/iredadmin/logs/)
     - Admin actions logged server-side
     - Cannot be deleted by mailbox user
     - Full timeline of mailbox changes

  5. SMTP SESSION DATA (Postfix queue)
     - queue files preserved until purged by admin
     - Message-IDs link to exact send times

  6. NETWORK FLOW DATA (pfSense/Firewall logs)
     - All connections logged at firewall level
     - IP 185.220.101.47 → 10.71.119.51 captured
     - DNS queries logged

  === CONCLUSION ===
  Despite the attacker's effort to cover tracks, the following
  evidence provides a COMPLETE timeline:
    - Email header analysis → phishing source
    - Dovecot logs → exact login times + IPs
    - Wazuh alerts → all phases captured with MITRE IDs
    - Mail queue logs → BEC email content preserved
    - iRedAdmin logs → mailbox rule changes logged
FORENSIC_NOTE

ok "Phase 6: Evidence cleanup simulated"
ok "Attacker deleted: security alerts, phishing email, sent items"
ok "Attacker emptied: Trash folder"
ok "KEY INSIGHT: Mailbox audit logs CANNOT be deleted!"
ok "Forensics note saved: /tmp/phishing_evidence/phase6_forensics_note.txt"
fi

# ===========================================================
# Summary
# ===========================================================
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║            SIMULATION COMPLETE                           ║"
echo "║           'Cái Bẫy Hoàn Hảo'                              ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Phase 1: Phishing email sent (SPF/DKIM/DMARC FAIL)"
echo "║  Phase 2: Victim clicked link (DNS + web logs)"
echo "║  Phase 3: Attacker login (Impossible travel, 2 sessions)"
echo "║  Phase 4: Mail rule created (Auto-forward financial)"
echo "║  Phase 5: BEC email sent (From legitimate mailbox)"
echo "║  Phase 6: Evidence deleted (But audit logs preserved!)"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Evidence collected: /tmp/phishing_evidence/"
echo "║  Run forensics: /opt/forensics/forensic_toolkit.sh"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
info "Next steps:"
info "  1. Review evidence in: ls /tmp/phishing_evidence/"
info "  2. Run forensics: ssh to 113 and use forensic toolkit"
info "  3. Check Wazuh: https://10.71.120.103"
info "  4. Analyze GoPhish: http://10.71.119.101:3333"
info "  5. Create timeline: ./forensic_toolkit.sh timeline"
echo ""
