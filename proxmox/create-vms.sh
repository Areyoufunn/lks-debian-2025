#!/bin/bash
#
# Proxmox VM Creation Script - LKS 2025 Topology
# Clones VMs from template ID 100
#
# Bridge Mapping:
# - vmbr0 = WAN/Internet (from Proxmox host)
# - INT = INT Zone (192.168.1.0/24)
# - DMZ = DMZ Zone (172.16.1.0/24)
# - MGMT = MGMT Zone (10.0.0.0/24)
#
# VM IDs: 400-407
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEMPLATE_ID=100
STORAGE="local-lvm"
BRIDGE_WAN="vmbr0"
BRIDGE_INT="INT"
BRIDGE_DMZ="DMZ"
BRIDGE_MGMT="MGMT"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  LKS 2025 - Proxmox VM Cloning from Template${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if template exists
if ! qm status ${TEMPLATE_ID} &>/dev/null; then
    echo -e "${RED}ERROR: Template ${TEMPLATE_ID} does not exist!${NC}"
    echo "Please create a Debian template first with ID ${TEMPLATE_ID}"
    exit 1
fi

echo -e "${GREEN}✓ Template ${TEMPLATE_ID} found${NC}"
echo ""

# Function to clone VM and configure network
clone_vm() {
    local vmid=$1
    local name=$2
    shift 2
    local bridges=("$@")
    
    echo -e "${YELLOW}Cloning VM ${vmid}: ${name}${NC}"
    
    # Clone from template
    qm clone ${TEMPLATE_ID} ${vmid} --name ${name} --full
    
    # Remove all existing network interfaces
    for i in {0..9}; do
        qm set ${vmid} --delete net${i} 2>/dev/null || true
    done
    
    # Add network interfaces with correct bridges
    for i in "${!bridges[@]}"; do
        qm set ${vmid} --net${i} virtio,bridge=${bridges[$i]}
    done
    
    echo -e "${GREEN}✓ VM ${vmid} (${name}) cloned and configured${NC}"
    echo ""
}

# VM 400: fw-srv (Firewall/Gateway) - 4 interfaces
echo -e "${BLUE}[1/8] Cloning fw-srv (Firewall & Gateway)${NC}"
clone_vm 400 "fw-srv" ${BRIDGE_WAN} ${BRIDGE_INT} ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 401: int-srv (Internal Services) - 2 interfaces
echo -e "${BLUE}[2/8] Cloning int-srv (DNS, LDAP, CA, DHCP, FTP, Repo)${NC}"
clone_vm 401 "int-srv" ${BRIDGE_INT} ${BRIDGE_MGMT}

# VM 402: mail-srv (Mail Server) - 2 interfaces
echo -e "${BLUE}[3/8] Cloning mail-srv (Postfix, Dovecot, Roundcube)${NC}"
clone_vm 402 "mail-srv" ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 403: web-01 (Web Cluster Master) - 2 interfaces
echo -e "${BLUE}[4/8] Cloning web-01 (Web Cluster - MASTER)${NC}"
clone_vm 403 "web-01" ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 404: web-02 (Web Cluster Backup) - 2 interfaces
echo -e "${BLUE}[5/8] Cloning web-02 (Web Cluster - BACKUP)${NC}"
clone_vm 404 "web-02" ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 405: db-srv (Database Server) - 2 interfaces
echo -e "${BLUE}[6/8] Cloning db-srv (MariaDB, phpMyAdmin)${NC}"
clone_vm 405 "db-srv" ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 406: mon-srv (Monitoring Server) - 2 interfaces
echo -e "${BLUE}[7/8] Cloning mon-srv (Cacti, SNMP)${NC}"
clone_vm 406 "mon-srv" ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 407: ani-clt (Client) - 2 interfaces
echo -e "${BLUE}[8/8] Cloning ani-clt (Client)${NC}"
clone_vm 407 "ani-clt" ${BRIDGE_WAN} ${BRIDGE_MGMT}

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ All VMs cloned successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}VM Summary:${NC}"
echo "  400 - fw-srv    (4 NICs: vmbr0, INT, DMZ, MGMT)"
echo "  401 - int-srv   (2 NICs: INT, MGMT)"
echo "  402 - mail-srv  (2 NICs: DMZ, MGMT)"
echo "  403 - web-01    (2 NICs: DMZ, MGMT)"
echo "  404 - web-02    (2 NICs: DMZ, MGMT)"
echo "  405 - db-srv    (2 NICs: DMZ, MGMT)"
echo "  406 - mon-srv   (2 NICs: DMZ, MGMT)"
echo "  407 - ani-clt   (2 NICs: vmbr0, MGMT)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Start VMs: qm start <vmid>"
echo "  2. Configure static IPs according to topology"
echo "  3. Set unique hostnames"
echo "  4. Run Ansible automation"
echo ""
