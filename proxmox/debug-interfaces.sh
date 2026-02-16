#!/bin/bash
#
# Debug script to check interface names on all VMs
#

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Checking interface names on all VMs...${NC}"
echo ""

for vmid in {400..408}; do
    echo -e "${YELLOW}VMID ${vmid}:${NC}"
    
    # Check if agent responding
    if qm agent ${vmid} ping &>/dev/null; then
        # Get interface list
        interfaces=$(qm guest exec ${vmid} -- /bin/bash -c "ip -o link show | awk -F': ' '{print \$2}'" 2>/dev/null)
        echo "$interfaces"
    else
        echo "  Agent not responding"
    fi
    echo ""
done
