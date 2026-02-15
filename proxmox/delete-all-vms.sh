#!/bin/bash
#
# Delete all LKS VMs from Proxmox
# Use with caution!
#

echo "WARNING: This will DELETE all VMs (400-407)"
echo "VMs to be deleted:"
echo "  400 - fw-srv"
echo "  401 - int-srv"
echo "  402 - mail-srv"
echo "  403 - web-01"
echo "  404 - web-02"
echo "  405 - db-srv"
echo "  406 - mon-srv"
echo "  407 - ani-clt"
echo ""
read -p "Are you sure? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo "Stopping and deleting VMs..."

for vmid in {400..407}; do
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
