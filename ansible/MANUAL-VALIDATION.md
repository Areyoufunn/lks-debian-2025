# Manual Configuration Validation Guide

Panduan untuk validate konfigurasi manual menggunakan Ansible.

## 🎯 Konsep

**Workflow:**
1. User konfigurasi service **MANUAL** (tanpa Ansible)
2. Run Ansible **validation playbook**
3. Ansible check konfigurasi dan **explain errors**
4. User fix errors berdasarkan penjelasan
5. Re-run validation sampai semua pass

## 🚀 Usage

### Validate All Services
```bash
cd /path/to/LKS/debian/ansible
ansible-playbook validate-manual.yml
```

### Validate Specific Service
```bash
# DNS only
ansible-playbook validate-manual.yml --tags dns

# Firewall only
ansible-playbook validate-manual.yml --tags firewall

# Database only
ansible-playbook validate-manual.yml --tags database

# Web cluster
ansible-playbook validate-manual.yml --tags web

# Mail server
ansible-playbook validate-manual.yml --tags mail
```

### Validate Specific Server
```bash
# Check int-srv only
ansible-playbook validate-manual.yml --limit int-srv

# Check firewall only
ansible-playbook validate-manual.yml --limit fw-srv

# Check web cluster
ansible-playbook validate-manual.yml --limit webcluster
```

## 📋 Validation Checks

### DNS (int-srv)
- ✓ Bind9 package installed
- ✓ Bind9 service running
- ✓ DNS listening on port 53
- ✓ Forward zone file exists
- ✓ Zone file syntax valid
- ✓ DNS resolution working

### Firewall (fw-srv)
- ✓ nftables installed
- ✓ nftables service running
- ✓ IP forwarding enabled
- ✓ NAT/Masquerade configured
- ✓ All 4 interfaces present
- ✓ Firewall rules loaded

### Database (int-srv)
- ✓ MariaDB installed
- ✓ MariaDB service running
- ✓ Remote access enabled (0.0.0.0)
- ✓ Database 'itnsa' exists
- ✓ Database 'roundcube' exists
- ✓ Database 'cacti' exists
- ✓ Users and permissions correct

### Mail (mail-srv)
- ✓ Postfix installed and running
- ✓ Dovecot installed and running
- ✓ SMTP port 25 listening
- ✓ IMAPS port 993 listening
- ✓ SSL certificates exist
- ✓ Roundcube configured
- ✓ Database connection correct

### Web Cluster (web-01, web-02)
- ✓ Keepalived installed and running
- ✓ HAProxy installed and running
- ✓ Nginx installed and running
- ✓ VIP configured
- ✓ SSL certificates exist

## 📊 Output Example

### ✓ PASS Example
```
TASK [✓ PASS: Bind9 Service Running]
ok: [int-srv] => {
    "msg": "✓ Bind9 service is active and running"
}
```

### ❌ ERROR Example
```
TASK [❌ ERROR: DNS Not Listening on Port 53]
ok: [int-srv] => {
    "msg": "
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ❌ ERROR: DNS tidak listening di port 53
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    MASALAH:
    Bind9 tidak listening pada port 53 (standard DNS port).
    
    PENJELASAN:
    Port 53 adalah standard port untuk DNS (UDP dan TCP).
    Jika Bind9 tidak listen di port ini, client tidak bisa
    melakukan DNS queries dan semua hostname resolution
    akan gagal.
    
    KEMUNGKINAN PENYEBAB:
    1. Bind9 configured untuk listen di IP tertentu saja
    2. Firewall blocking port 53
    3. Another service menggunakan port 53
    4. Bind9 failed to start karena config error
    
    CARA MEMPERBAIKI:
    1. Check what's using port 53:
       netstat -tulpn | grep :53
    
    2. Check bind9 listen configuration:
       grep 'listen-on' /etc/bind/named.conf.options
    
    3. Restart bind9:
       systemctl restart bind9
    
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    "
}
```

## 🔧 Typical Workflow

### 1. Manual Configuration
```bash
# User configures DNS manually
apt install bind9
nano /etc/bind/named.conf.local
nano /etc/bind/zones/db.lksn2025.id
systemctl restart bind9
```

### 2. Run Validation
```bash
ansible-playbook validate-manual.yml --tags dns
```

### 3. Fix Errors
```
❌ ERROR: Zone file has syntax errors
   → Missing dot at end of FQDN
   → Fix: Add dot after ns.lksn2025.id
```

### 4. Re-validate
```bash
ansible-playbook validate-manual.yml --tags dns
```

### 5. All Pass!
```
✓ Bind9 installed
✓ Service running
✓ Port 53 listening
✓ Zone file exists
✓ Syntax valid
✓ Resolution working
```

## 🎓 Educational Features

### Detailed Error Messages
Setiap error dijelaskan dengan:
- **MASALAH**: Apa yang salah
- **PENJELASAN**: Kenapa ini penting
- **KEMUNGKINAN PENYEBAB**: Apa yang mungkin menyebabkan error
- **CARA MEMPERBAIKI**: Step-by-step fix dengan commands

### Real Examples
Error messages include actual commands untuk fix:
```bash
# Not just "fix the config"
# But actual commands:
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
```

### Context Awareness
Validation understands the topology:
- Database di int-srv, bukan db-srv
- Remote access dari DMZ (172.16.1.0/24)
- VIP untuk web cluster (172.16.1.100)

## 📝 Adding New Validations

Create new validation file:
```yaml
# validation-tasks/validate-SERVICE.yml
---
- name: "🔍 CHECK: Something"
  command: check_command
  register: result
  failed_when: false
  changed_when: false

- name: "❌ ERROR: Explanation"
  debug:
    msg: |
      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      ❌ ERROR: Short description
      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      
      MASALAH:
      What's wrong
      
      PENJELASAN:
      Why it matters
      
      CARA MEMPERBAIKI:
      Step by step fix
      
      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  when: result.rc != 0
```

Add to validate-manual.yml:
```yaml
- name: "🔍 VALIDATE SERVICE"
  hosts: target_group
  tasks:
    - include_tasks: validation-tasks/validate-SERVICE.yml
  tags: [service]
```

## 🔗 Integration with Training

This validation system is perfect for:
- **Training environments**: Students configure manually, then validate
- **Competitions**: Check configurations without giving answers
- **Troubleshooting**: Identify issues quickly
- **Documentation**: Error messages serve as learning material
