# PhishLab - Sakura Tech Email Incident Lab
"Cái Bẫy Hoàn Hảo"

> Chi muc dich dao tao nhan dien phishing, BEC, va dieu tra so. Chi trien khai trong mang noi bo co phep.

## Cau truc kho (Repository Structure)

```
Demo-Mail-Phising/
├── lab/                      # Lab mo phong 6 VMs (Proxmox)
│   ├── topology/             # Cau hinh mang 6 VMs
│   ├── setup/                # Scripts cai dat cho tung VM
│   ├── gophish/              # GoPhish campaign config
│   ├── wazuh/                # Wazuh SIEM rules
│   ├── simulation/           # Tu dong mo phong 6 phase
│   ├── forensics/            # Cong cu dieu tra so
│   └── DEPLOYMENT_GUIDE.md  # Huong dan cai dat chi tiet
├── demo web only/            # Phishing landing page (web-only, khong can lab)
│   └── outlook-otp/
│       ├── frontend/         # Trang web gia mao Outlook + OTP
│       └── backend/          # Node.js API (gui OTP qua Gmail SMTP)
└── docs/                     # Tai lieu bieu mau
```

## Hai che do trien khai

### Che do 1: Demo Web Only (Khong can lab)
Chay phishing landing page don gian chi voi frontend + backend Node.js tren may cuc bo.

**Cac buoc:**

```bash
# 1. Cai dat backend
cd "demo web only/outlook-otp/backend"
npm install

# 2. Tao file .env (copy tu .env.example)
# Chen email Gmail va App Password cua ban

# 3. Chay backend
npm start

# 4. Mo frontend
# Mo file frontend/index.html trong trinh duyet
```

**Yeu cau:**
- Node.js 18+
- Tai khoan Gmail voi [App Password](https://myaccount.google.com/apppasswords)
- Frontend: chi can mo file HTML, khong can server

**Chuc nang:**
- Step 1: Nhap email
- Step 2: Nhap mat khau (luu log)
- Step 3: Nhap ma OTP 6 chu so (gui tu backend qua Gmail SMTP)
- Step 4: Thong bao thanh cong

**Luu y:** Tat ca email mat khau chi duoc ghi log cuc bo, khong gui dau.

---

### Che do 2: Lab Day Du (12 VMs Proxmox)
Lab mo phong tan cong **Email-Based Cybercrime** voi 2 case:

### Case 1 — Technical Attack (Spear Phishing + Reverse Shell)

```
Phase 1 (09:00):  GoPhish gui email phishing tu sakura-vendor.com → linhntt
Phase 2 (09:15): linhntt click link → landing page → GoPhish log IP, timestamp
Phase 3 (10:30): Reverse shell ve Kali → whoami → SAKURATECH\linhntt
Phase 4 (11:00): Wazuh bat alert — suspicious outbound connection
                 → Dieu tra: network log, process tree, Windows Event Log
```

### Case 2 — BEC Fraud (Financial)

```
Phase 1 (Day 1, 10:30): Attacker dang nhap mailbox linhntt tu IP nuoc ngoai (Tor exit node)
Phase 2 (Day 1, 11:00): Tao mail rule tu dong forward email tai chinh
Phase 3 (Day 3, 14:00): Attacker gui email BEC tu hop thu linhntt den phongketoan
                          ("Nha cung cap doi tai khoan ngan hang, chuyen khoan gap")
Phase 4 (Day 3, 14:30): Xoa bang chung nhung van con trace
                          → Dieu tra: email header, SPF/DKIM/DMARC FAIL,
                              impossible travel (VN → Germany 75 phut)
```

## Cau truc lab

```
lab/
├── topology/           cau hinh mang 6 VMs
│   └── TOPOLOGY.md   chi tiet IP, VLAN, account
├── setup/             scripts cai dat cho tung VM
│   ├── 107_dmz-mail/  iRedMail server
│   ├── 101_dmz-nginx/ GoPhish + Landing pages
│   ├── 103_mgmt-wazuh/ Wazuh SIEM
│   ├── 100_srv-victim/  Victim simulation
│   │                     ⚠️ Luu y: Victim hien tai la Windows (ws-linhntt VM120),
│   │                        khong phai Ubuntu. Script trong thu muc nay chi giu
│   │                        lai de tham khao ban Linux cu. Khi chay setup,
│   │                        BO QUA script nay.
│   ├── 113_jump-kali/  Kali forensics station
│   └── 102_fw-pfsense/ pfSense firewall
├── gophish/           GoPhish campaign config
│   ├── templates/      Email templates (phishing + BEC)
│   ├── landing_pages/   Landing page HTML
│   └── campaigns/       Campaign configs
├── wazuh/              Wazuh SIEM rules
│   ├── rules/           Custom detection rules
│   └── decoders/        Log decoders
├── simulation/          Tu dong mo phong 6 phase
│   └── run_all_phases.sh
├── forensics/           Cong cu dieu tra so
│   ├── forensic_guide.sh  Workflow tu dong
│   └── IOC.md           Danh sach IOC
└── DEPLOYMENT_GUIDE.md  Huong dan cai dat chi tiet
```

## Tai khoan mail

> ⚠️ Cac mat khau that duoc luu trong file rieng (khong commit len Git).
> README chi hien thi placeholder. Xem DEPLOYMENT_GUIDE.md (ban noi bo) de biet chi tiet.

| Email | Mat khau | Vai tro |
|-------|----------|---------|
| postmaster@sakuratech.local | `<admin-password>` | Admin iRedMail |
| linhntt@sakuratech.local | `<user-password>` | Ke toan truong (nan nhan) |
| ducmh@sakuratech.local | `<ceo-password>` | CEO gia (attacker dung spoof) |
| phongketoan@sakuratech.local | `<accounting-password>` | Phong ke toan (Case 2 BEC) |

## Web Services

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| iRedAdmin | https://10.10.50.20/iredadmin | postmaster@sakuratech.local | `<admin-password>` |
| Roundcube Webmail | https://10.10.50.20/mail | linhntt@sakuratech.local | `<user-password>` |
| GoPhish Admin | https://10.10.50.10:3333 | admin | (xem log lan chay gan nhat) |
| Wazuh Dashboard | https://172.16.30.100 | admin | `<wazuh-password>` |
| Proxmox GUI | https://192.168.1.10:8006 | root | - |
| pfSense GUI | https://192.168.1.200:4443 | admin | - |

## Active Directory

| Item | Value |
|------|-------|
| Domain | sakuratech.local |
| Domain Controller | win-dc (172.16.21.100) |
| Admin | SAKURATECH\Administrator |
| Admin Password | `<admin-password>` |
| User linhntt | linhntt@sakuratech.local |
| User Password | `<user-password>` |

## Database (iRedMail MariaDB)

| Item | Value |
|------|-------|
| MySQL root password | `<admin-password>` |

## VPN

| Item | Value |
|------|-------|
| DuckDNS Domain | soc-networklab.duckdns.org |
| VPN User | vpnuser |
| Protocol | TCP 443 (primary) / UDP 1194 |

## Cau truc lab — VM chi tiet

| VM | ID | IP | OS | Role | Wazuh Agent |
|----|----|----|----|------|-------------|
| dmz-nginx | CT101 | 10.10.50.10 | Ubuntu 24.04 | GoPhish + Landing Page | ✅ |
| fw-pfsense | VM102 | 10.10.50.1 / 172.16.0.1 | pfSense 2.7 | External Firewall | ❌ |
| mgmt-wazuh | VM103 | 172.16.30.100 | Ubuntu 22.04 | Wazuh SIEM | - |
| dmz-mail | CT107 | 10.10.50.20 | Ubuntu 24.04 | iRedMail 1.8.1 | ✅ |
| dmz-app | CT108 | 10.10.50.30 | Ubuntu 24.04 | (chua dung) | ⏳ |
| srv-mariadb | CT109 | 172.16.20.x | Ubuntu 24.04 | MariaDB | ⏳ |
| fw-mikrotik | VM110 | 172.16.0.2 | MikroTik | Internal Firewall/VLAN | ❌ |
| bkp-server | CT111 | - | Ubuntu 24.04 | Backup | ⏳ |
| prtg-monitor | VM112 | 172.16.30.101 | - | PRTG Monitor | ⏳ |
| jump-kali | VM113 | 172.16.30.102 | Kali Linux | Forensics Jump PC | ✅ |
| win-dc | VM115 | 172.16.21.100 | Windows Server 2022 | AD DC sakuratech.local | ✅ |
| ws-linhntt | VM120 | 172.16.23.101 | Windows 10 Pro | Victim Workstation | ✅ |

## VM can bat khi thuc nghiem

### Case 1
pfsense + mikrotik + dmz-mail + dmz-nginx + ws-linhntt + win-dc + wazuh + kali
**RAM uoc tinh: ~16GB**

### Case 2
pfsense + mikrotik + dmz-mail + win-dc + ws-linhntt + wazuh + kali
**RAM uoc tinh: ~16GB**

## Kich ban 2 Case

### Case 1 — Technical Attack (Spear Phishing + Reverse Shell)

```
Phase 1 (09:00):  GoPhish gui email phishing tu sakura-vendor.com → linhntt
Phase 2 (09:15): linhntt click link → landing page → GoPhish log IP, timestamp
Phase 3 (10:30): Reverse shell ve Kali → whoami → SAKURATECH\linhntt
Phase 4 (11:00): Wazuh bat alert — suspicious outbound connection
                 → Dieu tra: network log, process tree, Windows Event Log
```

### Case 2 — BEC Fraud (Financial)

```
Phase 1 (Day 1, 10:30): Attacker dang nhap mailbox linhntt tu IP nuoc ngoai (Tor exit node)
Phase 2 (Day 1, 11:00): Tao mail rule tu dong forward email tai chinh
Phase 3 (Day 3, 14:00): Attacker gui email BEC tu hop thu linhntt den phongketoan
                          ("Nha cung cap doi tai khoan ngan hang, chuyen khoan gap")
Phase 4 (Day 3, 14:30): Xoa bang chung nhung van con trace
                          → Dieu tra: email header, SPF/DKIM/DMARC FAIL,
                              impossible travel (VN → Germany 75 phut)
```

## Tien do ky thuat

### ✅ Da hoan thanh
- iRedMail 1.8.1 cai tren `CT107` — chay on dinh
- 4 mail accounts tao xong
- GoPhish cai tren `CT101` — gui email thanh cong
- Fake IP headers (X-Originating-IP, X-Forwarded-For, X-Source-IP, X-Mailer)
- Phase 1 — Email phishing gui thanh cong den linhntt
- Phase 2 — Victim click link, GoPhish tracking event logged
- Landing page "CANH BAO BAO MAT" hoat dong
- AD `sakuratech.local` setup tren `win-dc`
- `ws-linhntt` join domain
- Wazuh agents installed tren 5 node
- pfSense + MikroTik + VLAN routing
- VPN OpenVPN qua DuckDNS
- Repo GitHub updated voi IP thuc te

### ⏳ Dang lam
- Wazuh Manager `VM103` dang cai lai (bi loi truoc do)

### ❌ Chua lam
- Verify 5 Wazuh agents ket noi ve manager
- Deploy 12 custom Wazuh rules tu repo
- Reverse shell (dang tim tai lieu)
- Chay kich ban end-to-end Phase 1-6
- Case 2 — BEC fraud simulation
- Dieu tra tu Kali (phan tich header, log, truy IP)

## Tien do bao cao

| Chuong | Noi dung | Status |
|--------|----------|--------|
| Chuong 1 | Gioi thieu de tai | ❌ |
| Chuong 2 | Co so ly thuyet (SMTP, IMAP, POP3, RFC 5322) | ❌ |
| Chuong 3 | Email Header Analysis | ❌ |
| Chuong 4 | SPF / DKIM / DMARC | ❌ |
| Chuong 5 | Phan loai to pham email | ❌ |
| Chuong 6 | Quy trinh Digital Forensics | ❌ |
| Chuong 7 | Case Study — Kich ban kiem thu | ❌ |
| Chuong 8 | Thu thap chung cu | ❌ |
| Chuong 9 | Phuong phap truy vet | ❌ |
| Chuong 10 | Ket luan + Khuyen nghi | ❌ |

## IOC Tong hop

```
Domains:
  sakura-vendor.com         (typosquat phishing sender)
  login-sakura-vendor.com   (phishing landing page)

IPs:
  185.220.101.47            (attacker — Tor exit node, Germany)
  103.45.67.89              (fake relay hop 1)
  45.33.32.156              (fake relay hop 2)

Emails:
  support@sakura-vendor.com (phishing sender)
  attacker@protonmail.com   (forward destination)

SPF/DKIM/DMARC:
  sakura-vendor.com → SPF FAIL, DKIM FAIL, DMARC NONE

Behavioral:
  Impossible travel: VN (09:15) → Germany (10:30) — 75 phut
  Mail forwarding rule: keywords "thanh toan", "chuyen khoan"
  Mass delete event sau Phase 5
```

## MITRE ATT&CK Mapping

| Phase | Technique | ID |
|-------|-----------|-----|
| 1 | Spearphishing Link | T1566.002 |
| 2 | Phishing for Information | T1598 |
| 3 | Valid Accounts | T1078 |
| 4 | Email Forwarding Rule | T1114.003 |
| 4 | Email Hiding Rules | T1564.008 |
| 5 | Compromise Email Accounts | T1586.002 |
| 6 | Clear Mailbox Data | T1070.008 |

## Wazuh Custom Rules

12 rules tuong thich voi cac giai doan tan cong:

| Rule | Mo ta | Muc do |
|------|-------|--------|
| 100001 | Tor exit node login | HIGH |
| 100002 | Tor exit node IMAP | HIGH |
| 100003 | Compromised account access | CRITICAL |
| 100004 | Mail forwarding rule | CRITICAL |
| 100005 | BEC email from foreign IP | CRITICAL |
| 100006 | Phishing domain detected | MEDIUM |
| 100007 | SPF/DKIM/DMARC fail | MEDIUM |
| 100008 | Suspicious sender domain | LOW |
| 100009 | Webmail from foreign IP | MEDIUM |
| 100010 | Mass email deletion | LOW |
| 100011 | Brute force attempt | HIGH |
| 100012 | External forward detected | MEDIUM |

## Link quan trong

| Resource | Link |
|----------|------|
| GitHub Repo | https://github.com/haizzdungnay/Demo-Mail-Phising |
| Wazuh Docs | https://documentation.wazuh.com |
| iRedMail Docs | https://docs.iredmail.org |
| GoPhish Docs | https://docs.getgophish.com |
| MITRE ATT&CK | https://attack.mitre.org |
| LetsDefend | https://letsdefend.io |

## Cai dat nhanh

### 1. Tao VMs tren Proxmox/VMware

Xem bang VM chi tiet o muc "Cau truc lab — VM chi tiet" ben tren.

### 2. Chay setup scripts

```bash
# Copy setup scripts sang VMs
scp lab/setup/107_dmz-mail/setup.sh root@10.10.50.20:/tmp/
ssh root@10.10.50.20 && bash /tmp/setup.sh
```

Lam tuong tu cho cac VM con lai.

### 3. Cau hinh GoPhish

```bash
# Truy cap: https://10.10.50.10:3333
# Default: admin / gophish
```

Import template tu `lab/gophish/templates/`.
Import landing page tu `lab/gophish/landing_pages/`.

### 4. Chay mo phong

```bash
# Tren CT107 dmz-mail:
bash lab/simulation/run_all_phases.sh

# Hoac tung phase:
bash run_all_phases.sh --phase 1
bash run_all_phases.sh --phase 2
```

### 5. Dieu tra so

```bash
# Tren VM113 jump-kali:
cd /opt/forensics
forensic_toolkit.sh all

# Hoac tung buoc:
forensic_toolkit.sh collect
forensic_toolkit.sh timeline
forensic_toolkit.sh report
```

## Bao mat

- Chi trien khai trong mang noi bo, khong public ra Internet
- Doi mat khau mac dinh sau khi cai dat
- Khong gui email ra ngoai to chuc
- Xoa toan bo du lieu sau khi ket thuc lab
- Khong ket noi voi mang san xuat

## Tai lieu tham khao

- Kich ban chi tiet: `lab/DEPLOYMENT_GUIDE.md`
- Topology: `lab/topology/TOPOLOGY.md`
- IOC: `lab/forensics/IOC.md`
- Kich ban goc: `kich ban uu tien 1.txt`
- Kich ban ky thuat: `kich ban uu tien 2 .txt`

Doc `DISCLAIMER.txt` truoc khi su dung.
