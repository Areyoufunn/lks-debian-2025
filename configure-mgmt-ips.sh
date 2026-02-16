#!/bin/bash
#
# Configure MGMT IPs from juri-srv
# Run this script on juri-srv AFTER:
# 1. VMs are created and running
# 2. Production IPs are configured (WAN, INT, DMZ)
# 3. juri-srv has network access to all servers
#
# This script will:
# - Generate SSH key on juri-srv
# - SSH to each server via production IP
# - Configure MGMT IP on each server
# - Copy SSH key to each server
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
echo -e "${BLUE}  Configure MGMT IPs from juri-srv${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root${NC}"
    exit 1
fi

# Server configurations: Hostname:Production_IP:MGMT_IP:MGMT_Interface
declare -A SERVERS=(
    ["fw-srv"]="192.168.27.200:10.0.0.254:ens21"
    ["int-srv"]="192.168.1.10:10.0.0.10:ens19"
    ["mail-srv"]="172.16.1.10:10.0.0.20:ens19"
    ["web-01"]="172.16.1.21:10.0.0.21:ens19"
    ["web-02"]="172.16.1.22:10.0.0.22:ens19"
    ["db-srv"]="172.16.1.30:10.0.0.30:ens19"
    ["mon-srv"]="172.16.1.40:10.0.0.40:ens19"
    ["ani-clt"]="192.168.27.100:10.0.0.100:ens19"
)

PASSWORD="12345678"

echo -e "${CYAN}[1/4] Generating SSH Key...${NC}"
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
echo -e "${CYAN}[2/4] Installing sshpass (for automated SSH)...${NC}"
echo ""

if ! command -v sshpass &> /dev/null; then
    echo "Installing sshpass..."
    apt update -qq
    apt install -y sshpass
    echo -e "${GREEN}✓ sshpass installed${NC}"
else
    echo -e "${GREEN}✓ sshpass already installed${NC}"
fi

echo ""
echo -e "${CYAN}[3/4] Configuring MGMT IPs on all servers...${NC}"
echo ""
echo -e "${YELLOW}Note: Using password: ${PASSWORD}${NC}"
echo ""

SUCCESS=0
FAILED=0
FAILED_SERVERS=()

for hostname in "${!SERVERS[@]}"; do
    IFS=':' read -r prod_ip mgmt_ip iface <<< "${SERVERS[$hostname]}"
    
    echo -e "${YELLOW}━━━ Configuring ${hostname} (${mgmt_ip}) ━━━${NC}"
    echo "  Production IP: ${prod_ip}"
    echo "  MGMT IP: ${mgmt_ip}"
    echo "  Interface: ${iface}"
    echo ""
    
    # Test connectivity
    echo "  Testing connectivity to ${prod_ip}..."
    if ! ping -c 1 -W 2 ${prod_ip} &>/dev/null; then
        echo -e "${RED}  ✗ Cannot reach ${hostname} at ${prod_ip}${NC}"
        echo -e "${YELLOW}    Please ensure production IP is configured${NC}"
        ((FAILED++))
        FAILED_SERVERS+=("${hostname}")
        echo ""
        continue
    fi
    echo -e "${GREEN}  ✓ ${hostname} is reachable${NC}"
    
    # Create MGMT IP configuration
    echo "  Creating MGMT IP configuration..."
    sshpass -p "${PASSWORD}" ssh -o StrictHostKeyChecking=no root@${prod_ip} \
        "cat > /etc/network/interfaces.d/${iface} << EOF
auto ${iface}
iface ${iface} inet static
    address ${mgmt_ip}
    netmask 255.255.255.0
EOF" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ Config file created${NC}"
    else
        echo -e "${RED}  ✗ Failed to create config${NC}"
        ((FAILED++))
        FAILED_SERVERS+=("${hostname}")
        echo ""
        continue
    fi
    
    # Apply IP configuration
    echo "  Applying IP configuration..."
    sshpass -p "${PASSWORD}" ssh -o StrictHostKeyChecking=no root@${prod_ip} \
        "ip addr add ${mgmt_ip}/24 dev ${iface} 2>/dev/null || true; ip link set ${iface} up; ifup ${iface} 2>/dev/null || true" 2>/dev/null
    
    # Verify
    echo "  Verifying MGMT IP..."
    sleep 2
    if ping -c 2 -W 3 ${mgmt_ip} &>/dev/null; then
        echo -e "${GREEN}  ✓ ${hostname} MGMT IP configured and reachable${NC}"
        ((SUCCESS++))
    else
        echo -e "${YELLOW}  ⚠ MGMT IP configured but not yet reachable${NC}"
        ((SUCCESS++))
    fi
    
    echo ""
done

echo -e "${CYAN}[4/4] Distributing SSH Keys...${NC}"
echo ""

SSH_SUCCESS=0
SSH_FAILED=0

for hostname in "${!SERVERS[@]}"; do
    IFS=':' read -r prod_ip mgmt_ip iface <<< "${SERVERS[$hostname]}"
    
    echo -e "${BLUE}━━━ Copying SSH key to ${hostname} ━━━${NC}"
    
    # Try MGMT IP first, fallback to production IP
    if sshpass -p "${PASSWORD}" ssh-copy-id -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${mgmt_ip} 2>/dev/null; then
        echo -e "${GREEN}✓ SSH key copied to ${hostname} via MGMT IP${NC}"
        ((SSH_SUCCESS++))
    elif sshpass -p "${PASSWORD}" ssh-copy-id -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${prod_ip} 2>/dev/null; then
        echo -e "${GREEN}✓ SSH key copied to ${hostname} via production IP${NC}"
        ((SSH_SUCCESS++))
    else
        echo -e "${RED}✗ Failed to copy SSH key to ${hostname}${NC}"
        ((SSH_FAILED++))
    fi
    echo ""
done

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Configuration Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}MGMT IP Configuration:${NC}"
echo -e "  Total Servers: ${CYAN}${#SERVERS[@]}${NC}"
echo -e "  Success:       ${GREEN}${SUCCESS}${NC}"
echo -e "  Failed:        ${RED}${FAILED}${NC}"
echo ""
echo -e "${CYAN}SSH Key Distribution:${NC}"
echo -e "  Success:       ${GREEN}${SSH_SUCCESS}${NC}"
echo -e "  Failed:        ${RED}${SSH_FAILED}${NC}"
echo ""

if [ ${#FAILED_SERVERS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Failed servers:${NC}"
    for server in "${FAILED_SERVERS[@]}"; do
        echo "  - ${server}"
    done
    echo ""
fi

if [ $FAILED -eq 0 ] && [ $SSH_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All configurations successful!${NC}"
    echo ""
    echo -e "${CYAN}MGMT IP Mapping:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Hostname   Production IP     MGMT IP        Interface"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for hostname in fw-srv int-srv mail-srv web-01 web-02 db-srv mon-srv ani-clt; do
        if [ -n "${SERVERS[$hostname]}" ]; then
            IFS=':' read -r prod_ip mgmt_ip iface <<< "${SERVERS[$hostname]}"
            printf "  %-10s %-17s %-14s %s\n" "$hostname" "$prod_ip" "$mgmt_ip" "$iface"
        fi
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Test SSH connectivity:"
    echo "     ssh root@10.0.0.10  # int-srv (no password!)"
    echo "     ssh root@10.0.0.20  # mail-srv"
    echo ""
    echo "  2. Run Ansible:"
    echo "     cd /root/lks-debian-2025/ansible"
    echo "     ansible all -m ping"
    echo "     ansible-playbook site.yml"
    echo ""
else
    echo -e "${YELLOW}⚠ Some configurations failed${NC}"
    echo "Please check the output above for details"
    echo ""
    echo "You can retry manually:"
    echo "  ssh root@<production-ip>"
    echo "  # Configure MGMT IP manually"
    echo ""
fi

echo -e "${GREEN}✓ Configuration complete!${NC}"
echo ""
