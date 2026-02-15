#!/bin/bash
#
# Juri Server Setup Script
# Setup validation/checker server with all necessary tools
#

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔍 JURI SERVER - Configuration Validator Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root"
    exit 1
fi

echo "[1/7] Updating system..."
apt update
apt upgrade -y

echo "[2/7] Installing Ansible and dependencies..."
apt install -y ansible python3-pip git curl wget net-tools dnsutils

echo "[3/7] Installing Python dependencies..."
pip3 install pymysql

echo "[4/7] Installing network tools..."
apt install -y nmap tcpdump netcat-openbsd telnet ftp lftp

echo "[5/7] Installing validation tools..."
apt install -y bind9-utils ldap-utils mysql-client snmp snmp-mibs-downloader

echo "[6/7] Cloning LKS automation repository..."
cd /root
if [ -d "lks-debian-2025" ]; then
    echo "Repository already exists, pulling latest..."
    cd lks-debian-2025
    git pull
else
    git clone https://github.com/Areyoufunn/lks-debian-2025.git
    cd lks-debian-2025
fi

echo "[7/7] Setting up SSH keys for server access..."
cd /root/lks-debian-2025
chmod +x setup-juri-ssh-keys.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ⚠️  SSH KEY DISTRIBUTION REQUIRED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To distribute SSH keys to all servers, run:"
echo "  ./setup-juri-ssh-keys.sh"
echo ""
echo "This will:"
echo "  1. Generate SSH key pair"
echo "  2. Copy public key to all 8 servers"
echo "  3. Enable passwordless SSH access"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Juri Server Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Installed Tools:"
echo "  ✓ Ansible - Configuration management & validation"
echo "  ✓ Network tools - nmap, tcpdump, netcat"
echo "  ✓ DNS tools - dig, nslookup, host"
echo "  ✓ LDAP tools - ldapsearch, ldapwhoami"
echo "  ✓ MySQL client - Database testing"
echo "  ✓ SNMP tools - snmpwalk, snmpget"
echo ""
echo "Repository cloned to: /root/lks-debian-2025"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📋 USAGE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Setup SSH keys to all servers:"
echo "   ssh-keygen -t rsa"
echo "   ssh-copy-id root@fw-srv"
echo "   ssh-copy-id root@int-srv"
echo "   # ... etc"
echo ""
echo "2. Update inventory with server IPs:"
echo "   nano /root/lks-debian-2025/ansible/inventory/hosts.ini"
echo ""
echo "3. Run validation on all servers:"
echo "   cd /root/lks-debian-2025/ansible"
echo "   ansible-playbook validate-manual.yml"
echo ""
echo "4. Run validation on specific service:"
echo "   ansible-playbook validate-manual.yml --tags dns"
echo "   ansible-playbook validate-manual.yml --tags firewall"
echo "   ansible-playbook validate-manual.yml --tags database"
echo ""
echo "5. Manual testing tools:"
echo "   # DNS"
echo "   dig @192.168.1.10 lksn2025.id"
echo "   nslookup www.lksn2025.id 192.168.1.10"
echo ""
echo "   # LDAP"
echo "   ldapsearch -x -H ldap://192.168.1.10 -b 'dc=lksn2025,dc=id'"
echo ""
echo "   # Database"
echo "   mysql -h 192.168.1.10 -u root -p"
echo ""
echo "   # Web"
echo "   curl -I http://172.16.1.100"
echo "   curl -k https://172.16.1.100"
echo ""
echo "   # Mail"
echo "   telnet 172.16.1.10 25"
echo "   telnet 172.16.1.10 993"
echo ""
echo "   # Network scan"
echo "   nmap -sV 192.168.1.0/24"
echo "   nmap -sV 172.16.1.0/24"
echo ""
