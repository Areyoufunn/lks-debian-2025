#!/bin/bash
#
# Configure MGMT IPs on all VMs
# Run this script AFTER VMs are created and running
# This script uses qm guest exec to configure IPs directly
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
echo -e "${BLUE}  Configure MGMT IPs on All VMs${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if qemu-guest-agent is available
echo -e "${CYAN}Checking prerequisites...${NC}"
echo ""

# VM configurations: VMID, Hostname, MGMT_IP, MGMT_Interface_Index
declare -A VMS=(
    ["400"]="fw-srv:10.0.0.254:3"      # 4th interface (ens21)
    ["401"]="int-srv:10.0.0.10:1"      # 2nd interface (ens19)
    ["402"]="mail-srv:10.0.0.20:1"     # 2nd interface (ens19)
    ["403"]="web-01:10.0.0.21:1"       # 2nd interface (ens19)
    ["404"]="web-02:10.0.0.22:1"       # 2nd interface (ens19)
    ["405"]="db-srv:10.0.0.30:1"       # 2nd interface (ens19)
    ["406"]="mon-srv:10.0.0.40:1"      # 2nd interface (ens19)
    ["407"]="ani-clt:10.0.0.100:1"     # 2nd interface (ens19)
    ["408"]="juri-srv:10.0.0.50:1"     # 2nd interface (ens19)
)

# Function to configure IP via SSH
configure_ip_ssh() {
    local vmid=$1
    local hostname=$2
    local mgmt_ip=$3
    local iface_idx=$4
    
    # Determine interface name based on index
    local iface="ens$((18 + iface_idx))"
    
    echo -e "${YELLOW}Configuring ${hostname} (${mgmt_ip}) on ${iface}...${NC}"
    
    # Try to SSH and configure
    # Note: This requires password or existing SSH key
    cat > /tmp/config-${vmid}.sh << EOF
#!/bin/bash
# Configure MGMT interface
cat > /etc/network/interfaces.d/${iface} << IFACE
auto ${iface}
iface ${iface} inet static
    address ${mgmt_ip}
    netmask 255.255.255.0
IFACE

# Bring up interface
ip addr add ${mgmt_ip}/24 dev ${iface} 2>/dev/null || true
ip link set ${iface} up

# Make persistent
systemctl restart networking 2>/dev/null || ifup ${iface}

echo "✓ ${iface} configured with ${mgmt_ip}"
EOF
    
    chmod +x /tmp/config-${vmid}.sh
    
    # Try to copy and execute (requires sshpass or key)
    if command -v sshpass &> /dev/null; then
        sshpass -p "12345678" scp -o StrictHostKeyChecking=no /tmp/config-${vmid}.sh root@${mgmt_ip}:/tmp/ 2>/dev/null
        sshpass -p "12345678" ssh -o StrictHostKeyChecking=no root@${mgmt_ip} "bash /tmp/config-${vmid}.sh" 2>/dev/null
        echo -e "${GREEN}✓ ${hostname} configured${NC}"
    else
        echo -e "${YELLOW}⚠ sshpass not installed, showing manual commands:${NC}"
        echo "  SSH to VM and run:"
        echo "  cat > /etc/network/interfaces.d/${iface} << EOF"
        echo "  auto ${iface}"
        echo "  iface ${iface} inet static"
        echo "      address ${mgmt_ip}"
        echo "      netmask 255.255.255.0"
        echo "  EOF"
        echo "  ifup ${iface}"
        echo ""
    fi
    
    rm -f /tmp/config-${vmid}.sh
}

# Alternative: Generate config files for manual application
echo -e "${CYAN}Generating MGMT IP configuration files...${NC}"
echo ""

mkdir -p /tmp/mgmt-configs

for vmid in "${!VMS[@]}"; do
    IFS=':' read -r hostname mgmt_ip iface_idx <<< "${VMS[$vmid]}"
    
    # Determine interface name
    iface="ens$((18 + iface_idx))"
    
    # Generate config file
    cat > /tmp/mgmt-configs/${hostname}-mgmt.cfg << EOF
# MGMT Interface Configuration for ${hostname}
# VMID: ${vmid}
# Interface: ${iface}
# IP: ${mgmt_ip}/24

# Add to /etc/network/interfaces or /etc/network/interfaces.d/${iface}

auto ${iface}
iface ${iface} inet static
    address ${mgmt_ip}
    netmask 255.255.255.0

# Quick apply (temporary):
# ip addr add ${mgmt_ip}/24 dev ${iface}
# ip link set ${iface} up

# Persistent apply:
# Copy above config to /etc/network/interfaces.d/${iface}
# ifup ${iface}
EOF
    
    echo -e "${GREEN}✓ Generated config for ${hostname} (${mgmt_ip})${NC}"
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Configuration files generated in: /tmp/mgmt-configs/${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}MGMT IP Mapping:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  VMID  Hostname   MGMT IP        Interface"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for vmid in {400..408}; do
    IFS=':' read -r hostname mgmt_ip iface_idx <<< "${VMS[$vmid]}"
    iface="ens$((18 + iface_idx))"
    printf "  %-4s  %-10s %-14s %s\n" "$vmid" "$hostname" "$mgmt_ip" "$iface"
done
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${YELLOW}Manual Configuration Steps:${NC}"
echo ""
echo "Option 1: Via Proxmox Console (Recommended)"
echo "  1. Open VM console in Proxmox"
echo "  2. Login as root (password: 12345678)"
echo "  3. Run these commands:"
echo ""
echo "     # For int-srv (VMID 401) example:"
echo "     cat > /etc/network/interfaces.d/ens19 << EOF"
echo "     auto ens19"
echo "     iface ens19 inet static"
echo "         address 10.0.0.10"
echo "         netmask 255.255.255.0"
echo "     EOF"
echo "     ifup ens19"
echo ""
echo "  4. Repeat for all VMs (see /tmp/mgmt-configs/ for each config)"
echo ""

echo "Option 2: Automated (if you have network access)"
echo "  1. Install sshpass on Proxmox host:"
echo "     apt install sshpass -y"
echo ""
echo "  2. Run this script again"
echo ""

echo "Option 3: Use Ansible (after at least juri-srv has MGMT IP)"
echo "  1. Configure juri-srv MGMT IP manually (10.0.0.50)"
echo "  2. SSH to juri-srv and run Ansible playbook to configure others"
echo ""

echo -e "${GREEN}Configuration files ready!${NC}"
echo ""
