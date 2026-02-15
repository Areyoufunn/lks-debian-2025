#!/bin/bash
#
# LKS 2025 - Service Validation Script
# Educational validation with auto-correction
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
FIXED_CHECKS=0

# Auto-fix mode
AUTO_FIX=false
if [ "$1" == "--fix" ]; then
    AUTO_FIX=true
fi

# Function to print section header
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Function to check and explain
check_service() {
    local service_name=$1
    local check_command=$2
    local error_message=$3
    local explanation=$4
    local fix_command=$5
    
    ((TOTAL_CHECKS++))
    
    echo -e "${CYAN}[CHECK $TOTAL_CHECKS]${NC} Checking: $service_name"
    
    if eval "$check_command" &>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED_CHECKS++))
        echo ""
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED_CHECKS++))
        echo ""
        echo -e "${YELLOW}━━━ ERROR EXPLANATION ━━━${NC}"
        echo -e "${RED}Problem:${NC} $error_message"
        echo ""
        echo -e "${CYAN}Why this matters:${NC}"
        echo "$explanation"
        echo ""
        
        if [ -n "$fix_command" ]; then
            echo -e "${GREEN}How to fix:${NC}"
            echo "  $fix_command"
            echo ""
            
            if [ "$AUTO_FIX" = true ]; then
                read -p "$(echo -e ${YELLOW}Auto-fix this issue? [y/N]:${NC} )" -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${CYAN}Applying fix...${NC}"
                    if eval "$fix_command"; then
                        echo -e "${GREEN}✓ Fixed successfully!${NC}"
                        ((FIXED_CHECKS++))
                        ((FAILED_CHECKS--))
                        ((PASSED_CHECKS++))
                    else
                        echo -e "${RED}✗ Fix failed. Please fix manually.${NC}"
                    fi
                fi
            fi
        fi
        echo ""
        return 1
    fi
}

# ============================================================
# DNS SERVICE VALIDATION
# ============================================================
validate_dns() {
    print_header "🌐 DNS SERVER VALIDATION (int-srv)"
    
    check_service \
        "Bind9 Service Running" \
        "systemctl is-active --quiet bind9" \
        "Bind9 service is not running" \
        "DNS server harus running untuk resolve domain names. Tanpa DNS, services tidak bisa berkomunikasi menggunakan hostname." \
        "systemctl start bind9 && systemctl enable bind9"
    
    check_service \
        "DNS Listening on Port 53" \
        "netstat -tuln | grep -q ':53'" \
        "DNS not listening on port 53" \
        "Port 53 adalah standard port untuk DNS. Jika tidak listen, client tidak bisa query DNS." \
        "systemctl restart bind9"
    
    check_service \
        "Forward Zone File Exists" \
        "[ -f /etc/bind/zones/db.lksn2025.id ]" \
        "Forward zone file missing" \
        "Forward zone file berisi mapping dari hostname ke IP address. Tanpa ini, DNS tidak bisa resolve domain lksn2025.id." \
        "cp /path/to/template/db.lksn2025.id /etc/bind/zones/ && systemctl reload bind9"
    
    check_service \
        "DNS Configuration Syntax" \
        "named-checkconf" \
        "DNS configuration has syntax errors" \
        "Syntax error di named.conf akan prevent Bind9 dari starting. Harus fix sebelum service bisa jalan." \
        "named-checkconf -p"
    
    check_service \
        "Zone File Syntax" \
        "named-checkzone lksn2025.id /etc/bind/zones/db.lksn2025.id" \
        "Zone file has syntax errors" \
        "Zone file syntax error akan cause DNS queries to fail. Serial number, SOA record, dan format harus benar." \
        "Check zone file format and increment serial number"
}

# ============================================================
# FIREWALL SERVICE VALIDATION
# ============================================================
validate_firewall() {
    print_header "🔥 FIREWALL VALIDATION (fw-srv)"
    
    check_service \
        "nftables Service Running" \
        "systemctl is-active --quiet nftables" \
        "nftables service is not running" \
        "Firewall harus running untuk protect network. Tanpa firewall, semua traffic allowed dan network vulnerable." \
        "systemctl start nftables && systemctl enable nftables"
    
    check_service \
        "IP Forwarding Enabled" \
        "[ \$(sysctl -n net.ipv4.ip_forward) -eq 1 ]" \
        "IP forwarding is disabled" \
        "IP forwarding diperlukan agar fw-srv bisa route traffic antar network (WAN, INT, DMZ). Tanpa ini, inter-network communication tidak akan work." \
        "sysctl -w net.ipv4.ip_forward=1 && echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf"
    
    check_service \
        "NAT Rules Configured" \
        "nft list table ip nat | grep -q masquerade" \
        "NAT/Masquerade rules not found" \
        "NAT masquerade diperlukan untuk translate internal IPs ke public IP. Tanpa ini, internal hosts tidak bisa access internet." \
        "nft add rule ip nat postrouting oifname ens18 masquerade"
    
    check_service \
        "Firewall Rules Loaded" \
        "nft list ruleset | grep -q 'chain input'" \
        "No firewall rules loaded" \
        "Firewall rules define apa yang allowed/blocked. Tanpa rules, default policy akan apply (biasanya drop all)." \
        "nft -f /etc/nftables.conf"
}

# ============================================================
# MAIL SERVICE VALIDATION
# ============================================================
validate_mail() {
    print_header "📧 MAIL SERVER VALIDATION (mail-srv)"
    
    check_service \
        "Postfix Service Running" \
        "systemctl is-active --quiet postfix" \
        "Postfix (SMTP) is not running" \
        "Postfix adalah SMTP server untuk send/receive email. Tanpa ini, email tidak bisa dikirim atau diterima." \
        "systemctl start postfix && systemctl enable postfix"
    
    check_service \
        "Dovecot Service Running" \
        "systemctl is-active --quiet dovecot" \
        "Dovecot (IMAP) is not running" \
        "Dovecot adalah IMAP server untuk retrieve email. Tanpa ini, users tidak bisa read email via email client." \
        "systemctl start dovecot && systemctl enable dovecot"
    
    check_service \
        "SMTP Port 25 Listening" \
        "netstat -tuln | grep -q ':25'" \
        "SMTP not listening on port 25" \
        "Port 25 adalah standard SMTP port. Jika tidak listen, email dari external servers tidak bisa masuk." \
        "systemctl restart postfix"
    
    check_service \
        "IMAP Port 993 Listening" \
        "netstat -tuln | grep -q ':993'" \
        "IMAPS not listening on port 993" \
        "Port 993 adalah secure IMAP port (SSL/TLS). Email clients connect ke port ini untuk retrieve email securely." \
        "systemctl restart dovecot"
    
    check_service \
        "SSL Certificate Exists" \
        "[ -f /etc/ssl/lksn-ca/certs/mail-srv.crt ]" \
        "Mail SSL certificate not found" \
        "SSL certificate diperlukan untuk encrypt email traffic (SMTPS, IMAPS). Tanpa ini, email dikirim plain text (insecure)." \
        "Generate certificate using CA role"
}

# ============================================================
# WEB CLUSTER VALIDATION
# ============================================================
validate_web() {
    print_header "🌍 WEB CLUSTER VALIDATION (web-01, web-02)"
    
    check_service \
        "Keepalived Service Running" \
        "systemctl is-active --quiet keepalived" \
        "Keepalived is not running" \
        "Keepalived manage VIP failover. Tanpa ini, jika MASTER down, VIP tidak akan failover ke BACKUP." \
        "systemctl start keepalived && systemctl enable keepalived"
    
    check_service \
        "HAProxy Service Running" \
        "systemctl is-active --quiet haproxy" \
        "HAProxy is not running" \
        "HAProxy adalah load balancer. Tanpa ini, traffic tidak akan distributed ke backend web servers." \
        "systemctl start haproxy && systemctl enable haproxy"
    
    check_service \
        "Nginx Service Running" \
        "systemctl is-active --quiet nginx" \
        "Nginx is not running" \
        "Nginx adalah web server yang serve actual content. Tanpa ini, web pages tidak bisa displayed." \
        "systemctl start nginx && systemctl enable nginx"
    
    check_service \
        "VIP Configured" \
        "ip addr show | grep -q '172.16.1.100'" \
        "VIP 172.16.1.100 not configured" \
        "VIP (Virtual IP) adalah shared IP antara web-01 dan web-02. Ini memungkinkan high availability - jika satu server down, yang lain take over." \
        "Check keepalived configuration"
}

# ============================================================
# DATABASE VALIDATION
# ============================================================
validate_database() {
    print_header "💾 DATABASE VALIDATION (db-srv)"
    
    check_service \
        "MariaDB Service Running" \
        "systemctl is-active --quiet mariadb" \
        "MariaDB is not running" \
        "MariaDB adalah database server. Tanpa ini, applications tidak bisa store/retrieve data." \
        "systemctl start mariadb && systemctl enable mariadb"
    
    check_service \
        "Database 'itnsa' Exists" \
        "mysql -e 'SHOW DATABASES' | grep -q itnsa" \
        "Database 'itnsa' not found" \
        "Database 'itnsa' diperlukan untuk store application data. Harus created sebelum application bisa use it." \
        "mysql -e 'CREATE DATABASE itnsa'"
    
    check_service \
        "Remote Access Enabled" \
        "grep -q 'bind-address.*0.0.0.0' /etc/mysql/mariadb.conf.d/50-server.cnf" \
        "MariaDB not configured for remote access" \
        "Remote access diperlukan agar applications dari servers lain bisa connect ke database. Default bind-address adalah 127.0.0.1 (localhost only)." \
        "sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf && systemctl restart mariadb"
}

# ============================================================
# MAIN EXECUTION
# ============================================================
echo ""
print_header "🔍 LKS 2025 - SERVICE VALIDATION"

if [ "$AUTO_FIX" = true ]; then
    echo -e "${GREEN}Auto-fix mode enabled${NC}"
    echo ""
fi

# Detect current server and run appropriate checks
HOSTNAME=$(hostname)

case $HOSTNAME in
    int-srv*)
        validate_dns
        ;;
    fw-srv*)
        validate_firewall
        ;;
    mail-srv*)
        validate_mail
        ;;
    web-*)
        validate_web
        ;;
    db-srv*)
        validate_database
        ;;
    *)
        echo -e "${YELLOW}Running all validations...${NC}"
        echo ""
        validate_dns
        validate_firewall
        validate_mail
        validate_web
        validate_database
        ;;
esac

# Summary
print_header "📊 VALIDATION SUMMARY"
echo -e "Total Checks:  ${CYAN}$TOTAL_CHECKS${NC}"
echo -e "Passed:        ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed:        ${RED}$FAILED_CHECKS${NC}"
if [ "$AUTO_FIX" = true ]; then
    echo -e "Auto-Fixed:    ${YELLOW}$FIXED_CHECKS${NC}"
fi
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! System is healthy.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review and fix.${NC}"
    if [ "$AUTO_FIX" = false ]; then
        echo -e "${YELLOW}Tip: Run with --fix flag to enable auto-correction${NC}"
    fi
    exit 1
fi
