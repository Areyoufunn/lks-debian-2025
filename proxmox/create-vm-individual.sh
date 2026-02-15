#!/bin/bash
#
# Individual VM Cloning from Template
# Template ID: 100
#

# Configuration
TEMPLATE_ID=100
BRIDGE_WAN="vmbr0"
BRIDGE_INT="INT"
BRIDGE_DMZ="DMZ"
BRIDGE_MGMT="MGMT"

# Check template exists
check_template() {
    if ! qm status ${TEMPLATE_ID} &>/dev/null; then
        echo "ERROR: Template ${TEMPLATE_ID} does not exist!"
        exit 1
    fi
}

# Function to clone and configure VM
clone_and_configure() {
    local vmid=$1
    local name=$2
    shift 2
    local bridges=("$@")
    
    echo "Cloning VM ${vmid} from template ${TEMPLATE_ID}..."
    qm clone ${TEMPLATE_ID} ${vmid} --name ${name} --full
    
    # Remove existing network interfaces
    for i in {0..9}; do
        qm set ${vmid} --delete net${i} 2>/dev/null || true
    done
    
    # Configure network bridges
    for i in "${!bridges[@]}"; do
        qm set ${vmid} --net${i} virtio,bridge=${bridges[$i]}
        echo "  - net${i} → ${bridges[$i]}"
    done
    
    echo "✓ VM ${vmid} (${name}) cloned successfully"
}

# ============================================================
# VM 400: fw-srv (Firewall & Gateway)
# ============================================================
create_fw_srv() {
    check_template
    echo "Creating fw-srv (VMID 400)..."
    clone_and_configure 400 "fw-srv" ${BRIDGE_WAN} ${BRIDGE_INT} ${BRIDGE_DMZ} ${BRIDGE_MGMT}
    echo "  IP Configuration:"
    echo "    ens18 → vmbr0 (WAN: 192.168.27.200)"
    echo "    ens19 → INT (INT: 192.168.1.254)"
    echo "    ens20 → DMZ (DMZ: 172.16.1.254)"
    echo "    ens21 → MGMT (MGMT: 10.0.0.11)"
}

# ============================================================
# VM 401: int-srv (Internal Services)
# ============================================================
create_int_srv() {
    check_template
    echo "Creating int-srv (VMID 401)..."
    clone_and_configure 401 "int-srv" ${BRIDGE_INT} ${BRIDGE_MGMT}
    echo "  IP Configuration:"
    echo "    ens18 → INT (INT: 192.168.1.10)"
    echo "    ens19 → MGMT (MGMT: 10.0.0.10)"
}

# ============================================================
# VM 402: mail-srv (Mail Server)
# ============================================================
create_mail_srv() {
    check_template
    echo "Creating mail-srv (VMID 402)..."
    clone_and_configure 402 "mail-srv" ${BRIDGE_DMZ} ${BRIDGE_MGMT}
    echo "  IP Configuration:"
    echo "    ens18 → DMZ (DMZ: 172.16.1.10)"
    echo "    ens19 → MGMT (MGMT: 10.0.0.12)"
}

# ============================================================
# VM 403: web-01 (Web Cluster Master)
# ============================================================
create_web_01() {
    check_template
    echo "Creating web-01 (VMID 403)..."
    clone_and_configure 403 "web-01" ${BRIDGE_DMZ} ${BRIDGE_MGMT}
    echo "  IP Configuration:"
    echo "    ens18 → DMZ (DMZ: 172.16.1.21)"
    echo "    ens19 → MGMT (MGMT: 10.0.0.13)"
}

# ============================================================
# VM 404: web-02 (Web Cluster Backup)
# ============================================================
create_web_02() {
    check_template
    echo "Creating web-02 (VMID 404)..."
    clone_and_configure 404 "web-02" ${BRIDGE_DMZ} ${BRIDGE_MGMT}
    echo "  IP Configuration:"
    echo "    ens18 → DMZ (DMZ: 172.16.1.22)"
    echo "    ens19 → MGMT (MGMT: 10.0.0.14)"
}

# ============================================================
# VM 405: db-srv (Database Server)
# ============================================================
create_db_srv() {
    check_template
    echo "Creating db-srv (VMID 405)..."
    clone_and_configure 405 "db-srv" ${BRIDGE_DMZ} ${BRIDGE_MGMT}
    echo "  IP Configuration:"
    echo "    ens18 → DMZ (DMZ: 172.16.1.17)"
    echo "    ens19 → MGMT (MGMT: 10.0.0.16)"
}

# ============================================================
# VM 406: mon-srv (Monitoring Server)
# ============================================================
create_mon_srv() {
    check_template
    echo "Creating mon-srv (VMID 406)..."
    clone_and_configure 406 "mon-srv" ${BRIDGE_DMZ} ${BRIDGE_MGMT}
    echo "  IP Configuration:"
    echo "    ens18 → DMZ (DMZ: 172.16.1.15)"
    echo "    ens19 → MGMT (MGMT: 10.0.0.17)"
}

# ============================================================
# VM 407: ani-clt (Client)
# ============================================================
create_ani_clt() {
    check_template
    echo "Creating ani-clt (VMID 407)..."
    clone_and_configure 407 "ani-clt" ${BRIDGE_WAN} ${BRIDGE_MGMT}
    echo "  IP Configuration:"
    echo "    ens18 → vmbr0 (WAN: 192.168.27.100)"
    echo "    ens19 → MGMT (MGMT: 10.0.0.15)"
}

# ============================================================
# Main Menu
# ============================================================
echo "LKS 2025 - Individual VM Cloning from Template ${TEMPLATE_ID}"
echo "=========================================================="
echo ""
echo "Select VM to clone:"
echo "  1) fw-srv    (400)"
echo "  2) int-srv   (401)"
echo "  3) mail-srv  (402)"
echo "  4) web-01    (403)"
echo "  5) web-02    (404)"
echo "  6) db-srv    (405)"
echo "  7) mon-srv   (406)"
echo "  8) ani-clt   (407)"
echo "  9) Clone ALL"
echo "  0) Exit"
echo ""
read -p "Enter choice: " choice

case $choice in
    1) create_fw_srv ;;
    2) create_int_srv ;;
    3) create_mail_srv ;;
    4) create_web_01 ;;
    5) create_web_02 ;;
    6) create_db_srv ;;
    7) create_mon_srv ;;
    8) create_ani_clt ;;
    9) 
        check_template
        create_fw_srv
        create_int_srv
        create_mail_srv
        create_web_01
        create_web_02
        create_db_srv
        create_mon_srv
        create_ani_clt
        ;;
    0) echo "Exiting..."; exit 0 ;;
    *) echo "Invalid choice"; exit 1 ;;
esac
