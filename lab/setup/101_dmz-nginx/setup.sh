#!/bin/bash
# ============================================================
# SETUP: 101 dmz-nginx — GoPhish + Landing Pages
# OS: Ubuntu 24.04 LTS (LXC)
# Role: Phishing campaign management + Landing pages
# IP: 10.71.119.101
# ============================================================

set -e

echo "[101] === GoPhish + Nginx Setup ==="

# --- Network ---
cat > /etc/netplan/50-cloud-init.yaml <<'NETCFG'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 10.71.119.101/24
      nameservers:
        addresses:
          - 10.71.119.1
          - 8.8.8.8
      routes:
        - to: default
          via: 10.71.119.1
NETCFG

netplan apply

# --- Install GoPhish ---
echo "[101] Installing GoPhish 0.12.1..."

cd /tmp

# Download GoPhish
if [ ! -f /tmp/gophish-v0.12.1-linux-64bit.zip ]; then
    wget -q https://github.com/gophish/gophish/releases/download/v0.12.1/gophish-v0.12.1-linux-64bit.zip
fi

apt-get update
apt-get install -y unzip curl wget nginx

# Install GoPhish
mkdir -p /opt/gophish
unzip -o gophish-v0.12.1-linux-64bit.zip -d /opt/gophish
chmod +x /opt/gophish/gophish

# --- Configure GoPhish ---
cat > /opt/gophish/config.json <<'GOPHISH_CONFIG'
{
    "admin_server": {
        "listen_url": "0.0.0.0:3333",
        "use_tls": false,
        "cert_path": "",
        "key_path": ""
    },
    "phish_server": {
        "listen_url": "0.0.0.0:8080",
        "use_tls": false,
        "cert_path": "",
        "key_path": "",
        "api_keys": []
    },
    "db_name": "sqlite3",
    "db_path": "/opt/gophish/gophish.db",
    " migrate_db": true,
    "mail_server": {
        "from_address": "phishing-gophish@localhost",
        "host": "",
        "port": 25,
        "use_tls": false,
        "use_starttls": false,
        "username": "",
        "password": ""
    },
    "captured_credentials_cooldown": "10s",
    "cleanup_duration": "60m",
    "pipe_timeout": "10s"
}
GOPHISH_CONFIG

# --- Create landing pages directory ---
mkdir -p /opt/gophish/static
mkdir -p /opt/gophish/templates

# --- Nginx reverse proxy for HTTPS (optional) ---
cat > /etc/nginx/sites-available/gophish <<'NGINX_CONF'
server {
    listen 8443 ssl;
    server_name 10.71.119.101;

    ssl_certificate /etc/ssl/certs/gophish.crt;
    ssl_certificate_key /etc/ssl/private/gophish.key;

    location / {
        proxy_pass http://127.0.0.1:3333;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_CONF

# Generate self-signed cert for HTTPS (optional)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/gophish.key \
    -out /etc/ssl/certs/gophish.crt \
    -subj "/CN=10.71.119.101/O=SakuraTech/C=VN"

# --- Systemd service ---
cat > /etc/systemd/system/gophish.service <<'SERVICE_UNIT'
[Unit]
Description=GoPhish Phishing Framework
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/gophish
ExecStart=/opt/gophish/gophish
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_UNIT

systemctl daemon-reload
systemctl enable gophish

# --- Firewall ---
apt-get install -y ufw
ufw default deny incoming
ufw allow 22/tcp
ufw allow 8080/tcp   # GoPhish phishing pages
ufw allow 3333/tcp   # GoPhish admin
ufw allow 8443/tcp   # HTTPS admin
ufw enable

# --- Install Wazuh Agent ---
echo "[101] Installing Wazuh agent..."
curl -sO https://packages.wazuh.com/4.8/wazuh-agent_latest_amd64.deb
dpkg -i wazuh-agent_latest_amd64.deb
sed -i 's/MANAGER_IP/10.71.120.103/' /var/ossec/etc/ossec.conf
systemctl enable wazuh-agent
systemctl start wazuh-agent

# --- SSH Hardening ---
sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

# --- Start GoPhish ---
systemctl start gophish

echo "[101] === Setup Complete ==="
echo "[101] GoPhish Admin UI: http://10.71.119.101:3333"
echo "[101] Default login: admin / gophish"
echo "[101] CHANGE PASSWORD IMMEDIATELY after first login!"
echo "[101] Landing pages: http://10.71.119.101:8080"
echo "[101] SMTP via Mail server: 10.71.119.51:25"
echo "[101]"
echo "[101] IMPORTANT: Change default admin password!"
echo "[101] GOPHISH_API_KEY will be generated on first login."
