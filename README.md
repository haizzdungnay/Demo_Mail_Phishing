# PhishLab — Sakura Tech Email Incident Lab
# "Cái Bẫy Hoàn Hảo"

> Chi muc dich dao tao nhan dien phishing, BEC, va dieu tra so. Chi trien khai trong mang noi bo co phep.

## Kịch bản

Day la lab mo phong tan cong **Business Email Compromise (BEC)** hoan chinh voi 6 giai doan:

```
[Day 1]
  09:00  Phase 1  — Email phishing tu domain gia sakura-vendor.com
  09:15  Phase 2  — Nuoc nhan click link, GoPhish ghi nhan
  10:30  Phase 3  — Ke tan cong dang nhap tu IP nuoc ngoai
  11:00  Phase 4  — Tao mail rule tu dong forward email tai chinh

[Day 3]
  14:00  Phase 5  — Ke tan cong gui email BEC tu hop thu linhntt
  14:30  Phase 6  — Xoa bang chung nhung van con trace
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
│   ├── 100_srv-victim/ Victim simulation
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

## Cai dat nhanh

### 1. Tao 6 VMs tren Proxmox/VMware

| VM | IP | OS | Role |
|----|----|----|------|
| dmz-mail | 10.71.119.51 | Ubuntu 24.04 | iRedMail |
| dmz-nginx | 10.71.119.101 | Ubuntu 24.04 | GoPhish |
| mgmt-wazuh | 10.71.120.103 | Ubuntu 22.04 | Wazuh SIEM |
| srv-victim | 10.71.121.100 | Ubuntu 24.04 | Victim |
| jump-kali | 10.71.120.113 | Kali Linux | Forensics |
| fw-pfsense | multi | pfSense 2.7 | Firewall |

### 2. Chay setup scripts

```bash
# Copy setup scripts sang VMs
scp lab/setup/107_dmz-mail/setup.sh root@10.71.119.51:/tmp/
ssh root@10.71.119.51 && bash /tmp/setup.sh
```

Lam tuong tu cho cac VM con lai.

### 3. Cau hinh GoPhish

```bash
# Truy cap: http://10.71.119.101:3333
# Default: admin / gophish
```

Import template tu `lab/gophish/templates/`.
Import landing page tu `lab/gophish/landing_pages/`.

### 4. Chay mo phong

```bash
# Tren 107 dmz-mail:
bash lab/simulation/run_all_phases.sh

# Hoac tung phase:
bash run_all_phases.sh --phase 1
bash run_all_phases.sh --phase 2
```

### 5. Dieu tra so

```bash
# Tren 113 jump-kali:
cd /opt/forensics
forensic_toolkit.sh all

# Hoac tung buoc:
forensic_toolkit.sh collect
forensic_toolkit.sh timeline
forensic_toolkit.sh report
```

## Cong cu trong lab

| Cong cu | Dia chi | Mat khau | Chuc nang |
|---------|---------|----------|-----------|
| GoPhish Admin | http://10.71.119.101:3333 | admin/gophish | Quan ly campaign |
| iRedAdmin | https://10.71.119.51/iredadmin | postmaster/Intern#2026 | Quan ly mail |
| Roundcube | https://10.71.119.51/mail | linhntt/Victim@2026! | Webmail |
| Wazuh | https://10.71.120.103 | admin/WazuhLab2026! | SIEM dashboards |
| Kali Tools | 10.71.120.113 | root/(ban dat) | Forensics |

## Danh sach tai khoan mail

| Email | Mat khau | Vai tro |
|-------|----------|---------|
| postmaster@sakuratech.local | Intern#2026 | Admin |
| linhntt@sakuratech.local | Victim@2026! | Ke toan truong (nan nhan) |
| ducmh@sakuratech.local | CEO@2026! | CEO |
| phongketoan@sakuratech.local | Staff@2026! | Phong ke toan |

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

## IOC Tong hop

```
Domains:
  sakura-vendor.com        (phishing sender)
  login-sakura-vendor.com  (phishing landing)
  attacker@protonmail.com   (forward destination)

IPs:
  185.220.101.47          (attacker — Tor exit, Germany)

Auth failures:
  SPF: FAIL on sakura-vendor.com
  DKIM: FAIL on sakura-vendor.com
  DMARC: NONE on sakura-vendor.com

Behavioral:
  Impossible travel: VN -> Germany in 75 min
  Mail rule: forward "thanh toan", "chuyen khoan"
```

## MITRE ATT&CK

| Phase | Technique | ID |
|-------|-----------|-----|
| 1 | Spearphishing Link | T1566.002 |
| 2 | Phishing for Information | T1598 |
| 3 | Valid Accounts | T1078 |
| 4 | Email Forwarding Rule | T1114.003 |
| 4 | Email Hiding Rules | T1564.008 |
| 5 | Compromise Email Accounts | T1586.002 |
| 6 | Clear Mailbox Data | T1070.008 |

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
