# IOC (Indicators of Compromise) — Sakura Tech Incident

## Domains

| Domain | Type | Description |
|--------|------|-------------|
| `sakura-vendor.com` | Phishing sender | Typosquat của `sakura-vendor.net` |
| `login-sakura-vendor.com` | Phishing landing | Trang giả mạo Outlook |
| `sakura-vendor.net` | Legitimate | Domain thật của nhà cung cấp (không phải phishing) |
| `sakuratech.local` | Legitimate | Internal mail domain |
| `attacker@protonmail.com` | Attacker | Email forward destination |

## IP Addresses

| IP | Type | Description |
|----|------|-------------|
| `185.220.101.47` | Attacker | Tor exit node, Germany — nơi attacker đăng nhập |
| `10.71.119.51` | Mail Server | iRedMail server |
| `10.71.119.101` | GoPhish | Phishing infrastructure |
| `10.71.121.100` | Victim | Victim workstation IP |
| `91.108.4.x` | Attacker | Tor exit nodes (additional) |
| `91.108.8.x` | Attacker | Tor exit nodes (additional) |
| `199.249.223.x` | Attacker | Tor exit nodes (additional) |

## Email Addresses

| Email | Role |
|-------|------|
| `support@sakura-vendor.com` | Phishing sender (giả mạo) |
| `attacker@protonmail.com` | Attacker email (forward destination) |
| `linhntt@sakuratech.local` | Compromised account |
| `phongketoan@sakuratech.local` | BEC target |

## Authentication Failures

| Indicator | Value |
|-----------|-------|
| SPF | FAIL on `sakura-vendor.com` |
| DKIM | FAIL on `sakura-vendor.com` |
| DMARC | NONE on `sakura-vendor.com` |

## Behavioral Indicators

| Indicator | Value |
|-----------|-------|
| Impossible Travel | Vietnam (10.71.121.100) → Germany (185.220.101.47) in 75 minutes |
| Concurrent Sessions | 2 IMAP sessions simultaneously on `linhntt` account |
| Mail Rule Keywords | `thanh toán`, `chuyển khoản`, `ngân hàng`, `payment`, `invoice` |
| Mail Rule Action | Forward to `attacker@protonmail.com`, mark as read, move to trash |

## Hashes

| File | MD5 | SHA256 |
|------|-----|--------|
| `phase1_phishing_email.eml` | (hash after simulation) | (hash after simulation) |
| `phase5_bec_email.eml` | (hash after simulation) | (hash after simulation) |
| `mail.log` | (hash after collection) | (hash after collection) |
| `dovecot.log` | (hash after collection) | (hash after collection) |

## Network Artifacts

| Artifact | Description |
|----------|-------------|
| DNS Query | `login-sakura-vendor.com` queried by victim |
| Session ID | `attacker-session-002` (Dovecot) |
| Message-ID | `phish-1716954000@sakura-vendor.com` |
| Message-ID | `bec-incident-2026@sakuratech.local` |
| Sieve Script | `fileinto "sakura-vendor-filter"` |

## MITRE ATT&CK Mapping

| Phase | Tactic | Technique | ID |
|-------|--------|-----------|-----|
| 1 | Initial Access | Spearphishing Link | T1566.002 |
| 1 | Reconnaissance | Phishing for Information | T1598 |
| 2 | Collection | Input Capture | T1056 |
| 3 | Credential Access | Valid Accounts | T1078 |
| 3 | Discovery | Remote System Discovery | T1018 |
| 4 | Collection | Email Forwarding Rule | T1114.003 |
| 4 | Defense Evasion | Email Hiding Rules | T1564.008 |
| 5 | Resource Development | Compromise Email Accounts | T1586.002 |
| 5 | Exfiltration | Exfiltration Over Alternative Protocol | T1048 |
| 6 | Defense Evasion | Clear Mailbox Data | T1070.008 |
| 6 | Defense Evasion | Delete Email | T1070.004 |
