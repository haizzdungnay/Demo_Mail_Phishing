# ============================================================
# LAB DEPLOYMENT GUIDE — "Cái Bẫy Hoàn Hảo"
# Sakura Tech Co. — Email Phishing + BEC + Digital Forensics
# ============================================================

## OVERVIEW

This lab simulates a complete **Business Email Compromise (BEC)** attack chain:
**Phishing → Credential Theft → Account Compromise → Mail Rule Persistence → BEC Fraud → Evidence Deletion**

The goal is to:
1. Understand the full attack chain
2. Detect the attack using SIEM (Wazuh)
3. Forensically investigate using log analysis
4. Write incident report with chain of custody

---

## PREREQUISITES

- Proxmox VE 8.x or VMware Workstation 17+
- At least 6 VMs (or 5 if using shared firewall)
- 32GB+ RAM total
- 200GB+ disk space total
- Internet access (for downloading ISOs and packages)

---

## LAB DEPLOYMENT STEPS

### Step 1: Create Proxmox/VMware VMs

Create these VMs in order:

| # | Name | OS | vCPU | RAM | Disk | IP |
|---|------|-----|------|-----|------|-----|
| 1 | `dmz-mail` | Ubuntu 24.04 LXC | 4 | 4GB | 80GB | 10.71.119.51 |
| 2 | `dmz-nginx` | Ubuntu 24.04 LXC | 2 | 2GB | 40GB | 10.71.119.101 |
| 3 | `mgmt-wazuh` | Ubuntu 22.04 VM | 4 | 8GB | 100GB | 10.71.120.103 |
| 4 | `srv-victim` | Ubuntu 24.04 LXC | 2 | 2GB | 40GB | 10.71.121.100 |
| 5 | `jump-kali` | Kali Linux 2024 VM | 4 | 8GB | 100GB | 10.71.120.113 |
| 6 | `fw-pfsense` | pfSense CE 2.7 VM | 2 | 2GB | 16GB | Multiple |

### Step 2: Network Configuration

On Proxmox, create a Linux Bridge for internal network:

```bash
# On Proxmox host
# Create bridge for internal lab network (no NAT)
# Use vmbr1 as the internal bridge

# Option A: Internal only (no internet for VMs)
# Option B: NAT + Internal (for package downloads)
```

**pfSense Configuration:**
- WAN: NAT/bridged (or disconnected for air-gapped)
- LAN (DMZ): 10.71.119.1/24
- OPT1 (MGMT): 10.71.120.1/24
- OPT2 (VICTIM_LAN): 10.71.121.1/24

### Step 3: Run Setup Scripts

SSH to each VM and run the setup script:

```bash
# === 107 dmz-mail ===
scp lab/setup/107_dmz-mail/setup.sh root@10.71.119.51:/tmp/
ssh root@10.71.119.51
bash /tmp/setup.sh

# After iRedMail installs, create users:
bash /tmp/create_users.sh

# === 101 dmz-nginx ===
scp lab/setup/101_dmz-nginx/setup.sh root@10.71.119.101:/tmp/
ssh root@10.71.119.101
bash /tmp/setup.sh

# === 103 mgmt-wazuh ===
scp lab/setup/103_mgmt-wazuh/setup.sh root@10.71.120.103:/tmp/
scp lab/wazuh/rules/sakura_custom_rules.xml root@10.71.120.103:/tmp/
scp lab/wazuh/decoders/sakura_custom_decoders.xml root@10.71.120.103:/tmp/
ssh root@10.71.120.103
bash /tmp/setup.sh
cp /tmp/sakura_custom_rules.xml /var/ossec/etc/rules/
cp /tmp/sakura_custom_decoders.xml /var/ossec/etc/decoders/
systemctl restart wazuh-manager

# === 100 srv-victim ===
scp lab/setup/100_srv-victim/setup.sh root@10.71.121.100:/tmp/
ssh root@10.71.121.100
bash /tmp/setup.sh

# === 113 jump-kali ===
scp lab/setup/113_jump-kali/setup.sh root@10.71.120.113:/tmp/
scp lab/forensics/forensic_guide.sh root@10.71.120.113:/tmp/
ssh root@10.71.120.113
bash /tmp/setup.sh
```

### Step 4: Configure GoPhish

```bash
# Access GoPhish admin
firefox http://10.71.119.101:3333

# Default credentials: admin / gophish
# CHANGE PASSWORD IMMEDIATELY!

# Import template:
# 1. Go to Templates → Import Template
# 2. Paste content from lab/gophish/templates/sakura_vendor_payment_upgrade.json

# Import landing page:
# 1. Go to Landing Pages → Import
# 2. Paste content from lab/gophish/landing_pages/outlook_sakura_vendor.html

# Configure Sending Profile:
# 1. Sending Profiles → New Profile
# 2. Name: Sakura Vendor Fake SMTP
# 3. From: support@sakura-vendor.com
# 4. Host: 10.71.119.51:25

# Create Campaign:
# 1. Campaigns → New Campaign
# 2. Name: Sakura Tech - Payment System Update
# 3. Select template + landing page + sending profile
# 4. Target: linhntt@sakuratech.local
# 5. URL: http://10.71.119.101:8080
```

### Step 5: Configure iRedMail

```bash
# Access iRedAdmin
firefox https://10.71.119.51/iredadmin
# Login: postmaster@sakuratech.local / Intern#2026

# Create mail accounts:
# 1. Add Domain: sakuratech.local
# 2. Add User: linhntt@sakuratech.local (Kế toán trưởng)
# 3. Add User: ducmh@sakuratech.local (CEO)
# 4. Add User: hoangnt@sakuratech.local (Nhân viên TC)
# 5. Add User: phongketoan@sakuratech.local (Phòng kế toán)
```

### Step 6: Configure Wazuh Custom Rules

```bash
# On 103 mgmt-wazuh:
cp lab/wazuh/rules/sakura_custom_rules.xml /var/ossec/etc/rules/
cp lab/wazuh/decoders/sakura_custom_decoders.xml /var/ossec/etc/decoders/
chown ossec:ossec /var/ossec/etc/rules/*.xml
chown ossec:ossec /var/ossec/etc/decoders/*.xml
systemctl restart wazuh-manager

# Verify rules loaded:
tail -f /var/ossec/logs/alerts/alerts.json
```

---

## RUNNING THE SIMULATION

### Full Automated Run (Recommended)

```bash
# On 107 dmz-mail or any node with SSH access:
scp -r lab/simulation/ root@10.71.119.51:/tmp/
scp lab/forensics/evidence/* root@10.71.119.51:/tmp/phishing_evidence/ 2>/dev/null || true
ssh root@10.71.119.51
cd /tmp
bash run_all_phases.sh
```

### Manual Phase-by-Phase

```bash
# Phase 1: Send phishing email
# (via GoPhish or manual SMTP)
# Template: lab/gophish/templates/sakura_vendor_payment_upgrade.json

# Phase 2: Victim clicks link
# (from srv-victim 100)
curl "http://10.71.119.101:8080/track/click/test123"

# Phase 3: Attacker login (inject into dovecot log)
ssh root@10.71.119.51
echo "$(date) dmz-mail dovecot: imap-login: Info: Login: user=<linhntt@sakuratech.local>, rip=185.220.101.47" >> /var/log/dovecot.log

# Phase 4: Mail rule (via Roundcube as attacker)
# Login: linhntt@sakuratech.local from external IP
# Create filter: forward "thanh toán", "chuyển khoản" → attacker@protonmail.com

# Phase 5: BEC email (via Roundcube as attacker)
# Send email from linhntt to phongketoan
# Content: Bank account update request

# Phase 6: Delete evidence
# (Attacker deletes emails from Roundcube)
```

---

## FORENSICS INVESTIGATION

### From Kali (113 jump-kali)

```bash
# Connect to Kali
ssh root@10.71.120.113

# Run forensic toolkit
cd /opt/forensics/cases/sakura_incident
forensic_toolkit.sh collect    # Collect all evidence
forensic_toolkit.sh timeline   # Build timeline
forensic_toolkit.sh report    # Generate report

# Or use individual tools:
whois 185.220.101.47
dig TXT sakura-vendor.com
curl ipinfo.io/185.220.101.47

# Analyze logs on mail server
ssh root@10.71.119.51
grep "sakura-vendor" /var/log/mail.log
grep "linhntt" /var/log/dovecot.log
```

### Wazuh Dashboard Investigation

```bash
# Access Wazuh
firefox https://10.71.120.103
# Login: admin / WazuhLab2026!

# Check panels:
# 1. Security Events → Search: "sakura"
# 2. Agents → Check 107 and 100 status
# 3. Discover → Filter by rule ID 100001-100012
# 4. Panels → Phishing alerts, BEC alerts
```

### Email Header Analysis

```bash
# Save email as .eml file
# Use Google Admin Toolbox:
# https://toolbox.googleapps.com/apps/messageheader/

# Or use command line:
cat suspicious_email.eml | grep "^Received:"
cat suspicious_email.eml | grep "^From:"
cat suspicious_email.eml | grep "SPF\|DKIM\|DMARC"
```

---

## EXPECTED DETECTION TIMELINE

After running simulation, Wazuh should show alerts in this order:

| Time | Alert | Rule | Severity |
|------|--------|-------|-----------|
| 09:00 | Phishing email from sakura-vendor.com | 100006 | Medium |
| 09:00 | SPF/DKIM/DMARC failure | 100007 | Medium |
| 09:15 | DNS query to suspicious domain | 100006 | Medium |
| 09:15 | User clicked phishing link | 100008 | Low |
| 10:30 | Tor exit node login | 100002 | High |
| 10:30 | Impossible travel detected | 100003 | Critical |
| 10:30 | Compromised account accessed | 100009 | High |
| 11:00 | Mail forwarding rule created | 100004 | Critical |
| 14:00 | Internal email from external IP | 100005 | Critical |
| 14:30 | Mass email deletion | 100010 | Medium |

---

## TROUBLESHOOTING

### iRedMail Installation Fails
- Ensure 4GB+ RAM and 80GB+ disk
- Disable any existing mail servers
- Run as root

### GoPhish Not Sending Email
- Check SMTP: `telnet 10.71.119.51 25`
- Check Wazuh: `tail /var/ossec/logs/alerts/alerts.json`
- Verify sending profile in GoPhish

### Wazuh Agents Not Connecting
- Check firewall: `ufw status`
- Check agent: `systemctl status wazuh-agent`
- Verify manager IP: `grep manager /var/ossec/etc/ossec.conf`

### Victim Cannot Access Phishing Page
- Check DNS: `dig login-sakura-vendor.com`
- Add to `/etc/hosts` if DNS not working:
  `10.71.119.101  login-sakura-vendor.com sakura-vendor.com`

---

## SECURITY NOTES

- This lab MUST run in an isolated network
- Change all default passwords immediately
- Delete all simulation data after the lab is complete
- Do NOT connect VMs to production networks
- Use strong passwords for all mail accounts
