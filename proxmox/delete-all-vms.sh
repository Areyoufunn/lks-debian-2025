#!/bin/bash
#
# Delete all LKS VMs from Proxmox
# Use with caution!
#

# Define colors
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

echo "WARNING: This will DELETE all VMs (400-408)"
echo -e "${YELLOW}This will DELETE the following VMs:${NC}"
echo "  400 - fw-srv"
echo "  401 - int-srv"
echo "  402 - mail-srv"
echo "  403 - web-01"
echo "  404 - web-02"
echo "  405 - db-srv"
echo "  406 - mon-srv"
echo "  407 - ani-clt"
echo "  408 - juri-srv"
echo ""
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Deleting VMs...${NC}"
echo ""

# Delete VMs 400-408
for vmid in {400..408}; do
    if qm status $vmid &>/dev/null; then
        echo "Stopping VM $vmid..."
        qm stop $vmid 2>/dev/null || true
        sleep 2
        echo "Deleting VM $vmid..."
        qm destroy $vmid --purge
        echo "✓ VM $vmid deleted"
    else
        echo "⊘ VM $vmid does not exist"
    fi
done

echo ""
echo "✓ Cleanup complete!"
