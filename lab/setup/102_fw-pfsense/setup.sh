#!/bin/bash
# ============================================================
# SETUP: 102 fw-pfsense — pfSense Firewall
# OS: pfSense CE 2.7.x
# Role: Edge firewall, VLAN segmentation, NAT
# ============================================================
# NOTE: This is the CONFIGURATION guide for pfSense.
# pfSense is typically installed via ISO, not scripted.
# Run this AFTER pfSense ISO installation.
# ============================================================

set -e

echo "[102] === pfSense Firewall Configuration Guide ==="
echo "[102] This script provides the commands to run via pfSense WebGUI"
echo "[102] or via SSH (admin/pfsense)"

# --- Network Interface Assignments ---
# Via WebGUI: Interfaces > Assignments
#
# Interface 1 (WAN): 连接到上游网络/DHCP
# Interface 2 (LAN/DMZ): 10.71.119.1/24  → DMZ VLAN10
# Interface 3 (OPT1/MGMT): 10.71.120.1/24 → MGMT VLAN20
# Interface 4 (OPT2/LAN): 10.71.121.1/24   → Victim LAN VLAN30

# --- VLAN Configuration ---
# Via WebGUI: Interfaces > VLANs
#
# Parent Interface: (your LAN NIC, e.g. igb0)
# VLAN Tag 10 — DMZ:     10.71.119.0/24
# VLAN Tag 20 — MGMT:    10.71.120.0/24
# VLAN Tag 30 — Victim:   10.71.121.0/24

# --- Static Routes ---
# Via WebGUI: System > Routing > Routes
#
# Gateway DMZ:  10.71.119.1 (interface DMZ)
# Gateway MGMT: 10.71.120.1 (interface MGMT)
# Gateway LAN:  10.71.121.1 (interface LAN2)

# --- NAT Rules ---
# Via WebGUI: Firewall > NAT > Outbound
#
# Outbound NAT rule: LAN/MGMT/DMZ to any → WAN (auto)
# Port forwards:
#   WAN:443 → 10.71.119.51:443 (Mail server)
#   WAN:3333 → 10.71.119.101:3333 (GoPhish — if needed)

# --- Firewall Rules ---
# Via WebGUI: Firewall > Rules

cat > /tmp/pfsense_rules.txt <<'PF_RULES'
# ============================================================
# pfSense Firewall Rules Configuration
# Apply via WebGUI: Firewall > Rules
# ============================================================

# --- WAN Rules (Block all inbound by default) ---
# Already default deny on WAN

# --- DMZ Rules (10.71.119.0/24) ---
# Allow DMZ → MGMT (Wazuh agent)
ALLOW  DMZ  → MGMT  TCP 1514    "Wazuh Agent"
# Allow DMZ → LAN (IMAP access)
ALLOW  DMZ  → LAN   TCP 143     "IMAP access"
# Allow DMZ → WAN (SMTP outbound)
ALLOW  DMZ  → WAN   TCP 25      "SMTP outbound"
# Allow DMZ → MGMT (Kibana access)
ALLOW  DMZ  → MGMT  TCP 5601    "Kibana"
# Block DMZ → LAN (isolation)
BLOCK  DMZ  → LAN   *           "DMZ cannot access Victim LAN"

# --- MGMT Rules (10.71.120.0/24) ---
# Allow MGMT → DMZ (all)
ALLOW  MGMT → DMZ  *           "MGMT full access to DMZ"
# Allow MGMT → LAN (all)
ALLOW  MGMT → LAN  *           "MGMT full access to Victim LAN"
# Allow MGMT → WAN (NTP, DNS, HTTP/S)
ALLOW  MGMT → WAN  TCP 53,80,443 "MGMT internet access"
# Block MGMT → WAN SMTP
BLOCK  MGMT → WAN  TCP 25      "Block SMTP from MGMT"

# --- LAN Rules (10.71.121.0/24) ---
# Allow LAN → DMZ Mail (HTTPS)
ALLOW  LAN  → DMZ  TCP 443     "Victim access mail web"
# Allow LAN → DMZ Phishing (HTTP)
ALLOW  LAN  → DMZ  TCP 8080    "Victim access phishing pages"
# Allow LAN → MGMT (DNS, Wazuh agent)
ALLOW  LAN  → MGMT TCP 1514    "Wazuh agent"
ALLOW  LAN  → MGMT UDP 53      "DNS"
# Block LAN → WAN (only allow via proxy if needed)
BLOCK  LAN  → WAN  *           "Block direct internet from Victim"

# --- DNS Resolution ---
# Via WebGUI: Services > DNS Resolver > General
#
# Enable DNS Resolver
# Add overrides:
#   mail.sakuratech.local     → 10.71.119.51
#   wazuh.sakuratech.local    → 10.71.120.103
#   phishing.sakuratech.local → 10.71.119.101
#   sakura-vendor.com          → 10.71.119.101
#   login-sakura-vendor.com     → 10.71.119.101

# --- DHCP (optional for victim LAN) ---
# Via WebGUI: Services > DHCP Server > LAN2
#
# Range: 10.71.121.10 - 10.71.121.200
# Gateway: 10.71.121.1
# DNS: 10.71.121.1 (pfSense resolver)
# Domain: sakuratech.local

# --- Fail2Ban / Intrusion Detection ---
# Via WebGUI: Services > Intrusion Detection
#
# Enable Snort/Suricata on WAN
# Enable ET rules (emerging threats)
# Enable community rules
# Alert on: external IPs connecting to internal services
PF_RULES

# --- Generate pfSense config backup commands ---
cat > /tmp/pfsense_setup_commands.sh <<'PF_SETUP'
#!/bin/bash
# Run these commands via pfSense SSH or Diagnostics > Command
# ssh admin@10.71.120.1 (or whatever your MGMT IP is)

# --- Set Hostname ---
# via WebGUI: System > General Setup > Hostname

# --- Set DNS ---
# via WebGUI: System > General Setup
# DNS servers: 8.8.8.8, 8.8.4.4
# Allow DNS server override: Yes

# --- Enable VLANs ---
# via WebGUI: Interfaces > VLANs

# Example via config.xml snippet (import carefully):
cat << 'CONFIGXML' > /tmp/pfsense_partial.xml
<vlans>
  <vlan>
    <if>igb0</if>
    <tag>10</tag>
    <descr>DMZ Network</descr>
  </vlan>
  <vlan>
    <if>igb0</if>
    <tag>20</tag>
    <descr>MGMT Network</descr>
  </vlan>
  <vlan>
    <if>igb0</if>
    <tag>30</tag>
    <descr>Victim LAN</descr>
  </vlan>
</vlans>

<interfaces>
  <opt1>
    <descr>DMZ</descr>
    <if>igb0.10</if>
    <ipaddr>10.71.119.1</ipaddr>
    <subnet>24</subnet>
  </opt1>
  <opt2>
    <descr>MGMT</descr>
    <if>igb0.20</if>
    <ipaddr>10.71.120.1</ipaddr>
    <subnet>24</subnet>
  </opt2>
  <opt3>
    <descr>VICTIM_LAN</descr>
    <if>igb0.30</if>
    <ipaddr>10.71.121.1</ipaddr>
    <subnet>24</subnet>
  </opt3>
</interfaces>
CONFIGXML

echo "[102] pfSense configuration saved to /tmp/pfsense_partial.xml"
echo "[102] Import via WebGUI: Diagnostics > Backup & Restore > Restore"
echo "[102] Or manually configure via WebGUI using the guide above."
PF_SETUP

echo ""
echo "[102] === pfSense Setup Guide ==="
echo "[102]"
echo "[102] 1. Download pfSense CE ISO from https://www.pfsense.org/download/"
echo "[102] 2. Install on VM with 2+ NICs"
echo "[102] 3. Assign interfaces via console:"
echo "[102]    WAN → connected to upstream network"
echo "[102]    LAN → DMZ (10.71.119.1/24)"
echo "[102]    OPT1 → MGMT (10.71.120.1/24)"
echo "[102]    OPT2 → Victim LAN (10.71.121.1/24)"
echo "[102] 4. Configure via WebGUI: https://10.71.120.1"
echo "[102] 5. Follow the rules in /tmp/pfsense_rules.txt"
echo "[102]"
echo "[102] IMPORTANT SECURITY NOTES:"
echo "[102] - Change admin password immediately"
echo "[102] - Enable SSH with key-based auth only"
echo "[102] - Block all inbound on WAN by default"
echo "[102] - Enable pfBlockerNG for IP blocklists (optional)"
