#!/bin/bash
# ============================================================
# SETUP: 103 mgmt-wazuh — Wazuh SIEM Server
# OS: Ubuntu 22.04 LTS (VM)
# Role: SIEM — Log collection, alerting, dashboards
# IP: 10.71.120.103
# ============================================================

set -e

echo "[103] === Wazuh SIEM Server Setup ==="

# --- Network ---
cat > /etc/netplan/50-cloud-init.yaml <<'NETCFG'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 10.71.120.103/24
      nameservers:
        addresses:
          - 10.71.120.1
          - 8.8.8.8
      routes:
        - to: default
          via: 10.71.120.1
NETCFG

netplan apply

# --- Install Wazuh Stack ---
echo "[103] Installing Wazuh 4.8.2..."

# Add Wazuh GPG key
curl -sO https://packages.wazuh.com/key/GPG-KEY-WAZUH
apt-key add GPG-KEY-WAZUH
echo "deb https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list

apt-get update

# Install Wazuh Manager + ELK Stack (all-in-one)
apt-get install -y \
    wazuh-manager \
    wazuh-indexer \
    wazuh-server \
    wazuh-dashboard \
    wazuh-agent

# --- Configure Wazuh Manager ---
sed -i 's/<bind_addr>.*<\/bind_addr>/<bind_addr>0.0.0.0<\/bind_addr>/' \
    /var/ossec/etc/ossec.conf

# Enable agent communication
sed -i 's/<client>\s*<\/client>/<client><server><name>mgmt-wazuh<\/name><address>10.71.120.103<\/address><\/server><\/client>/' \
    /var/ossec/etc/ossec.conf || true

# --- Install Custom Rules ---
echo "[103] Installing custom Wazuh rules..."
mkdir -p /var/ossec/etc/rules
cp -r /tmp/lab/wazuh/rules/*.xml /var/ossec/etc/rules/
chown ossec:ossec /var/ossec/etc/rules/*.xml

# --- Install Custom Decoders ---
echo "[103] Installing custom Wazuh decoders..."
mkdir -p /var/ossec/etc/decoders
cp -r /tmp/lab/wazuh/decoders/*.xml /var/ossec/etc/decoders/
chown ossec:ossec /var/ossec/etc/decoders/*.xml

# --- Configure Filebeat for Elasticsearch ---
cat > /etc/filebeat/filebeat.yml <<'FILEBEAT_CONFIG'
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/mail.log
      - /var/log/dovecot.log
      - /var/log/nginx/access.log
    fields:
      log_type: mail_server
    fields_under_root: true

  - type: log
    enabled: true
    paths:
      - /var/ossec/logs/alerts/alerts.json
    fields:
      log_type: wazuh_alerts
    fields_under_root: true

output.elasticsearch:
  hosts: ["localhost:9200"]
  username: "admin"
  password: "WazuhLab2026!"
  ssl.certificate_authorities: ["/etc/wazuh-indexer/certs/root-ca.pem"]
  ssl.certificate: "/etc/wazuh-indexer/certs/wazuh-server.pem"
  ssl.key: "/etc/wazuh-indexer/certs/wazuh-server-key.pem"

setup.template.settings:
  index.number_of_shards: 1

setup.kibana:
  host: "localhost:5601"
FILEBEAT_CONFIG

# --- Configure Elasticsearch ---
cat > /etc/wazuh-indexer/opensearch.yml <<'OPENSEARCH_CONFIG'
network.host: 0.0.0.0
node.name: wazuh-node-1
cluster.name: wazuh-cluster
cluster.initial_master_nodes: wazuh-node-1
discovery.type: single-node
plugins.security.ssl.http.enabled: false
plugins.security.disabled: true
OPENSEARCH_CONFIG

# --- Configure Kibana/Dashboard ---
sed -i 's/server.host: "localhost"/server.host: "0.0.0.0"/' \
    /etc/wazuh-dashboard/wazuh-dashboard.yml

# --- Firewall ---
apt-get install -y ufw
ufw default deny incoming
ufw allow 22/tcp
ufw allow 1514/tcp   # Wazuh agent
ufw allow 1515/tcp   # Wazuh auth
ufw allow 9200/tcp   # Elasticsearch
ufw allow 5601/tcp   # Kibana
ufw allow 443/tcp    # Wazuh Dashboard
ufw enable

# --- Enable & Start Services ---
systemctl daemon-reload
systemctl enable wazuh-manager
systemctl enable wazuh-indexer
systemctl enable wazuh-dashboard
systemctl enable wazuh-server

systemctl start wazuh-indexer
sleep 5
systemctl start wazuh-manager
systemctl start wazuh-server
systemctl start wazuh-dashboard

# --- Generate passwords ---
echo "[103] Setting up admin password..."
export JAVA_HOME=/usr/share/wazuh-indexer/jdk
/usr/share/wazuh-indexer/plugins/security/securityadmin/scripts/securityadmin.sh \
    -cd /usr/share/wazuh-indexer/plugins/security/securityadmin/scripts/ \
    -icl -key /etc/wazuh-indexer/certs/wazuh-node-1-key.pem \
    -cert /etc/wazuh-indexer/certs/wazuh-node-1.pem \
    -cacert /etc/wazuh-indexer/certs/root-ca.pem -p 9200 || true

echo "[103] === Setup Complete ==="
echo "[103] Wazuh Dashboard: https://10.71.120.103"
echo "[103] Elasticsearch:   https://10.71.120.103:9200"
echo "[103] Default user:     admin / WazuhLab2026!"
echo "[103] Agent port:       10.71.120.103:1514"
echo "[103]"
echo "[103] Install agents on other nodes:"
echo "[103]   curl -sO https://packages.wazuh.com/4.8/wazuh-agent_latest_amd64.deb"
echo "[103]   sudo dpkg -i wazuh-agent_latest_amd64.deb"
echo "[103]   sudo /var/ossec/bin/agent-auth -m 10.71.120.103 -p 1514"
echo "[103]   sudo systemctl enable wazuh-agent && sudo systemctl start wazuh-agent"
