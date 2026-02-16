#!/bin/bash
#
# Automated MGMT IP Configuration via qemu-guest-agent
# Run this script on Proxmox host AFTER VMs are created and running
#
# Prerequisites:
# - VMs must be running
# - qemu-guest-agent must be installed and running in VMs
# - openssh-server must be installed in VMs
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
echo -e "${BLUE}  Automated MGMT IP Configuration${NC}"
echo -e "${BLUE}  Using qemu-guest-agent${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# VM configurations: VMID:Hostname:MGMT_IP:Interface
declare -A VMS=(
    ["400"]="fw-srv:10.0.0.254:ens21"
    ["401"]="int-srv:10.0.0.10:ens19"
    ["402"]="mail-srv:10.0.0.20:ens19"
    ["403"]="web-01:10.0.0.21:ens19"
    ["404"]="web-02:10.0.0.22:ens19"
    ["405"]="db-srv:10.0.0.30:ens19"
    ["406"]="mon-srv:10.0.0.40:ens19"
    ["407"]="ani-clt:10.0.0.100:ens19"
    ["408"]="juri-srv:10.0.0.50:ens19"
)

# Function to check if qemu-guest-agent is running
check_agent() {
    local vmid=$1
    local hostname=$2
    
    echo -e "${CYAN}Checking qemu-guest-agent on ${hostname} (${vmid})...${NC}"
    
    if qm agent ${vmid} ping &>/dev/null; then
        echo -e "${GREEN}✓ Agent responding${NC}"
        return 0
    else
        echo -e "${RED}✗ Agent not responding${NC}"
        return 1
    fi
}

# Function to configure MGMT IP
configure_mgmt_ip() {
    local vmid=$1
    local hostname=$2
    local mgmt_ip=$3
    local iface=$4
    
    echo -e "${YELLOW}━━━ Configuring ${hostname} (${mgmt_ip}) ━━━${NC}"
    
    # Create network config using echo instead of heredoc
    echo "Creating network configuration..."
    qm guest exec ${vmid} -- /bin/bash -c "echo 'auto ${iface}' > /etc/network/interfaces.d/${iface}" &>/dev/null
    qm guest exec ${vmid} -- /bin/bash -c "echo 'iface ${iface} inet static' >> /etc/network/interfaces.d/${iface}" &>/dev/null
    qm guest exec ${vmid} -- /bin/bash -c "echo '    address ${mgmt_ip}' >> /etc/network/interfaces.d/${iface}" &>/dev/null
    qm guest exec ${vmid} -- /bin/bash -c "echo '    netmask 255.255.255.0' >> /etc/network/interfaces.d/${iface}" &>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Config file created${NC}"
    else
        echo -e "${RED}✗ Failed to create config${NC}"
        return 1
    fi
    
    # Apply IP immediately
    echo "Applying IP configuration..."
    qm guest exec ${vmid} -- /bin/bash -c "ip addr add ${mgmt_ip}/24 dev ${iface} 2>/dev/null || true" &>/dev/null
    qm guest exec ${vmid} -- /bin/bash -c "ip link set ${iface} up" &>/dev/null
    
    # Bring up interface persistently
    qm guest exec ${vmid} -- /bin/bash -c "ifup ${iface} 2>/dev/null || true" &>/dev/null
    
    # Verify
    echo "Verifying configuration..."
    sleep 1  # Give it a moment
    local result=$(qm guest exec ${vmid} -- /bin/bash -c "ip addr show ${iface} | grep '${mgmt_ip}'" 2>/dev/null)
    
    if [ -n "$result" ]; then
        echo -e "${GREEN}✓ ${hostname} configured successfully (${mgmt_ip})${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Configuration applied but verification unclear${NC}"
        echo -e "${YELLOW}  Trying to verify manually...${NC}"
        # Try ping test
        if ping -c 1 -W 2 ${mgmt_ip} &>/dev/null; then
            echo -e "${GREEN}✓ ${hostname} is reachable at ${mgmt_ip}${NC}"
            return 0
        else
            echo -e "${RED}✗ ${hostname} not reachable${NC}"
            return 1
        fi
    fi
}

# Function to ensure SSH is installed and running
ensure_ssh() {
    local vmid=$1
    local hostname=$2
    
    echo "Ensuring SSH is installed and running..."
    
    # Install openssh-server if not present
    qm guest exec ${vmid} -- /bin/bash -c "dpkg -l | grep -q openssh-server || apt update && apt install -y openssh-server" &>/dev/null
    
    # Enable and start SSH
    qm guest exec ${vmid} -- /bin/bash -c "systemctl enable ssh && systemctl start ssh" &>/dev/null
    
    # Configure SSH to allow root login
    qm guest exec ${vmid} -- /bin/bash -c "sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config" &>/dev/null
    qm guest exec ${vmid} -- /bin/bash -c "sed -i 's/PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config" &>/dev/null
    
    # Restart SSH
    qm guest exec ${vmid} -- /bin/bash -c "systemctl restart ssh" &>/dev/null
    
    echo -e "${GREEN}✓ SSH configured${NC}"
}

# Main execution
echo -e "${CYAN}Step 1: Checking qemu-guest-agent on all VMs...${NC}"
echo ""

FAILED_AGENTS=()
for vmid in "${!VMS[@]}"; do
    IFS=':' read -r hostname mgmt_ip iface <<< "${VMS[$vmid]}"
    
    if ! check_agent ${vmid} ${hostname}; then
        FAILED_AGENTS+=("${vmid}:${hostname}")
    fi
    echo ""
done

if [ ${#FAILED_AGENTS[@]} -gt 0 ]; then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}ERROR: qemu-guest-agent not responding on:${NC}"
    for item in "${FAILED_AGENTS[@]}"; do
        IFS=':' read -r vmid hostname <<< "$item"
        echo -e "${RED}  - ${hostname} (VMID ${vmid})${NC}"
    done
    echo ""
    echo -e "${YELLOW}Please ensure:${NC}"
    echo "  1. VMs are running"
    echo "  2. qemu-guest-agent is installed in template"
    echo "  3. qemu-guest-agent service is running"
    echo ""
    echo "To install in VM:"
    echo "  apt update && apt install -y qemu-guest-agent"
    echo "  systemctl enable qemu-guest-agent"
    echo "  systemctl start qemu-guest-agent"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ All agents responding!${NC}"
echo ""

# Configure MGMT IPs
echo -e "${CYAN}Step 2: Configuring MGMT IPs...${NC}"
echo ""

SUCCESS=0
FAILED=0

for vmid in {400..408}; do
    IFS=':' read -r hostname mgmt_ip iface <<< "${VMS[$vmid]}"
    
    if configure_mgmt_ip ${vmid} ${hostname} ${mgmt_ip} ${iface}; then
        ((SUCCESS++))
    else
        ((FAILED++))
    fi
    echo ""
done

# Configure SSH on all VMs
echo -e "${CYAN}Step 3: Configuring SSH on all VMs...${NC}"
echo ""

for vmid in {400..408}; do
    IFS=':' read -r hostname mgmt_ip iface <<< "${VMS[$vmid]}"
    echo -e "${YELLOW}Configuring SSH on ${hostname}...${NC}"
    ensure_ssh ${vmid} ${hostname}
    echo ""
done

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Configuration Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Total VMs:  ${CYAN}9${NC}"
echo -e "Success:    ${GREEN}${SUCCESS}${NC}"
echo -e "Failed:     ${RED}${FAILED}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All MGMT IPs configured successfully!${NC}"
    echo ""
    echo -e "${CYAN}MGMT IP Mapping:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  VMID  Hostname   MGMT IP        Interface"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for vmid in {400..408}; do
        IFS=':' read -r hostname mgmt_ip iface <<< "${VMS[$vmid]}"
        printf "  %-4s  %-10s %-14s %s\n" "$vmid" "$hostname" "$mgmt_ip" "$iface"
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Verify connectivity:"
    echo "     ping 10.0.0.50  # juri-srv"
    echo "     ping 10.0.0.10  # int-srv"
    echo ""
    echo "  2. SSH to juri-srv:"
    echo "     ssh root@10.0.0.50"
    echo "     Password: 12345678"
    echo ""
    echo "  3. Setup SSH keys:"
    echo "     cd /root/lks-debian-2025"
    echo "     ./setup-juri-ssh-keys.sh"
    echo ""
    echo "  4. Run Ansible:"
    echo "     cd ansible"
    echo "     ansible all -m ping"
    echo "     ansible-playbook site.yml"
    echo ""
else
    echo -e "${YELLOW}⚠ Some configurations failed${NC}"
    echo "Please check the output above for errors"
    echo ""
fi

echo -e "${GREEN}✓ Configuration complete!${NC}"
echo ""
