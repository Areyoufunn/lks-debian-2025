#!/bin/bash
#
# Reset Root Password on All Servers
# Run this from Proxmox host to reset password to 12345678
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
echo -e "${BLUE}  Reset Root Password on All VMs${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if running on Proxmox
if ! command -v qm &> /dev/null; then
    echo -e "${RED}❌ This script must run on Proxmox host${NC}"
    exit 1
fi

NEW_PASSWORD="12345678"

# VM IDs and names
declare -A VMS=(
    [400]="fw-srv"
    [401]="int-srv"
    [402]="mail-srv"
    [403]="web-01"
    [404]="web-02"
    [405]="db-srv"
    [406]="mon-srv"
    [407]="juri-srv"
    [408]="ani-clt"
)

echo -e "${CYAN}Resetting password to: ${YELLOW}${NEW_PASSWORD}${NC}"
echo ""

count=0
SUCCESS=0
FAILED=0

for vmid in 400 401 402 403 404 405 406 407 408; do
    count=$((count + 1))
    hostname="${VMS[$vmid]}"
    
    echo "[$count/9] Resetting password for ${hostname} (VM ${vmid})..."
    
    # Check if VM exists
    if ! qm status ${vmid} &>/dev/null; then
        echo -e "${RED}  FAILED: VM ${vmid} not found${NC}"
        FAILED=$((FAILED + 1))
        echo ""
        continue
    fi
    
    # Reset password using qm guest exec
    if qm guest exec ${vmid} -- /bin/bash -c "echo 'root:${NEW_PASSWORD}' | chpasswd" &>/dev/null; then
        echo -e "${GREEN}  SUCCESS: ${hostname}${NC}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "${RED}  FAILED: ${hostname}${NC}"
        FAILED=$((FAILED + 1))
    fi
    
    echo ""
done

echo "Password reset complete!"
echo "Processed ${count} VMs"
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Total VMs:  ${CYAN}9${NC}"
echo -e "Success:    ${GREEN}${SUCCESS}${NC}"
echo -e "Failed:     ${RED}${FAILED}${NC}"
echo ""
echo -e "New Password: ${YELLOW}${NEW_PASSWORD}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All passwords reset successfully!${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. SSH to juri-srv:"
    echo "     ssh root@10.0.0.50"
    echo "     Password: ${NEW_PASSWORD}"
    echo ""
    echo "  2. Re-run SSH key distribution:"
    echo "     cd /root/lks-debian-2025"
    echo "     ./setup-juri-ssh-keys.sh"
    echo ""
else
    echo -e "${YELLOW}⚠ Some password resets failed${NC}"
    echo "Please check the output above"
fi

echo ""
