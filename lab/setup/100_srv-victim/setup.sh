#!/bin/bash
# ============================================================
# SETUP: 100 srv-victim — Victim Simulation
# OS: Ubuntu 24.04 LTS (LXC)
# Role: Simulate victim clicking phishing link
# IP: 10.71.121.100
# ============================================================

set -e

echo "[100] === Victim Simulation Setup ==="

# --- Network ---
cat > /etc/netplan/50-cloud-init.yaml <<'NETCFG'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 10.71.121.100/24
      nameservers:
        addresses:
          - 10.71.119.1
          - 8.8.8.8
      routes:
        - to: default
          via: 10.71.121.1
NETCFG

netplan apply

# --- Install simulation tools ---
apt-get update
apt-get install -y \
    curl wget \
    firefox-esr chromium-browser \
    python3 python3-pip \
    ufw \
    tmux htop

# --- Install Wazuh Agent ---
echo "[100] Installing Wazuh agent..."
curl -sO https://packages.wazuh.com/4.8/wazuh-agent_latest_amd64.deb
dpkg -i wazuh-agent_latest_amd64.deb

# Configure Wazuh agent
cat > /var/ossec/etc/ossec.conf <<'OSSEC_AGENT'
<ossec_config>
  <client>
    <server>
      <address>10.71.120.103</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
  </client>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>

  <rootcheck>
    <disabled>yes</disabled>
  </rootcheck>

  <wodle name="syscollector">
    <disabled>yes</disabled>
  </wodle>
</ossec_config>
OSSEC_AGENT

/var/ossec/bin/agent-auth -m 10.71.120.103 -p 1514 || true
systemctl enable wazuh-agent
systemctl start wazuh-agent

# --- Firewall ---
ufw default deny incoming
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow out 53/udp
ufw allow out 80/tcp
ufw allow out 443/tcp
ufw enable

# --- Add DNS entries for phishing domain ---
echo "[100] Adding phishing domain to /etc/hosts..."
cat >> /etc/hosts <<'HOSTS_ENTRIES'
# Phishing domain simulation
10.71.119.101  login-sakura-vendor.com
10.71.119.101  sakura-vendor.com
HOSTS_ENTRIES

# --- Download phishing page locally for simulation ---
mkdir -p /var/www/html/phishing
wget -q "http://10.71.119.101:8080" -O /var/www/html/phishing/index.html || true

# --- Create simulation scripts ---
mkdir -p /opt/simulation
cat > /opt/simulation/victim_simulation.sh <<'VICTIM_SCRIPT'
#!/bin/bash
# ============================================================
# VICTIM SIMULATION — Run on node 100 (srv-victim)
# Simulates Chị Linh opening phishing email and clicking link
# ============================================================

GOPHISH_URL="http://10.71.119.101:8080"
TRACKING_ID="${1:-test123}"

echo "[VICTIM] Starting victim simulation..."
echo "[VICTIM] Victim: linhntt@sakuratech.local"

# Record start time
START_TIME=$(date '+%Y-%m-%dT%H:%M:%S')
echo "[VICTIM] Simulation started at: $START_TIME"

# Simulate email open (trigger tracking pixel)
echo "[VICTIM] Step 1: Opening phishing email (tracking pixel)..."
curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
     -H "X-Forwarded-For: 10.71.121.100" \
     "${GOPHISH_URL}/track/open/${TRACKING_ID}" \
     -o /dev/null

sleep 2

# Simulate link click
echo "[VICTIM] Step 2: Clicking phishing link..."
curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
     -H "X-Forwarded-For: 10.71.121.100" \
     "${GOPHISH_URL}/track/click/${TRACKING_ID}" \
     -o /dev/null

echo "[VICTIM] Step 3: Visiting phishing landing page..."
curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
     -H "X-Forwarded-For: 10.71.121.100" \
     "${GOPHISH_URL}" -o /dev/null

# Simulate form submission (credential capture)
echo "[VICTIM] Step 4: Simulating credential submission..."
curl -s -X POST "${GOPHISH_URL}/submit" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "email=linhntt@sakuratech.local&password=Victim@2026!" \
     -H "X-Forwarded-For: 10.71.121.100" \
     -o /dev/null

echo "[VICTIM] Simulation complete at: $(date '+%Y-%m-%dT%H:%M:%S')"
echo "[VICTIM] All events logged in GoPhish dashboard"
VICTIM_SCRIPT

chmod +x /opt/simulation/victim_simulation.sh

echo "[100] === Setup Complete ==="
echo "[100] IP: 10.71.121.100"
echo "[100] Run simulation: /opt/simulation/victim_simulation.sh <tracking_id>"
echo "[100] Access Roundcube: https://10.71.119.51/mail"
echo "[100] Login: linhntt@sakuratech.local / Victim@2026!"
echo "[100] Wazuh Agent: Connected to 10.71.120.103"
