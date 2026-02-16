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
# VM IDs: 400-408
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

# Function to clone VM and configure network with cloud-init
clone_vm() {
    local vmid=$1
    local name=$2
    local mgmt_ip=$3
    shift 3
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
    
    # Configure cloud-init for MGMT network and SSH
    qm set ${vmid} --ide2 ${STORAGE}:cloudinit
    qm set ${vmid} --ciuser root
    qm set ${vmid} --cipassword 12345678
    
    # Set MGMT IP on last interface
    local last_idx=$((${#bridges[@]} - 1))
    qm set ${vmid} --ipconfig${last_idx} "ip=${mgmt_ip}/24"
    
    echo -e "${GREEN}✓ VM ${vmid} (${name}) cloned with MGMT IP ${mgmt_ip}${NC}"
    echo ""
}

# VM 400: fw-srv (Firewall/Gateway) - 4 interfaces
echo -e "${BLUE}[1/9] Cloning fw-srv (Firewall & Gateway)${NC}"
clone_vm 400 "fw-srv" "10.0.0.254" ${BRIDGE_WAN} ${BRIDGE_INT} ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 401: int-srv (Internal Services) - 2 interfaces
echo -e "${BLUE}[2/9] Cloning int-srv (DNS, LDAP, CA, DHCP, FTP, Repo)${NC}"
clone_vm 401 "int-srv" "10.0.0.10" ${BRIDGE_INT} ${BRIDGE_MGMT}

# VM 402: mail-srv (Mail Server) - 2 interfaces
echo -e "${BLUE}[3/9] Cloning mail-srv (Postfix, Dovecot, Roundcube)${NC}"
clone_vm 402 "mail-srv" "10.0.0.20" ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 403: web-01 (Web Cluster Master) - 2 interfaces
echo -e "${BLUE}[4/9] Cloning web-01 (Web Cluster - MASTER)${NC}"
clone_vm 403 "web-01" "10.0.0.21" ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 404: web-02 (Web Cluster Backup) - 2 interfaces
echo -e "${BLUE}[5/9] Cloning web-02 (Web Cluster - BACKUP)${NC}"
clone_vm 404 "web-02" "10.0.0.22" ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 405: db-srv (Database Server) - 2 interfaces
echo -e "${BLUE}[6/9] Cloning db-srv (MariaDB, phpMyAdmin)${NC}"
clone_vm 405 "db-srv" "10.0.0.30" ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 406: mon-srv (Monitoring Server) - 2 interfaces
echo -e "${BLUE}[7/9] Cloning mon-srv (Cacti, SNMP)${NC}"
clone_vm 406 "mon-srv" "10.0.0.40" ${BRIDGE_DMZ} ${BRIDGE_MGMT}

# VM 407: ani-clt (Client) - 2 interfaces
echo -e "${BLUE}[8/9] Cloning ani-clt (Client)${NC}"
clone_vm 407 "ani-clt" "10.0.0.100" ${BRIDGE_WAN} ${BRIDGE_MGMT}

# VM 408: juri-srv (Validator/Checker Server) - 2 interfaces
echo -e "${BLUE}[9/9] Cloning juri-srv (Configuration Validator)${NC}"
clone_vm 408 "juri-srv" "10.0.0.50" ${BRIDGE_WAN} ${BRIDGE_MGMT}

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ All VMs cloned successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}VM Summary with MGMT IPs:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  VMID  Hostname   MGMT IP        Interfaces"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  400   fw-srv     10.0.0.254     vmbr0, INT, DMZ, MGMT"
echo "  401   int-srv    10.0.0.10      INT, MGMT"
echo "  402   mail-srv   10.0.0.20      DMZ, MGMT"
echo "  403   web-01     10.0.0.21      DMZ, MGMT"
echo "  404   web-02     10.0.0.22      DMZ, MGMT"
echo "  405   db-srv     10.0.0.30      DMZ, MGMT"
echo "  406   mon-srv    10.0.0.40      DMZ, MGMT"
echo "  407   ani-clt    10.0.0.100     vmbr0, MGMT"
echo "  408   juri-srv   10.0.0.50      vmbr0, MGMT (Validator)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}Credentials (Cloud-init):${NC}"
echo "  Username: root"
echo "  Password: 12345678"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Start all VMs:"
echo "     for i in {400..408}; do qm start \$i; done"
echo ""
echo "  2. Wait for cloud-init (~2 minutes)"
echo ""
echo "  3. Configure production IPs manually (WAN, INT, DMZ)"
echo "     MGMT IPs already configured automatically!"
echo ""
echo "  4. Setup SSH keys from juri-srv:"
echo "     ssh root@10.0.0.50  # Password: 12345678"
echo "     cd /root/lks-debian-2025"
echo "     ./setup-juri-ssh-keys.sh"
echo ""
echo "  5. Run Ansible automation:"
echo "     cd ansible"
echo "     ansible all -m ping"
echo "     ansible-playbook site.yml"
echo ""
echo -e "${GREEN}✓ VMs ready! MGMT network configured for Ansible.${NC}"
echo ""
