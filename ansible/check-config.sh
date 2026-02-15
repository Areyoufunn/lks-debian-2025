#!/bin/bash
#
# Ansible Configuration Checker
# Validates all configurations and explains errors
#

set +e  # Don't exit on errors, we want to report them

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED=0
FAILED=0
WARNINGS=0

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🔍 ANSIBLE CONFIGURATION CHECKER${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Function to print section
print_section() {
    echo ""
    echo -e "${MAGENTA}━━━ $1 ━━━${NC}"
    echo ""
}

# Function to check
check() {
    local name="$1"
    local command="$2"
    local error_msg="$3"
    local explanation="$4"
    local fix="$5"
    
    ((TOTAL_CHECKS++))
    echo -ne "${CYAN}[$TOTAL_CHECKS]${NC} Checking: $name ... "
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
        echo ""
        echo -e "${RED}  Error:${NC} $error_msg"
        echo -e "${YELLOW}  Why:${NC} $explanation"
        if [ -n "$fix" ]; then
            echo -e "${GREEN}  Fix:${NC} $fix"
        fi
        echo ""
        return 1
    fi
}

# Function to warn
warn() {
    local name="$1"
    local message="$2"
    
    ((TOTAL_CHECKS++))
    ((WARNINGS++))
    echo -e "${YELLOW}[!]${NC} Warning: $name"
    echo -e "${YELLOW}    $message${NC}"
    echo ""
}

# ============================================================
# CHECK 1: ANSIBLE INSTALLATION
# ============================================================
print_section "1. ANSIBLE INSTALLATION"

check \
    "Ansible installed" \
    "command -v ansible-playbook" \
    "Ansible is not installed" \
    "Ansible diperlukan untuk menjalankan automation. Tanpa Ansible, semua playbook tidak akan bisa dijalankan." \
    "apt install ansible -y"

check \
    "Ansible version >= 2.9" \
    "ansible --version | head -n1 | grep -qE '(2\.(9|[0-9]{2})|[3-9]\.)'" \
    "Ansible version too old" \
    "Beberapa module dan feature memerlukan Ansible 2.9+. Version lama mungkin tidak support syntax atau module yang digunakan." \
    "apt update && apt install ansible -y"

# ============================================================
# CHECK 2: DIRECTORY STRUCTURE
# ============================================================
print_section "2. DIRECTORY STRUCTURE"

cd "$SCRIPT_DIR" || exit 1

check \
    "ansible.cfg exists" \
    "[ -f ansible.cfg ]" \
    "ansible.cfg not found" \
    "File ini berisi konfigurasi Ansible seperti inventory path, logging, dan privilege escalation. Tanpa file ini, Ansible akan use default settings yang mungkin tidak sesuai." \
    "Create ansible.cfg with proper configuration"

check \
    "inventory/hosts.ini exists" \
    "[ -f inventory/hosts.ini ]" \
    "Inventory file not found" \
    "Inventory file mendefinisikan semua hosts dan variables. Tanpa inventory, Ansible tidak tahu server mana yang harus di-configure." \
    "Create inventory/hosts.ini with all hosts"

check \
    "site.yml exists" \
    "[ -f site.yml ]" \
    "Master playbook not found" \
    "site.yml adalah master playbook yang orchestrate semua deployment. Tanpa file ini, tidak ada entry point untuk menjalankan automation." \
    "Create site.yml master playbook"

check \
    "roles directory exists" \
    "[ -d roles ]" \
    "Roles directory not found" \
    "Roles directory berisi semua service configurations. Tanpa directory ini, tidak ada tasks yang bisa dijalankan." \
    "mkdir -p roles"

# ============================================================
# CHECK 3: ANSIBLE SYNTAX
# ============================================================
print_section "3. ANSIBLE SYNTAX VALIDATION"

check \
    "ansible.cfg syntax" \
    "ansible-config dump &>/dev/null" \
    "ansible.cfg has syntax errors" \
    "Syntax error di ansible.cfg akan prevent Ansible dari loading configuration. Periksa format INI dan pastikan tidak ada typo." \
    "ansible-config dump untuk lihat error detail"

check \
    "Inventory syntax" \
    "ansible-inventory --list &>/dev/null" \
    "Inventory has syntax errors" \
    "Inventory file harus follow format INI yang benar. Error bisa dari: missing brackets, invalid variable names, atau duplicate host definitions." \
    "ansible-inventory --list -i inventory/hosts.ini untuk debug"

check \
    "site.yml syntax" \
    "ansible-playbook site.yml --syntax-check" \
    "site.yml has YAML syntax errors" \
    "YAML syntax sangat strict tentang indentation. Error biasanya dari: wrong indentation, missing colons, atau invalid characters." \
    "ansible-playbook site.yml --syntax-check untuk detail error"

# ============================================================
# CHECK 4: ROLE STRUCTURE
# ============================================================
print_section "4. ROLE STRUCTURE VALIDATION"

REQUIRED_ROLES=(
    "firewall"
    "dns"
    "ca"
    "ldap"
    "mail"
    "webcluster"
    "database"
    "monitoring"
    "dhcp"
    "ftp"
    "repository"
    "ssh-hardening"
)

for role in "${REQUIRED_ROLES[@]}"; do
    check \
        "Role: $role exists" \
        "[ -d roles/$role ]" \
        "Role directory 'roles/$role' not found" \
        "Role $role diperlukan untuk configure service tersebut. Tanpa role ini, service tidak akan ter-install atau ter-configure." \
        "Create role structure: mkdir -p roles/$role/{tasks,templates,handlers}"
    
    if [ -d "roles/$role" ]; then
        check \
            "Role: $role/tasks/main.yml" \
            "[ -f roles/$role/tasks/main.yml ]" \
            "tasks/main.yml missing in $role" \
            "main.yml adalah entry point untuk role. Tanpa file ini, Ansible tidak tahu tasks apa yang harus dijalankan." \
            "Create roles/$role/tasks/main.yml"
        
        if [ -f "roles/$role/tasks/main.yml" ]; then
            check \
                "Role: $role tasks syntax" \
                "ansible-playbook -i localhost, --syntax-check <(echo '---
- hosts: localhost
  roles:
    - $role')" \
                "Syntax error in $role tasks" \
                "YAML syntax error di tasks file. Periksa indentation, list format (-), dan variable syntax ({{ }})." \
                "Check roles/$role/tasks/main.yml for YAML errors"
        fi
    fi
done

# ============================================================
# CHECK 5: TEMPLATE VALIDATION
# ============================================================
print_section "5. TEMPLATE FILES VALIDATION"

# Check for common template issues
TEMPLATE_COUNT=$(find roles -name "*.j2" 2>/dev/null | wc -l)
echo -e "${CYAN}Found $TEMPLATE_COUNT Jinja2 templates${NC}"
echo ""

# Check each template for basic syntax
while IFS= read -r template; do
    # Check for unclosed Jinja2 tags
    if grep -qE '\{\{[^}]*$|\{%[^%]*$' "$template"; then
        warn \
            "Template: $(basename $template)" \
            "Possible unclosed Jinja2 tag detected. Check for {{ or {% without closing }}"
    fi
    
    # Check for undefined variables (common ones)
    if grep -qE '\{\{\s*[a-z_]+\s*\}\}' "$template"; then
        # This is just a warning, not an error
        : # Templates are expected to have variables
    fi
done < <(find roles -name "*.j2" 2>/dev/null)

# ============================================================
# CHECK 6: VARIABLE DEFINITIONS
# ============================================================
print_section "6. VARIABLE DEFINITIONS"

# Check if critical variables are defined in inventory
check \
    "Variable: domain defined" \
    "grep -q 'domain=' inventory/hosts.ini" \
    "Domain variable not defined in inventory" \
    "Variable 'domain' diperlukan untuk DNS, certificates, dan banyak service lain. Tanpa ini, banyak template akan error." \
    "Add 'domain=lksn2025.id' to inventory group vars"

check \
    "Variable: vip defined for webcluster" \
    "grep -q 'vip=' inventory/hosts.ini" \
    "VIP variable not defined for web cluster" \
    "VIP (Virtual IP) diperlukan untuk Keepalived high availability. Tanpa ini, web cluster tidak akan bisa failover." \
    "Add 'vip=172.16.1.100' to webcluster group vars"

# ============================================================
# CHECK 7: DEPENDENCIES
# ============================================================
print_section "7. PYTHON DEPENDENCIES"

check \
    "Python3 installed" \
    "command -v python3" \
    "Python3 not found" \
    "Ansible requires Python3 on control node. Banyak module juga memerlukan Python libraries." \
    "apt install python3 -y"

check \
    "Python MySQL library" \
    "python3 -c 'import pymysql' 2>/dev/null || python3 -c 'import MySQLdb' 2>/dev/null" \
    "Python MySQL library not found" \
    "mysql_user dan mysql_db modules memerlukan PyMySQL atau MySQLdb. Tanpa ini, database tasks akan fail." \
    "apt install python3-pymysql -y"

# ============================================================
# CHECK 8: PLAYBOOK LOGIC
# ============================================================
print_section "8. PLAYBOOK LOGIC VALIDATION"

# Check for proper host targeting
if grep -q "hosts: database" site.yml; then
    warn \
        "Deprecated 'database' host group" \
        "Database has been moved to int-srv. Update site.yml to use 'hosts: internal' for database role."
fi

# Check deployment order
check \
    "Firewall deployed first" \
    "grep -B5 'firewall' site.yml | head -n1 | grep -q 'PHASE 1'" \
    "Firewall not in Phase 1" \
    "Firewall harus di-deploy pertama untuk setup network routing. Jika tidak, inter-network communication akan fail." \
    "Move firewall to Phase 1 in site.yml"

check \
    "DNS deployed before other services" \
    "grep -B5 'dns' site.yml | head -n1 | grep -qE 'PHASE [1-3]'" \
    "DNS deployed too late" \
    "DNS harus di-deploy early karena services lain depend on DNS resolution. Jika DNS belum ready, hostname resolution akan fail." \
    "Move DNS to early phase (2-3)"

# ============================================================
# CHECK 9: CERTIFICATE CONFIGURATION
# ============================================================
print_section "9. SSL/TLS CERTIFICATE VALIDATION"

if [ -f "roles/ca/templates/openssl.cnf.j2" ]; then
    check \
        "OpenSSL config has web_cert extension" \
        "grep -q '\[web_cert\]' roles/ca/templates/openssl.cnf.j2" \
        "web_cert extension not found in OpenSSL config" \
        "web_cert extension dengan SAN (Subject Alternative Names) diperlukan untuk modern browsers. Tanpa ini, browsers akan reject certificate." \
        "Add [web_cert] section with subjectAltName to openssl.cnf.j2"
    
    check \
        "OpenSSL config has SAN for web" \
        "grep -q 'subjectAltName' roles/ca/templates/openssl.cnf.j2" \
        "Subject Alternative Names not configured" \
        "SAN diperlukan untuk support multiple domains/IPs in single certificate. Modern browsers require SAN even for single domain." \
        "Add subjectAltName = @web_alt_names to web_cert section"
fi

# ============================================================
# CHECK 10: DATABASE CONFIGURATION
# ============================================================
print_section "10. DATABASE CONFIGURATION"

if [ -f "roles/database/tasks/main.yml" ]; then
    check \
        "Database creates roundcube DB" \
        "grep -q \"name: roundcube\" roles/database/tasks/main.yml" \
        "Roundcube database not created" \
        "Roundcube webmail memerlukan database 'roundcube'. Tanpa database ini, Roundcube tidak bisa store emails dan settings." \
        "Add mysql_db task to create 'roundcube' database"
    
    check \
        "Database creates cacti DB" \
        "grep -q \"name: cacti\" roles/database/tasks/main.yml" \
        "Cacti database not created" \
        "Cacti monitoring memerlukan database 'cacti' untuk store metrics dan graphs. Tanpa ini, Cacti tidak bisa function." \
        "Add mysql_db task to create 'cacti' database"
fi

if [ -f "roles/mail/templates/roundcube-config.inc.php.j2" ]; then
    check \
        "Roundcube uses MySQL (not SQLite)" \
        "grep -q 'mysql://' roles/mail/templates/roundcube-config.inc.php.j2" \
        "Roundcube still using SQLite" \
        "Roundcube harus connect ke centralized MySQL di int-srv. SQLite adalah local database yang tidak bisa di-share." \
        "Change db_dsnw to mysql://roundcube:password@192.168.1.10/roundcube"
    
    check \
        "Roundcube points to int-srv" \
        "grep -q '192.168.1.10' roles/mail/templates/roundcube-config.inc.php.j2" \
        "Roundcube not pointing to int-srv database" \
        "Database sekarang di int-srv (192.168.1.10), bukan localhost. Connection harus point ke IP yang benar." \
        "Update database host to 192.168.1.10 in roundcube config"
fi

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  📊 VALIDATION SUMMARY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Total Checks:  ${CYAN}$TOTAL_CHECKS${NC}"
echo -e "Passed:        ${GREEN}$PASSED${NC}"
echo -e "Failed:        ${RED}$FAILED${NC}"
echo -e "Warnings:      ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo -e "${GREEN}Configuration is ready for deployment.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed!${NC}"
    echo -e "${YELLOW}Please fix the errors above before deploying.${NC}"
    echo ""
    echo -e "${CYAN}Quick fixes:${NC}"
    echo "  1. Review error messages above"
    echo "  2. Fix syntax errors in YAML files"
    echo "  3. Ensure all required roles exist"
    echo "  4. Verify variable definitions"
    echo "  5. Re-run this script to verify fixes"
    exit 1
fi
