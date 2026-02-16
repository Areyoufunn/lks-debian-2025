#!/bin/bash
#
# SSH Key Distribution Script for Juri Server
# Generates SSH key and distributes to all servers
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🔑 SSH Key Distribution for Juri Server${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root${NC}"
    exit 1
fi

# Define servers
declare -A SERVERS=(
    ["fw-srv"]="192.168.27.200"
    ["int-srv"]="192.168.1.10"
    ["mail-srv"]="172.16.1.10"
    ["web-01"]="172.16.1.21"
    ["web-02"]="172.16.1.22"
    ["db-srv"]="172.16.1.30"
    ["mon-srv"]="172.16.1.40"
    ["ani-clt"]="192.168.27.100"
)

echo -e "${CYAN}[1/3] Generating SSH Key...${NC}"
echo ""

# Check if SSH key already exists
if [ -f ~/.ssh/id_rsa ]; then
    echo -e "${YELLOW}⚠ SSH key already exists at ~/.ssh/id_rsa${NC}"
    read -p "Do you want to overwrite it? (yes/no): " overwrite
    if [ "$overwrite" != "yes" ]; then
        echo "Using existing key..."
    else
        echo "Generating new key..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "juri-srv@lksn2025"
        echo -e "${GREEN}✓ New SSH key generated${NC}"
    fi
else
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "juri-srv@lksn2025"
    echo -e "${GREEN}✓ SSH key generated${NC}"
fi

echo ""
echo -e "${CYAN}[2/3] Displaying Public Key${NC}"
echo ""
echo -e "${YELLOW}Public Key:${NC}"
cat ~/.ssh/id_rsa.pub
echo ""

echo -e "${CYAN}[3/3] Distributing SSH Key to Servers${NC}"
echo ""
echo -e "${YELLOW}Note: You will be prompted for password for each server${NC}"
echo -e "${YELLOW}      Default password: 12345678${NC}"
echo ""

# Counter
SUCCESS=0
FAILED=0

# Distribute to each server
for hostname in "${!SERVERS[@]}"; do
    ip="${SERVERS[$hostname]}"
    echo -e "${BLUE}━━━ Copying key to ${hostname} (${ip}) ━━━${NC}"
    
    # Try to copy SSH key
    if ssh-copy-id -o ConnectTimeout=5 root@${ip} 2>/dev/null; then
        echo -e "${GREEN}✓ Key copied to ${hostname}${NC}"
        ((SUCCESS++))
    else
        echo -e "${RED}✗ Failed to copy key to ${hostname}${NC}"
        echo -e "${YELLOW}  Possible reasons:${NC}"
        echo "    - Server not reachable (check IP: ${ip})"
        echo "    - SSH service not running"
        echo "    - Wrong password"
        echo "    - Firewall blocking connection"
        ((FAILED++))
    fi
    echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  📊 Distribution Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Total Servers: ${CYAN}${#SERVERS[@]}${NC}"
echo -e "Success:       ${GREEN}${SUCCESS}${NC}"
echo -e "Failed:        ${RED}${FAILED}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All SSH keys distributed successfully!${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Test SSH connection:"
    echo "     ssh root@fw-srv"
    echo "     ssh root@int-srv"
    echo ""
    echo "  2. Run Ansible validation:"
    echo "     cd /root/lks-debian-2025/ansible"
    echo "     ansible all -m ping"
    echo "     ansible-playbook validate-manual.yml"
else
    echo -e "${YELLOW}⚠ Some servers failed. Please check:${NC}"
    echo "  1. Server IPs are correct"
    echo "  2. Servers are running and accessible"
    echo "  3. SSH service is running on servers"
    echo "  4. Network connectivity (ping test)"
    echo ""
    echo "  You can retry failed servers manually:"
    echo "  ssh-copy-id root@<server-ip>"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
