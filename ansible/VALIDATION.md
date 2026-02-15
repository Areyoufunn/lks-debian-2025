# Configuration Validation Guide

Panduan untuk validate semua konfigurasi Ansible sebelum deployment.

## 🔍 Quick Check

```bash
cd /path/to/LKS/debian/ansible
chmod +x check-config.sh
./check-config.sh
```

## 📋 Validation Categories

### 1. Ansible Installation
- ✓ Ansible installed
- ✓ Ansible version >= 2.9
- ✓ Python3 available
- ✓ Required Python libraries

### 2. Directory Structure
- ✓ ansible.cfg exists
- ✓ inventory/hosts.ini exists
- ✓ site.yml exists
- ✓ roles/ directory exists

### 3. Syntax Validation
- ✓ ansible.cfg syntax
- ✓ Inventory file syntax
- ✓ YAML playbook syntax
- ✓ Jinja2 template syntax

### 4. Role Completeness
- ✓ All 12 roles exist
- ✓ Each role has tasks/main.yml
- ✓ Tasks have valid YAML syntax
- ✓ Templates are properly formatted

### 5. Variable Definitions
- ✓ Domain variable defined
- ✓ VIP variable for web cluster
- ✓ Network variables (IPs, gateways)
- ✓ Service-specific variables

### 6. Dependencies
- ✓ Python MySQL library
- ✓ Ansible collections
- ✓ System packages

### 7. Deployment Logic
- ✓ Correct deployment order
- ✓ Firewall first
- ✓ DNS early
- ✓ Dependencies respected

### 8. SSL/TLS Configuration
- ✓ CA role configured
- ✓ Certificate extensions defined
- ✓ SAN (Subject Alternative Names)
- ✓ Certificate validity periods

### 9. Database Configuration
- ✓ All databases created
- ✓ Users and permissions
- ✓ Remote access configured
- ✓ Services point to correct DB

### 10. Network Configuration
- ✓ IP addresses valid
- ✓ Network zones correct
- ✓ Firewall rules match topology
- ✓ DNS records complete

## 🐛 Common Errors & Solutions

### Error: "Ansible is not installed"
**Why:** Ansible diperlukan untuk menjalankan automation.
**Fix:**
```bash
apt update
apt install ansible -y
```

### Error: "ansible.cfg has syntax errors"
**Why:** Format INI tidak valid (missing brackets, typos).
**Fix:**
```bash
ansible-config dump
# Review error message and fix ansible.cfg
```

### Error: "Inventory has syntax errors"
**Why:** Format INI tidak benar atau duplicate hosts.
**Fix:**
```bash
ansible-inventory --list -i inventory/hosts.ini
# Check for duplicate hosts or invalid variable names
```

### Error: "site.yml has YAML syntax errors"
**Why:** Indentation salah atau missing colons.
**Fix:**
```bash
ansible-playbook site.yml --syntax-check
# Fix indentation (use 2 spaces, not tabs)
```

### Error: "Role directory not found"
**Why:** Role belum dibuat atau salah nama.
**Fix:**
```bash
mkdir -p roles/ROLENAME/{tasks,templates,handlers}
touch roles/ROLENAME/tasks/main.yml
```

### Error: "tasks/main.yml missing"
**Why:** Entry point untuk role tidak ada.
**Fix:**
```bash
cat > roles/ROLENAME/tasks/main.yml << 'EOF'
---
# ROLENAME tasks
- name: "Example task"
  debug:
    msg: "Hello from ROLENAME"
EOF
```

### Error: "Domain variable not defined"
**Why:** Variable 'domain' diperlukan untuk DNS dan certificates.
**Fix:**
```bash
# Add to inventory/hosts.ini under appropriate group
[internal:vars]
domain=lksn2025.id
```

### Error: "VIP variable not defined"
**Why:** Keepalived memerlukan VIP untuk failover.
**Fix:**
```bash
# Add to inventory/hosts.ini
[webcluster:vars]
vip=172.16.1.100
```

### Error: "Python MySQL library not found"
**Why:** mysql_user/mysql_db modules memerlukan PyMySQL.
**Fix:**
```bash
apt install python3-pymysql -y
```

### Error: "web_cert extension not found"
**Why:** Modern browsers require SAN in certificates.
**Fix:**
```bash
# Add to roles/ca/templates/openssl.cnf.j2
[ web_cert ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @web_alt_names

[ web_alt_names ]
DNS.1 = www.lksn2025.id
DNS.2 = lksn2025.id
IP.1 = 172.16.1.100
```

### Error: "Roundcube database not created"
**Why:** Roundcube memerlukan database untuk store data.
**Fix:**
```bash
# Add to roles/database/tasks/main.yml
- name: "Create Database 'roundcube'"
  mysql_db:
    name: roundcube
    state: present
    login_user: root
    login_password: Skills39!
```

### Error: "Roundcube still using SQLite"
**Why:** Harus connect ke centralized MySQL.
**Fix:**
```bash
# Update roles/mail/templates/roundcube-config.inc.php.j2
$config['db_dsnw'] = 'mysql://roundcube:Skills39!@192.168.1.10/roundcube';
```

## 🔧 Manual Validation Commands

### Check Ansible Syntax
```bash
# Check playbook syntax
ansible-playbook site.yml --syntax-check

# Check specific role
ansible-playbook -i localhost, --syntax-check <(echo '---
- hosts: localhost
  roles:
    - firewall')
```

### Check Inventory
```bash
# List all hosts
ansible-inventory --list

# List specific group
ansible-inventory --graph

# Show host variables
ansible-inventory --host fw-srv
```

### Check Variables
```bash
# Show all variables for a host
ansible -m debug -a "var=hostvars[inventory_hostname]" fw-srv

# Check specific variable
ansible -m debug -a "var=domain" internal
```

### Dry Run
```bash
# Check what would change (without making changes)
ansible-playbook site.yml --check

# Verbose output
ansible-playbook site.yml --check -v

# Very verbose (show all tasks)
ansible-playbook site.yml --check -vvv
```

## 📊 Validation Checklist

Before deployment, ensure:

- [ ] All checks in `check-config.sh` pass
- [ ] Ansible syntax validation passes
- [ ] All 12 roles exist and have tasks
- [ ] Templates have no syntax errors
- [ ] Variables are defined in inventory
- [ ] Database connections point to int-srv
- [ ] SSL certificates configured with SAN
- [ ] Deployment order is correct
- [ ] SSH keys distributed to all servers
- [ ] Network connectivity verified

## 🚀 Post-Validation

After all checks pass:

1. **Backup current configs** (if updating existing servers)
2. **Run dry-run**: `ansible-playbook site.yml --check`
3. **Deploy phase by phase**: `ansible-playbook site.yml --tags phase1`
4. **Verify each phase** before proceeding
5. **Run validation scripts** on target servers
6. **Test services** manually

## 📝 Continuous Validation

Run validation:
- Before every deployment
- After making configuration changes
- After updating Ansible version
- When troubleshooting issues

```bash
# Add to git pre-commit hook
#!/bin/bash
cd ansible/
./check-config.sh || exit 1
```
