#!/bin/bash
#
# Remote Validation via Tailscale
# Run validation on remote server and display results
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ANSIBLE_DIR="$SCRIPT_DIR"

# Check if server IP provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Server IP/hostname required${NC}"
    echo ""
    echo "Usage: $0 <tailscale-ip> [service]"
    echo ""
    echo "Examples:"
    echo "  $0 100.64.0.1              # Validate all services"
    echo "  $0 100.64.0.1 dns          # Validate DNS only"
    echo "  $0 100.64.0.1 firewall     # Validate firewall only"
    echo ""
    echo "Available services:"
    echo "  - firewall"
    echo "  - dns"
    echo "  - ldap"
    echo "  - ca"
    echo "  - database"
    echo "  - mail"
    echo "  - web"
    exit 1
fi

SERVER_IP="$1"
SERVICE="${2:-all}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🔍 REMOTE VALIDATION VIA TAILSCALE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}Server:${NC} $SERVER_IP"
echo -e "${CYAN}Service:${NC} $SERVICE"
echo ""

# Check Tailscale connectivity
echo -e "${CYAN}[1/4]${NC} Checking Tailscale connectivity..."
if ! ping -c 1 -W 2 "$SERVER_IP" &>/dev/null; then
    echo -e "${RED}✗ Cannot reach server via Tailscale${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check Tailscale is running: tailscale status"
    echo "  2. Verify server IP: tailscale ip -4"
    echo "  3. Check server is online in Tailscale admin"
    exit 1
fi
echo -e "${GREEN}✓ Server reachable${NC}"
echo ""

# Check SSH access
echo -e "${CYAN}[2/4]${NC} Checking SSH access..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes root@"$SERVER_IP" "echo ok" &>/dev/null; then
    echo -e "${YELLOW}⚠ SSH key not configured${NC}"
    echo ""
    echo "Setting up SSH key..."
    ssh-copy-id root@"$SERVER_IP"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to setup SSH key${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ SSH access OK${NC}"
echo ""

# Copy validation files to server
echo -e "${CYAN}[3/4]${NC} Copying validation files..."
TEMP_DIR="/tmp/lks-validation-$$"

ssh root@"$SERVER_IP" "mkdir -p $TEMP_DIR"

# Copy validation playbook and tasks
scp -q "$ANSIBLE_DIR/validate-manual.yml" root@"$SERVER_IP":"$TEMP_DIR/"
scp -q -r "$ANSIBLE_DIR/validation-tasks" root@"$SERVER_IP":"$TEMP_DIR/"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to copy files${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Files copied${NC}"
echo ""

# Run validation
echo -e "${CYAN}[4/4]${NC} Running validation on server..."
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$SERVICE" = "all" ]; then
    ssh root@"$SERVER_IP" "cd $TEMP_DIR && ansible-playbook validate-manual.yml -c local -i localhost,"
else
    ssh root@"$SERVER_IP" "cd $TEMP_DIR && ansible-playbook validate-manual.yml -c local -i localhost, --tags $SERVICE"
fi

VALIDATION_RESULT=$?

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Cleanup
ssh root@"$SERVER_IP" "rm -rf $TEMP_DIR"

if [ $VALIDATION_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Validation completed successfully${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Validation completed with warnings/errors${NC}"
    echo "Review the output above for details"
    exit 1
fi
