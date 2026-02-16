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

# Define servers with MGMT IPs
declare -A SERVERS=(
    ["fw-srv"]="10.0.0.254"
    ["int-srv"]="10.0.0.10"
    ["mail-srv"]="10.0.0.20"
    ["web-01"]="10.0.0.21"
    ["web-02"]="10.0.0.22"
    ["db-srv"]="10.0.0.30"
    ["mon-srv"]="10.0.0.40"
    ["ani-clt"]="10.0.0.100"
)

echo -e "${CYAN}[1/3] Generating SSH Key...${NC}"
echo ""

# Check if SSH key already exists
if [ -f ~/.ssh/id_rsa ]; then
    echo -e "${YELLOW}⚠ SSH key already exists at ~/.ssh/id_rsa${NC}"
    echo "Using existing key..."
else
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "juri-srv@lksn2025"
    echo -e "${GREEN}✓ SSH key generated${NC}"
fi

echo ""
echo -e "${CYAN}[2/4] Installing required tools...${NC}"
echo ""

# Install sshpass
if ! command -v sshpass &> /dev/null; then
    echo "Installing sshpass..."
    apt update -qq
    apt install -y sshpass netcat-openbsd
    echo -e "${GREEN}✓ sshpass and netcat installed${NC}"
else
    echo -e "${GREEN}✓ sshpass already installed${NC}"
    # Ensure netcat is also installed
    if ! command -v nc &> /dev/null; then
        apt install -y netcat-openbsd
        echo -e "${GREEN}✓ netcat installed${NC}"
    fi
fi

echo ""
echo -e "${CYAN}[3/4] Displaying Public Key${NC}"
echo ""
echo -e "${YELLOW}Public Key:${NC}"
cat ~/.ssh/id_rsa.pub
echo ""

echo ""
echo -e "${CYAN}[4/4] Distributing SSH Key to Servers${NC}"
echo ""
echo -e "${YELLOW}Note: Connecting via MGMT network (10.0.0.x)${NC}"
echo -e "${YELLOW}      Password: 12345678${NC}"
echo ""

PASSWORD="12345678"

# Counter
count=0
SUCCESS=0
FAILED=0

echo "Starting distribution to 8 servers..."
echo ""

# Simple loop - exact same as debug version
for hostname in fw-srv int-srv mail-srv web-01 web-02 db-srv mon-srv ani-clt; do
    count=$((count + 1))
    ip="${SERVERS[$hostname]}"
    
    echo "[$count/8] Processing ${hostname} (${ip})..."
    
    # Just try to copy the key directly
    sshpass -p "${PASSWORD}" ssh-copy-id -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${ip}
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  SUCCESS: ${hostname}${NC}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "${RED}  FAILED: ${hostname}${NC}"
        FAILED=$((FAILED + 1))
    fi
    
    echo ""
    sleep 1
done

echo "Distribution complete!"
echo "Processed ${count} servers"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  📊 Distribution Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Total Servers: ${CYAN}8${NC}"
echo -e "Success:       ${GREEN}${SUCCESS}${NC}"
echo -e "Failed:        ${RED}${FAILED}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All SSH keys distributed successfully!${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Test SSH connection (via MGMT network):"
    echo "     ssh root@10.0.0.254  # fw-srv"
    echo "     ssh root@10.0.0.10   # int-srv"
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
