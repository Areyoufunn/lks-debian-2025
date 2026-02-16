#!/bin/bash
#
# Simple SSH Key Distribution Script (Debug Version)
# Run this on juri-srv to distribute SSH keys to all servers
#

set -x  # Enable debug mode to see every command

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "Starting SSH key distribution..."

# Define servers with MGMT IPs
declare -A SERVERS=(
    ["fw-srv"]="10.0.0.254"
    ["int-srv"]="10.0.0.10"
    ["mail-srv"]="10.0.0.20"
    ["web-01"]="10.0.0.21"
    ["web-02"]="10.0.0.22"
    ["db-srv"]="10.0.0.30"
    ["mon-srv"]="10.0.0.40"
    ["ani-clt"]="10.0.0.100"
)

PASSWORD="12345678"

# Generate SSH key if not exists
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "juri-srv@lksn2025"
fi

# Install sshpass if not exists
if ! command -v sshpass &> /dev/null; then
    echo "Installing sshpass..."
    apt update -qq
    apt install -y sshpass
fi

echo ""
echo "Starting distribution to 8 servers..."
echo ""

# Simple loop - no fancy tests
count=0
for hostname in fw-srv int-srv mail-srv web-01 web-02 db-srv mon-srv ani-clt; do
    count=$((count + 1))
    ip="${SERVERS[$hostname]}"
    
    echo "[$count/8] Processing ${hostname} (${ip})..."
    
    # Just try to copy the key directly
    sshpass -p "${PASSWORD}" ssh-copy-id -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${ip}
    
    if [ $? -eq 0 ]; then
        echo "  SUCCESS: ${hostname}"
    else
        echo "  FAILED: ${hostname}"
    fi
    
    echo ""
    sleep 1
done

echo "Distribution complete!"
echo "Processed ${count} servers"
