# ============================================================
# LAB TOPOLOGY - "CÁI BẪY HOÀN HẢO"
# Sakura Tech Co. — Email Phishing + BEC + Digital Forensics
# ============================================================
#
#  [Internet / External]
#        |
#   +----+----+
#   |          |
# [102 pfSense]  (External Firewall)
#   |  NAT / VLAN isolation
#   +----+----+
#        |
#  +-----+-----+-----+-----+
#  |     |     |     |      |
# [107] [101] [100] [103] [113]
# DMZ   DMZ   LAN   MGMT  JUMP
#
# VLAN10 — DMZ (Mail, GoPhish):    10.71.119.0/24
# VLAN20 — MGMT (Wazuh):           10.71.120.0/24
# VLAN30 — LAN (Victim):           10.71.121.0/24
# ============================================================

## NODE SPECIFICATIONS

### 107 dmz-mail (Mail Server — iRedMail)
```
Node ID    : 107
Hostname   : dmz-mail.sakuratech.local
IP Address : 10.71.119.51
Netmask    : 255.255.255.0
Gateway    : 10.71.119.1 (pfSense)
MAC        : (to be filled by Proxmox)
OS         : Ubuntu 24.04 LTS (LXC, privileged)
vCPU       : 4
RAM        : 4 GB
Disk       : 80 GB
Role       : iRedMail 1.8.1 — SMTP/IMAP/POP3
Ports      : 25 (SMTP), 143 (IMAP), 993 (IMAPS), 995 (POP3S)
            : 443 (iRedAdmin + Roundcube), 80 (redirect)
Services   : Postfix, Dovecot, Roundcube, iRedAdmin, Fail2ban
FQDN       : mail.sakuratech.local
Domain     : sakuratech.local
```

### 101 dmz-nginx (GoPhish + Landing Pages)
```
Node ID    : 101
Hostname   : dmz-nginx.sakuratech.local
IP Address : 10.71.119.101
Netmask    : 255.255.255.0
Gateway    : 10.71.119.1 (pfSense)
OS         : Ubuntu 24.04 LTS (LXC)
vCPU       : 2
RAM        : 2 GB
Disk       : 40 GB
Role       : GoPhish 0.12.1 — Phishing Campaign Management
            : Nginx reverse proxy
            : Landing page hosting
Ports      : 3333 (GoPhish Admin), 8080 (Phishing Pages)
Services   : GoPhish, Nginx
FQDN       : phishing.sakuratech.local
Domain     : sakura-vendor.com (phishing domain — typosquat)
```

### 103 mgmt-wazuh (SIEM — Wazuh)
```
Node ID    : 103
Hostname   : mgmt-wazuh.sakuratech.local
IP Address : 10.71.120.103
Netmask    : 255.255.255.0
Gateway    : 10.71.120.1 (pfSense)
OS         : Ubuntu 22.04 LTS (VM)
vCPU       : 4
RAM        : 8 GB
Disk       : 100 GB
Role       : Wazuh 4.8.2 — SIEM & Alerting
            : Elasticsearch 8.x + Kibana/Dashboard
Ports      : 1514 (Agent), 9200 (Elasticsearch), 5601 (Kibana)
Services   : Wazuh Manager, Elasticsearch, Wazuh Indexer, Dashboard
FQDN       : wazuh.sakuratech.local
```

### 100 srv-victim (Victim Simulation)
```
Node ID    : 100
Hostname   : srv-victim.sakuratech.local
IP Address : 10.71.121.100
Netmask    : 255.255.255.0
Gateway    : 10.71.121.1 (pfSense)
OS         : Ubuntu 24.04 LTS (LXC)
vCPU       : 2
RAM        : 2 GB
Disk       : 40 GB
Role       : Victim simulation — nhân viên mở email, click link
            : Browser để truy cập Roundcube
            : Wazuh agent để gửi log
Ports      : 1514 (Wazuh agent)
Services   : Wazuh agent, curl/browser
```

### 113 jump-kali (Forensics Jump Server)
```
Node ID    : 113
Hostname   : jump-kali.sakuratech.local
IP Address : 10.71.120.113
Netmask    : 255.255.255.0
Gateway    : 10.71.120.1 (pfSense)
OS         : Kali Linux 2024.x (VM)
vCPU       : 4
RAM        : 8 GB
Disk       : 100 GB
Role       : Forensic Analyst Station
            : Điều tra chứng cứ số
            : Phân tích log, email header, IP tracking
Tools      : Wireshark, Volatility, Autopsy, grep/sed/awk,
            : md5sum, sha256sum, whois, dig, curl
```

### 102 fw-pfsense (External Firewall)
```
Node ID    : 102
Hostname   : fw-pfsense.sakuratech.local
IP WAN     : (DHCP or static — lab external)
IP LAN     : 10.71.119.1 (DMZ gateway)
IP MGMT    : 10.71.120.1 (MGMT gateway)
IP LAN2    : 10.71.121.1 (Victim LAN)
OS         : pfSense CE 2.7.x (VM or LXC)
vCPU       : 2
RAM        : 2 GB
Disk       : 16 GB
Role       : Edge firewall — VLAN segmentation
            : NAT for outbound
            : Block unauthorized inbound
```

## MAIL ACCOUNTS (sakuratech.local)

| Account   | Email                          | Password       | Role           |
|-----------|--------------------------------|----------------|----------------|
| postmaster| postmaster@sakuratech.local   | Intern#2026    | Admin (iRedAdmin) |
| linhntt   | linhntt@sakuratech.local       | Victim@2026!   | Kế toán trưởng (Nạn nhân) |
| ducmh     | ducmh@sakuratech.local        | CEO@2026!      | CEO giả mạo (attacker controlled) |
| hoangnt   | hoangnt@sakuratech.local      | Staff@2026!    | Nhân viên phòng tài chính |
| phongkt   | phongketoan@sakuratech.local  | Staff@2026!    | Phòng kế toán |

## PHISHING INFRASTRUCTURE

| Component       | Detail                                      |
|-----------------|---------------------------------------------|
| Phishing Domain | sakura-vendor.com (typosquat của .net)    |
| Sender Email    | support@sakura-vendor.com                  |
| Landing Page    | http://10.71.119.101:8080 (GoPhish hosted)|
| GoPhish Admin   | https://10.71.119.101:3333                |
| Tracking Domain | login-sakura-vendor.com                    |

## NETWORK CONNECTIVITY MATRIX

| From \ To     | Mail(107) | GoPhish(101) | Wazuh(103) | Victim(100) | Kali(113) |
|---------------|-----------|---------------|------------|------------|-----------|
| Mail(107)     | —         | SMTP:25       | Agent:1514 | IMAP:143   | SSH:22    |
| GoPhish(101)  | SMTP:25   | —             | Agent:1514 | HTTP:8080  | SSH:22    |
| Wazuh(103)    | MGT:443   | MGT:443       | —          | Agent:1514 | MGT:443   |
| Victim(100)   | HTTPS:443 | HTTP:8080     | Agent:1514 | —          | —         |
| Kali(113)     | SSH:22    | SSH:22        | HTTPS:5601 | SSH:22     | —         |

## DNS ENTRIES (Add to pfSense DNS Resolver)

```
mail.sakuratech.local     A  10.71.119.51
wazuh.sakuratech.local     A  10.71.120.103
phishing.sakuratech.local  A  10.71.119.101
sakura-vendor.com          A  10.71.119.101   ; phishing domain
login-sakura-vendor.com     A  10.71.119.101   ; phishing tracking domain
```

## PHASE TIMELINE

```
[Day 1]
  09:00  Phase 1  — Email phishing sent from sakura-vendor.com
  09:15  Phase 2  — Victim clicks link, GoPhish logs event
  10:30  Phase 3  — Attacker login from foreign IP (impossible travel)
  11:00  Phase 4  — Mail rule created (auto-forward financial emails)

[Day 3]
  14:00  Phase 5  — BEC fraud email sent from Linh's mailbox
  14:30  Phase 6  — Attacker deletes evidence
```

## WAZUH MONITORING SCOPE

```
Monitor on 107 (mail):
  - /var/log/mail.log          (Postfix SMTP logs)
  - /var/log/dovecot.log        (Dovecot IMAP/POP3 auth)
  - /var/log/nginx/access.log   (Roundcube webmail)
  - /var/log/iredadmin.log      (Admin actions)
  - /var/log/fail2ban.log       (Brute force protection)

Monitor on 100 (victim):
  - /var/log/syslog             (Browser simulation logs)
  - /var/log/auth.log           (User sessions)

Monitor on 101 (GoPhish):
  - /opt/gophish/logs/          (Campaign events)

Monitor on Kali (113) — FORENSICS ONLY, no agent:
  - SSH access logs (manual collection)
```

## IOC LIST

```
# Domains
sakura-vendor.com           (phishing sender domain — typosquat)
login-sakura-vendor.com     (phishing landing page domain)

# IPs
185.220.101.47             (attacker — Tor exit node, Germany)
10.71.119.51               (mail server — sakuratech.local)
10.71.119.101             (GoPhish server)
10.71.121.100             (victim workstation)

# Emails
support@sakura-vendor.com  (phishing sender)
attacker@protonmail.com    (forward destination)
linhntt@sakuratech.local   (compromised account)

# Auth
SPF: FAIL on sakura-vendor.com
DKIM: FAIL on sakura-vendor.com
DMARC: NONE on sakura-vendor.com

# Behavioral
Impossible travel: Vietnam (09:15) → Germany (10:30) in 75 min
Mail rule: auto-forward "thanh toán", "chuyển khoản", "ngân hàng"
```

## MITRE ATT&CK MAPPING

| Phase | Tactic                  | Technique                  | ID           |
|-------|-------------------------|----------------------------|--------------|
| 1     | Initial Access         | Spearphishing Link         | T1566.002    |
| 2     | Collection             | Phishing for Information   | T1598        |
| 3     | Credential Access      | Valid Accounts             | T1078        |
| 4     | Collection             | Email Forwarding Rule      | T1114.003    |
| 4     | Defense Evasion        | Email Hiding Rules         | T1564.008    |
| 5     | Resource Development   | Compromise Email Accounts  | T1586.002    |
| 6     | Defense Evasion        | Clear Mailbox Data         | T1070.008    |
