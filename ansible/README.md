# LKS Debian Automation - Ansible Playbooks

## 📋 Overview

Ansible automation untuk konfigurasi semua services di topologi LKS Debian.

## 🏗️ Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── site.yml                 # Master playbook
├── inventory/
│   └── hosts.ini           # Inventory dengan semua hosts
├── roles/
│   ├── firewall/           # Firewall & NAT
│   ├── dns/                # Bind9 DNS
│   ├── ca/                 # Certificate Authority
│   ├── ldap/               # OpenLDAP
│   ├── mail/               # Postfix + Dovecot + Roundcube
│   ├── webcluster/         # Keepalived + HAProxy + Nginx
│   ├── database/           # MariaDB + phpMyAdmin
│   ├── monitoring/         # Cacti + SNMP
│   ├── dhcp/               # DHCP Server
│   ├── ftp/                # ProFTPD
│   ├── repository/         # Local APT Repository
│   └── ssh-hardening/      # SSH Security
└── logs/                   # Ansible logs
```

## 🚀 Usage

### Prerequisites

```bash
# Install Ansible
apt update
apt install -y ansible

# Verify installation
ansible --version
```

### Setup SSH Keys

```bash
# Generate SSH key (if not exists)
ssh-keygen -t ed25519

# Copy to all servers
ssh-copy-id root@192.168.27.200  # fw-srv
ssh-copy-id root@192.168.1.10    # int-srv
ssh-copy-id root@172.16.1.10     # mail-srv
ssh-copy-id root@172.16.1.17     # db-srv
ssh-copy-id root@172.16.1.15     # mon-srv
ssh-copy-id root@172.16.1.21     # web-01
ssh-copy-id root@172.16.1.22     # web-02
```

### Run Playbooks

#### 1. Deploy All Services (Full Automation)

```bash
cd /path/to/LKS/debian/ansible

# Run all phases
ansible-playbook site.yml

# Run with explain mode (educational)
ansible-playbook site.yml -e "explain_mode=true"
```

#### 2. Deploy Specific Phase

```bash
# Phase 1: Firewall only
ansible-playbook site.yml --tags phase1

# Phase 2: DNS only
ansible-playbook site.yml --tags phase2

# Phase 3: CA only
ansible-playbook site.yml --tags phase3

# Phase 4: LDAP only
ansible-playbook site.yml --tags phase4

# Phase 5: Mail only
ansible-playbook site.yml --tags phase5

# Phase 6: Web Cluster only
ansible-playbook site.yml --tags phase6

# Phase 7: Database only
ansible-playbook site.yml --tags phase7

# Phase 8: Monitoring only
ansible-playbook site.yml --tags phase8

# Phase 9: Additional Services only
ansible-playbook site.yml --tags phase9

# Phase 10: SSH Hardening only
ansible-playbook site.yml --tags phase10
```

#### 3. Deploy Specific Service

```bash
# Firewall
ansible-playbook site.yml --tags firewall

# DNS
ansible-playbook site.yml --tags dns

# LDAP
ansible-playbook site.yml --tags ldap

# Mail
ansible-playbook site.yml --tags mail

# Web
ansible-playbook site.yml --tags web

# Database
ansible-playbook site.yml --tags database

# Monitoring
ansible-playbook site.yml --tags monitoring
```

#### 4. Deploy to Specific Host

```bash
# Deploy firewall to fw-srv only
ansible-playbook site.yml --limit firewall

# Deploy DNS to int-srv only
ansible-playbook site.yml --limit internal --tags dns

# Deploy web cluster to both web servers
ansible-playbook site.yml --limit webcluster
```

## 🎓 Educational Mode

Gunakan `explain_mode=true` untuk melihat penjelasan setiap step:

```bash
ansible-playbook site.yml -e "explain_mode=true"
```

Output akan menampilkan:
- Apa yang dikonfigurasi
- Kenapa konfigurasi ini diperlukan
- File apa yang diubah
- Service apa yang di-restart

## ✅ Verification

### Check Inventory

```bash
# List all hosts
ansible all --list-hosts

# Ping all hosts
ansible all -m ping

# Check specific group
ansible firewall -m ping
ansible internal -m ping
ansible webcluster -m ping
```

### Dry Run (Check Mode)

```bash
# Test tanpa mengubah apapun
ansible-playbook site.yml --check

# Test specific phase
ansible-playbook site.yml --tags phase1 --check
```

### Verbose Output

```bash
# Level 1: Basic
ansible-playbook site.yml -v

# Level 2: More details
ansible-playbook site.yml -vv

# Level 3: Debug
ansible-playbook site.yml -vvv
```

## 📝 Deployment Order

Playbook akan deploy services dalam urutan yang benar berdasarkan dependencies:

1. **Phase 1:** Firewall (Foundation)
2. **Phase 2:** DNS (Name Resolution)
3. **Phase 3:** CA (Certificates)
4. **Phase 4:** LDAP (Authentication)
5. **Phase 5:** Mail Server
6. **Phase 6:** Web Cluster
7. **Phase 7:** Database
8. **Phase 8:** Monitoring
9. **Phase 9:** Additional Services (DHCP, FTP, Repo)
10. **Phase 10:** SSH Hardening

## 🐛 Troubleshooting

### Connection Issues

```bash
# Test SSH connection
ansible all -m ping

# If fails, check SSH keys
ssh root@<host-ip>
```

### Playbook Fails

```bash
# Run with verbose
ansible-playbook site.yml -vvv

# Check logs
tail -f logs/ansible.log

# Run specific task
ansible-playbook site.yml --start-at-task="Task Name"
```

### Reset Configuration

```bash
# Remove generated files on target
ansible all -m shell -a "rm -rf /etc/bind/zones /etc/nftables.conf"

# Re-run playbook
ansible-playbook site.yml
```

## 📚 Next Steps

After running automation:
1. Run validation scripts (in `../validation/`)
2. Test each service manually
3. Review logs for any errors
4. Document any customizations

## 🔗 References

- [Ansible Documentation](https://docs.ansible.com/)
- [Service Documentation](../requirements/per-service/)
- [Topology Configuration](../topology/topology-config.json)
