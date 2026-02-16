# Complete Automation & Validation Guide

## Quick Start

Dari **juri-srv**, jalankan automation dan validation:

```bash
cd /root/lks-debian-2025/ansible

# 1. Test connectivity
ansible all -m ping

# 2. Run full automation
ansible-playbook site.yml

# 3. Run validation
ansible-playbook validate-manual.yml
```

---

## Detailed Steps

### 1. Test Ansible Connectivity

```bash
cd /root/lks-debian-2025/ansible

# Ping all servers via MGMT network
ansible all -m ping

# Expected output:
# fw-srv | SUCCESS => { "ping": "pong" }
# int-srv | SUCCESS => { "ping": "pong" }
# mail-srv | SUCCESS => { "ping": "pong" }
# web-01 | SUCCESS => { "ping": "pong" }
# web-02 | SUCCESS => { "ping": "pong" }
# mon-srv | SUCCESS => { "ping": "pong" }
# ani-clt | SUCCESS => { "ping": "pong" }
```

**Jika ada yang FAILED:**
- Check MGMT IP configured: `ssh root@10.0.0.x`
- Check SSH key: `ssh root@10.0.0.x` (should not ask password)
- Check inventory: `cat inventory/hosts.ini`

---

### 2. Run Complete Automation

```bash
# Run all roles on all servers
ansible-playbook site.yml

# Or run specific roles:
ansible-playbook site.yml --tags firewall
ansible-playbook site.yml --tags dns
ansible-playbook site.yml --tags mail
ansible-playbook site.yml --tags web
```

**Execution time:** ~15-30 minutes (tergantung server specs)

**What it does:**
- ✅ Configure firewall (nftables, NAT, routing)
- ✅ Setup DNS server (BIND9)
- ✅ Setup LDAP server (OpenLDAP)
- ✅ Setup CA (Certificate Authority)
- ✅ Setup DHCP server
- ✅ Setup FTP server (vsftpd)
- ✅ Setup local repository (apt-mirror)
- ✅ Setup mail server (Postfix, Dovecot, Roundcube)
- ✅ Setup web cluster (Nginx, Keepalived, HAProxy)
- ✅ Setup database server (MariaDB)
- ✅ Setup monitoring (Prometheus, Grafana)

---

### 3. Run Validation

#### Option A: Automated Validation (Recommended)

```bash
# Run all validation checks
ansible-playbook validate-manual.yml

# Run specific validation:
ansible-playbook validate-manual.yml --tags firewall
ansible-playbook validate-manual.yml --tags dns
ansible-playbook validate-manual.yml --tags mail
ansible-playbook validate-manual.yml --tags web
```

**Output:**
- ✅ Green = PASSED
- ❌ Red = FAILED
- ⚠️ Yellow = WARNING

#### Option B: Manual Validation

**Firewall:**
```bash
ssh root@10.0.0.254
nft list ruleset | grep -A 5 "chain forward"
ping -c 2 8.8.8.8  # Test internet
```

**DNS:**
```bash
ssh root@10.0.0.10
dig @localhost lksn2025.id
dig @localhost mail.lksn2025.id
nslookup 192.168.1.10 localhost  # Reverse DNS
```

**LDAP:**
```bash
ssh root@10.0.0.10
ldapsearch -x -b "dc=lksn2025,dc=id" -H ldap://localhost
```

**Mail:**
```bash
ssh root@10.0.0.20
systemctl status postfix dovecot
echo "Test" | mail -s "Test" user@lksn2025.id
tail -f /var/log/mail.log
```

**Web Cluster:**
```bash
# Test VIP
curl http://172.16.1.100
curl https://www.lksn2025.id

# Check Keepalived
ssh root@10.0.0.21
ip addr show | grep 172.16.1.100  # Should show VIP on MASTER
```

**Database:**
```bash
ssh root@10.0.0.10
mysql -u root -p
SHOW DATABASES;
```

**Monitoring:**
```bash
# Access Grafana
http://172.16.1.40:3000
# Login: admin / admin

# Access Prometheus
http://172.16.1.40:9090
```

---

## Validation Checklist

### Network Connectivity
- [ ] All servers pingable via MGMT (10.0.0.x)
- [ ] Internet access from all servers
- [ ] Inter-VLAN routing works

### DNS
- [ ] Forward lookup: `dig @192.168.1.10 lksn2025.id`
- [ ] Reverse lookup: `dig @192.168.1.10 -x 192.168.1.10`
- [ ] Mail record: `dig @192.168.1.10 mail.lksn2025.id`

### LDAP
- [ ] LDAP service running
- [ ] Users searchable: `ldapsearch -x -b "dc=lksn2025,dc=id"`
- [ ] TLS enabled

### CA
- [ ] Root CA certificate exists
- [ ] Intermediate CA certificate exists
- [ ] Can issue certificates

### DHCP
- [ ] DHCP service running
- [ ] Lease file exists
- [ ] Correct IP range configured

### FTP
- [ ] FTP service running
- [ ] Anonymous access works
- [ ] User access works

### Repository
- [ ] Repository synced
- [ ] Accessible via HTTP
- [ ] Clients can use as apt source

### Mail
- [ ] Postfix running
- [ ] Dovecot running
- [ ] Roundcube accessible
- [ ] Can send/receive email

### Web Cluster
- [ ] Nginx running on both nodes
- [ ] Keepalived running
- [ ] VIP accessible (172.16.1.100)
- [ ] HAProxy load balancing works
- [ ] SSL certificates valid

### Database
- [ ] MariaDB running
- [ ] Databases created
- [ ] Users configured
- [ ] Remote access works

### Monitoring
- [ ] Prometheus running
- [ ] Grafana running
- [ ] Metrics being collected
- [ ] Dashboards accessible

---

## Troubleshooting

### Ansible Connection Failed
```bash
# Check SSH
ssh root@10.0.0.x

# Re-run SSH key distribution
cd /root/lks-debian-2025
./setup-juri-ssh-keys.sh

# Check inventory
cat ansible/inventory/hosts.ini
```

### Service Not Running
```bash
# Check service status
systemctl status <service>

# Check logs
journalctl -u <service> -f

# Restart service
systemctl restart <service>
```

### Configuration Error
```bash
# Re-run specific role
ansible-playbook site.yml --tags <role_name>

# Check configuration file
cat /etc/<service>/config
```

---

## Quick Commands Reference

```bash
# Test connectivity
ansible all -m ping

# Run automation
ansible-playbook site.yml

# Run validation
ansible-playbook validate-manual.yml

# Run specific role
ansible-playbook site.yml --tags dns

# Check service on all servers
ansible all -m shell -a "systemctl status sshd"

# Gather facts
ansible all -m setup

# Check disk space
ansible all -m shell -a "df -h"

# Check memory
ansible all -m shell -a "free -h"
```

---

## Expected Results

After successful automation:

✅ **Firewall:** NAT, routing, firewall rules configured  
✅ **DNS:** Forward/reverse zones, all records configured  
✅ **LDAP:** Directory service with users and groups  
✅ **CA:** Root and intermediate CAs ready  
✅ **DHCP:** Dynamic IP allocation configured  
✅ **FTP:** File transfer service ready  
✅ **Repository:** Local apt mirror available  
✅ **Mail:** Full email system (SMTP, IMAP, Webmail)  
✅ **Web:** High-availability web cluster with SSL  
✅ **Database:** MariaDB with replication  
✅ **Monitoring:** Prometheus + Grafana dashboards  

---

## Next Steps

1. **Test from client (ani-clt):**
   - Browse to http://www.lksn2025.id
   - Access webmail: http://mail.lksn2025.id/roundcube
   - Test FTP access
   - Test DHCP (request IP)

2. **Verify monitoring:**
   - Access Grafana: http://172.16.1.40:3000
   - Check all metrics are being collected
   - Verify alerts are configured

3. **Documentation:**
   - Document any manual changes
   - Update network diagram
   - Record credentials

4. **Backup:**
   - Backup configurations
   - Export VM snapshots
   - Document recovery procedures
