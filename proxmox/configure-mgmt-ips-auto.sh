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

# Note: Not using 'set -e' to continue even if one VM fails

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
    
    echo -e "${YELLOW}━━━ Configuring ${hostname} (${mgmt_ip}) on ${iface} ━━━${NC}"
    
    # Create network config using echo instead of heredoc
    echo "Creating network configuration..."
    
    if ! qm guest exec ${vmid} -- /bin/bash -c "echo 'auto ${iface}' > /etc/network/interfaces.d/${iface}" 2>&1; then
        echo -e "${RED}✗ Failed to create config file${NC}"
        return 1
    fi
    
    qm guest exec ${vmid} -- /bin/bash -c "echo 'iface ${iface} inet static' >> /etc/network/interfaces.d/${iface}" 2>&1
    qm guest exec ${vmid} -- /bin/bash -c "echo '    address ${mgmt_ip}' >> /etc/network/interfaces.d/${iface}" 2>&1
    qm guest exec ${vmid} -- /bin/bash -c "echo '    netmask 255.255.255.0' >> /etc/network/interfaces.d/${iface}" 2>&1
    
    echo -e "${GREEN}✓ Config file created${NC}"
    
    # Apply IP immediately
    echo "Applying IP configuration..."
    qm guest exec ${vmid} -- /bin/bash -c "ip addr add ${mgmt_ip}/24 dev ${iface} 2>/dev/null || true" 2>&1
    qm guest exec ${vmid} -- /bin/bash -c "ip link set ${iface} up" 2>&1
    
    # Bring up interface persistently
    echo "Bringing up interface..."
    qm guest exec ${vmid} -- /bin/bash -c "ifup ${iface} 2>/dev/null || true" 2>&1
    
    # Verify
    echo "Verifying configuration..."
    sleep 2  # Give it more time
    
    # Try ping test first (more reliable)
    if ping -c 2 -W 3 ${mgmt_ip} &>/dev/null; then
        echo -e "${GREEN}✓ ${hostname} is reachable at ${mgmt_ip}${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ ${hostname} not reachable via ping, checking interface...${NC}"
        local result=$(qm guest exec ${vmid} -- /bin/bash -c "ip addr show ${iface} 2>/dev/null" 2>&1)
        echo "Interface status: $result"
        return 1
    fi
}

# Function to ensure SSH is installed and running
ensure_ssh() {
    local vmid=$1
    local hostname=$2
    
    echo "Installing and configuring SSH..."
    
    # Update package list and install openssh-server
    echo "  - Updating package list..."
    qm guest exec ${vmid} -- /bin/bash -c "apt update -qq" 2>&1 | grep -v "^$" || true
    
    echo "  - Installing openssh-server..."
    qm guest exec ${vmid} -- /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt install -y openssh-server" 2>&1 | grep -v "^$" || true
    
    # Enable and start SSH service
    echo "  - Enabling SSH service..."
    qm guest exec ${vmid} -- /bin/bash -c "systemctl enable ssh" 2>&1
    qm guest exec ${vmid} -- /bin/bash -c "systemctl start ssh" 2>&1
    
    # Configure SSH to allow root login with password
    echo "  - Configuring SSH for root login..."
    qm guest exec ${vmid} -- /bin/bash -c "sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config" 2>&1
    qm guest exec ${vmid} -- /bin/bash -c "sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config" 2>&1
    qm guest exec ${vmid} -- /bin/bash -c "sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" 2>&1
    qm guest exec ${vmid} -- /bin/bash -c "sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" 2>&1
    
    # Restart SSH to apply changes
    echo "  - Restarting SSH service..."
    qm guest exec ${vmid} -- /bin/bash -c "systemctl restart ssh" 2>&1
    
    # Verify SSH is running
    local ssh_status=$(qm guest exec ${vmid} -- /bin/bash -c "systemctl is-active ssh" 2>/dev/null)
    if [[ "$ssh_status" == *"active"* ]]; then
        echo -e "${GREEN}  ✓ SSH installed and running${NC}"
        return 0
    else
        echo -e "${YELLOW}  ⚠ SSH status unclear${NC}"
        return 0
    fi
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
    echo "  2. SSH to juri-srv (SSH already configured!):"
    echo "     ssh root@10.0.0.50"
    echo "     Password: 12345678"
    echo ""
    echo "  3. Setup SSH keys from juri-srv:"
    echo "     cd /root"
    echo "     git clone https://github.com/Areyoufunn/lks-debian-2025.git"
    echo "     cd lks-debian-2025"
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
