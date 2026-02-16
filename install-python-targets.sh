#!/bin/bash
#
# Install Python on All Target Servers
# Run this on juri-srv to prepare servers for Ansible
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
echo -e "${BLUE}  Install Python on All Target Servers${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if running on juri-srv
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

echo -e "${CYAN}Installing Python on 8 target servers...${NC}"
echo ""

SUCCESS=0
FAILED=0
FAILED_SERVERS=()

# Install Python on each server
for hostname in fw-srv int-srv mail-srv web-01 web-02 db-srv mon-srv ani-clt; do
    ip="${SERVERS[$hostname]}"
    
    echo -e "${YELLOW}━━━ Installing Python on ${hostname} (${ip}) ━━━${NC}"
    
    # Test connectivity
    if ! ping -c 1 -W 2 ${ip} &>/dev/null; then
        echo -e "${RED}  ✗ Cannot reach ${hostname}${NC}"
        ((FAILED++))
        FAILED_SERVERS+=("${hostname}")
        echo ""
        continue
    fi
    
    # Install Python3
    echo "  Installing python3, python3-apt, python3-pip..."
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${ip} \
        "apt update -qq && DEBIAN_FRONTEND=noninteractive apt install -y python3 python3-apt python3-pip" &>/dev/null; then
        echo -e "${GREEN}  ✓ Python installed on ${hostname}${NC}"
        
        # Verify Python version
        PYTHON_VERSION=$(ssh root@${ip} "python3 --version" 2>&1)
        echo "    Version: ${PYTHON_VERSION}"
        
        ((SUCCESS++))
    else
        echo -e "${RED}  ✗ Failed to install Python on ${hostname}${NC}"
        ((FAILED++))
        FAILED_SERVERS+=("${hostname}")
    fi
    
    echo ""
done

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Installation Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Total Servers: ${CYAN}8${NC}"
echo -e "Success:       ${GREEN}${SUCCESS}${NC}"
echo -e "Failed:        ${RED}${FAILED}${NC}"
echo ""

if [ ${#FAILED_SERVERS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Failed servers:${NC}"
    for server in "${FAILED_SERVERS[@]}"; do
        echo "  - ${server} (${SERVERS[$server]})"
    done
    echo ""
fi

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Python installed on all servers!${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Test Ansible connectivity:"
    echo "     cd /root/lks-debian-2025/ansible"
    echo "     ansible all -m ping"
    echo ""
    echo "  2. Run automation:"
    echo "     ansible-playbook site.yml"
    echo ""
else
    echo -e "${YELLOW}⚠ Some installations failed${NC}"
    echo "Please check the output above and retry failed servers"
    echo ""
fi

echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
