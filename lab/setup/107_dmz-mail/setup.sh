#!/bin/bash
# ============================================================
# SETUP: 107 dmz-mail — iRedMail Mail Server
# OS: Ubuntu 24.04 LTS (LXC privileged)
# Role: SMTP/IMAP/POP3 + Roundcube + iRedAdmin
# IP: 10.71.119.51
# ============================================================

set -e

echo "[107] === iRedMail Mail Server Setup ==="

# --- Hostname & Network ---
hostnamectl set-hostname dmz-mail.sakuratech.local
hostnamectl set-location "DMZ Network"

# Set static IP
cat > /etc/netplan/50-cloud-init.yaml <<'NETCFG'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 10.71.119.51/24
      nameservers:
        addresses:
          - 10.71.119.1
          - 8.8.8.8
      routes:
        - to: default
          via: 10.71.119.1
NETCFG

netplan apply

# --- Firewall ---
apt-get update
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp     # SSH
ufw allow 25/tcp     # SMTP
ufw allow 143/tcp    # IMAP
ufw allow 993/tcp    # IMAPS
ufw allow 995/tcp    # POP3S
ufw allow 80/tcp     # HTTP (redirect)
ufw allow 443/tcp    # HTTPS (Roundcube + iRedAdmin)
ufw enable

# --- iRedMail Installation ---
cd /tmp

# Download iRedMail
if [ ! -f /tmp/iRedMail.sh ]; then
    wget https://github.com/iredmail/iRedMail/archive/refs/tags/1.8.1.tar.gz -O iRedMail.tar.gz
    tar xzf iRedMail.tar.gz
fi

cd iRedMail-1.8.1

# Pre-install
apt-get install -y \
    wget curl git bzip2 rsync \
    bc sudo p7zip-full \
    unzip libnet-ssleay-perl \
    libauthen-pam-perl libipc-run3-perl \
    libencode-detect-perl libdbd-sqlite3-perl \
    apt-show-versions html2text \
    libwww-perl libnet-ssleay-perl

# Run iRedMail installer (non-interactive)
export IREDMAIL_SKIP_CERT=yes

# NOTE: For fully automated install, use answer file:
cat > /tmp/iredmail_answers.txt <<'ANSWERS'
HOSTNAME=dmz-mail
FIRST_DOMAIN=sakuratech.local
MYSQL_ROOT_PASSWORD=StrongRootPass2026!
VMAIL_DB_PASSWORD=StrongVmailPass2026!
IREDADMIN_DB_PASSWORD=StrongAdminPass2026!
SOGO_DB_PASSWORD=StrongSogoPass2026!
IREDAPD_DB_PASSWORD=StrongIredapdPass2026!
MLMMJADMIN_DB_PASSWORD=StrongMlmmjPass2026!
ROUNDCUBE_DB_PASSWORD=StrongRoundcubePass2026!
NETWORK_INTERFACE=eth0
USE_IREDMAIL_SQLITE=yes
AVAILABLE_BACKENDS="SQLite"
MLMMJADMIN_PORT=7790
SOGO_WORKERS=3
SOGO_SERVER_PORT=20000
IREDAPD_PORT=7777
USE_LETSENCRYPT=no
SSL_COUNTRY=VN
SSL_STATE=HCMC
SSL_CITY="Ho Chi Minh City"
SSL_ORG=SakuraTech
SSL_OU=IT
SSL_COMMONNAME=mail.sakuratech.local
SKIP_LETSENCRYPT=y
FIRST_USER=postmaster
FIRST_PASS=Intern#2026
FIRST_USER_FULLNAME="Postmaster"
WITH_ROUNDCUBE=y
WITH_SOGO=y
WITH_IREDADMIN=y
WITH_IREDAPD=y
WITH_MLMMJADMIN=y
WITH_AMAVIS=y
WITH_FAIL2BAN=y
WITH_NETDATA=y
CLUEVEB_RCPT_LIMIT=100
KEEP_MLMMJ_SETTINGS_AFTER_UPGRADE=y
ANSWERS

chmod +x /tmp/iRedMail-1.8.1/iRedMail.sh

echo "[107] iRedMail installer ready. Run manually with:"
echo "  cd /tmp/iRedMail-1.8.1 && bash iRedMail.sh"
echo "[107] Use answer file: /tmp/iredmail_answers.txt"
echo "[107] IMPORTANT: Set MySQL root password: StrongRootPass2026!"

# --- Create Mail Users ---
echo "[107] Creating mail users after iRedMail installation..."
sleep 5

# Add users via iRedAdmin API or directly
# Users will be created after iRedMail is installed
cat > /tmp/create_users.sh <<'CREATEUSERS'
#!/bin/bash
# Create mail users for Sakura Tech

# Helper: add user via iRedAdmin SQL
add_user() {
    local email="$1"
    local password="$2"
    local name="$3"
    local quota="${4:-1024}"

    local storage_base_directory="/var/vmail"
    local maildir="${storage_base_directory}/${email##*@}/${email%%@}"
    local password_hash=$(doveadm pw -s SHA512-CRYPT -p "$password" 2>/dev/null || echo "")

    # Create maildir
    mkdir -p "${storage_base_directory}/${email##*@}/${email%%@}/cur"
    mkdir -p "${storage_base_directory}/${email##*@}/${email%%@}/new"
    mkdir -p "${storage_base_directory}/${email##*@}/${email%%@}/tmp"

    # Add to SQLite (if using SQLite backend)
    if [ -f /opt/iredadmin/iredmail.py ]; then
        cd /opt/iredadmin
        python3 -c "
import sys
sys.path.insert(0, '/opt/iredadmin')
from libs import iredutils
from settings import SQLITE_DBFILE
import sqlite3, hashlib, os, secrets

db = SQLITE_DBFILE
password_sha512 = hashlib.sha512(password.encode()).hexdigest()

conn = sqlite3.connect(db)
cur = conn.cursor()

# Check if user exists
cur.execute('SELECT username FROM mailbox WHERE username=?', (email,))
if cur.fetchone():
    print(f'[SKIP] User {email} already exists')
else:
    # Insert into mailbox
    cur.execute('''
        INSERT INTO mailbox (username, password, name, storagebasedirectory,
                            maildir, quota, domain, isadmin, isglobaladmin,
                            active, created, modified)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
    ''', (email, password_sha512, name, storage_base_directory,
          f"{email##*@}/{email%%@}", quota * 1024 * 1024, email.split('@')[1],
          0, 0, 1))
    conn.commit()
    print(f'[OK] Created user {email}')
conn.close()
"
    fi
}

# Add users
add_user "linhntt@sakuratech.local" "Victim@2026!" "Nguyen Thi Linh - Ke toan truong" 2048
add_user "ducmh@sakuratech.local" "CEO@2026!" "Dinh Cao Minh - CEO" 2048
add_user "hoangnt@sakuratech.local" "Staff@2026!" "Nguyen Tan Hoang - Nhan vien TC" 1024
add_user "phongketoan@sakuratech.local" "Staff@2026!" "Phong Ke Toan" 1024
CREATEUSERS

chmod +x /tmp/create_users.sh

# --- Install Wazuh Agent ---
echo "[107] Installing Wazuh agent..."
curl -sO https://packages.wazuh.com/4.8/wazuh-agent_latest_amd64.deb
dpkg -i wazuh-agent_latest_amd64.deb

# Configure Wazuh agent
sed -i 's/MANAGER_IP/10.71.120.103/' /var/ossec/etc/ossec.conf
sed -i 's/10.71.121.100/10.71.119.51/' /var/ossec/etc/ossec.conf
/var/ossec/bin/agent-auth -m 10.71.120.103 -p 1514 || true
systemctl enable wazuh-agent
systemctl start wazuh-agent

echo "[107] === Setup Complete ==="
echo "[107] Services:"
echo "  - SMTP:     10.71.119.51:25"
echo "  - IMAP:     10.71.119.51:143"
echo "  - Webmail:  https://10.71.119.51/mail (Roundcube)"
echo "  - Admin:    https://10.71.119.51/iredadmin"
echo "  - Default:   postmaster@sakuratech.local / Intern#2026"
echo ""
echo "[107] Next: Run iRedMail installer manually, then /tmp/create_users.sh"
