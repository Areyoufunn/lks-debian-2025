#!/bin/bash
#
# Setup Ansible Control Node
# Run this on int-srv or any server that will manage other servers
#

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 LKS 2025 - Ansible Control Node Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root"
    exit 1
fi

echo "[1/5] Installing Ansible..."
apt update
apt install -y ansible python3-pip git

echo "[2/5] Installing Python dependencies..."
pip3 install pymysql

echo "[3/5] Generating SSH key..."
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    echo "✓ SSH key generated"
else
    echo "✓ SSH key already exists"
fi

echo "[4/5] Configuring Ansible..."
mkdir -p /etc/ansible
cat > /etc/ansible/ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
EOF

echo "[5/5] Setup complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Ansible Control Node Ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "1. Copy SSH key to managed nodes:"
echo "   ssh-copy-id root@<server-ip>"
echo ""
echo "2. Update inventory:"
echo "   nano ansible/inventory/hosts.ini"
echo ""
echo "3. Test connectivity:"
echo "   cd ansible"
echo "   ansible all -m ping"
echo ""
echo "4. Deploy services:"
echo "   ansible-playbook site.yml"
echo ""
