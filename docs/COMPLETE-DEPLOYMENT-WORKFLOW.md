# Complete Deployment Workflow - LKS 2025

Panduan lengkap dari create VMs sampai running Ansible automation.

## 🎯 Overview

Workflow ini menggunakan **automated MGMT IP configuration** via qemu-guest-agent untuk setup cepat.

**Total Time:** ~10 menit untuk 9 VMs siap Ansible!

---

## 📋 Prerequisites

### 1. Proxmox Template (ID 100)

Template harus punya:
- ✅ Debian 12 (Bookworm)
- ✅ **qemu-guest-agent** installed dan enabled
- ✅ **openssh-server** installed dan enabled
- ✅ cloud-init installed

**Cara prepare template:** Lihat `TEMPLATE-PREPARATION.md`

### 2. Network Bridges

Pastikan bridges sudah dibuat di Proxmox:
- `vmbr0` - WAN/Internet
- `INT` - Internal Zone
- `DMZ` - DMZ Zone  
- `MGMT` - Management Zone

### 3. Repository

Clone repository di Proxmox host:
```bash
cd /root
git clone https://github.com/Areyoufunn/lks-debian-2025.git
cd lks-debian-2025
```

---

## 🚀 Complete Workflow

### Step 1: Create VMs (Di Proxmox Host)

```bash
cd /root/lks-debian-2025/proxmox

# Make scripts executable
chmod +x *.sh

# Create all VMs
./create-vms.sh

# Output:
# ✓ Template 100 found
# [1/9] Cloning fw-srv... ✓
# [2/9] Cloning int-srv... ✓
# ... (9 VMs total)
# ✓ All VMs cloned successfully!
```

**Time:** ~2 menit

---

### Step 2: Start VMs

```bash
# Start all VMs
for i in {400..408}; do qm start $i; done

# Wait for boot
sleep 30
```

**Time:** ~30 detik

---

### Step 3: Configure MGMT IPs (AUTOMATED!)

```bash
# Run automated configuration
./configure-mgmt-ips-auto.sh

# Output:
# ━━━ Checking qemu-guest-agent ━━━
# ✓ fw-srv agent responding
# ✓ int-srv agent responding
# ... (all VMs)
#
# ━━━ Configuring MGMT IPs ━━━
# ✓ fw-srv configured (10.0.0.254)
# ✓ int-srv configured (10.0.0.10)
# ... (all VMs)
#
# ━━━ Configuring SSH ━━━
# ✓ SSH enabled on all VMs
#
# ✓ All MGMT IPs configured successfully!
```

**Time:** ~2 menit

**Troubleshooting:**
- Jika agent tidak responding, pastikan qemu-guest-agent installed di template
- Jika gagal, gunakan manual config: `MGMT-IP-MANUAL-CONFIG.md`

---

### Step 4: Verify Connectivity

```bash
# Test ping dari Proxmox host
ping -c 3 10.0.0.50   # juri-srv
ping -c 3 10.0.0.10   # int-srv
ping -c 3 10.0.0.20   # mail-srv

# Test SSH
ssh root@10.0.0.50
# Password: 12345678
exit
```

**Time:** ~1 menit

---

### Step 5: Setup SSH Keys (Di juri-srv)

```bash
# SSH to juri-srv
ssh root@10.0.0.50
# Password: 12345678

# Clone repository
cd /root
git clone https://github.com/Areyoufunn/lks-debian-2025.git
cd lks-debian-2025

# Make scripts executable
chmod +x *.sh

# Distribute SSH keys
./setup-juri-ssh-keys.sh

# Output:
# [1/3] Generating SSH Key...
# ✓ SSH key generated
#
# [2/3] Displaying Public Key
# ssh-rsa AAAA...
#
# [3/3] Distributing SSH Key to Servers
# ━━━ Copying key to fw-srv (192.168.27.200) ━━━
# Password: 12345678
# ✓ Key copied to fw-srv
# ... (all servers)
#
# ✓ All SSH keys distributed successfully!
```

**Time:** ~3 menit (input password 8x)

---

### Step 6: Verify Ansible Connectivity

```bash
# Still di juri-srv
cd /root/lks-debian-2025/ansible

# Test ping
ansible all -m ping

# Expected output:
# fw-srv | SUCCESS => { "ping": "pong" }
# int-srv | SUCCESS => { "ping": "pong" }
# mail-srv | SUCCESS => { "ping": "pong" }
# ... (all servers)
```

**Time:** ~30 detik

---

### Step 7: Run Ansible Automation

```bash
# Deploy all services
ansible-playbook site.yml

# Or deploy by phase
ansible-playbook site.yml --tags phase1
ansible-playbook site.yml --tags phase2

# Or deploy specific service
ansible-playbook site.yml --tags dns
ansible-playbook site.yml --tags mail
```

**Time:** ~15-30 menit (tergantung services)

---

### Step 8: Validate Configuration

```bash
# Run validation
ansible-playbook validate-manual.yml

# Or validate specific service
ansible-playbook validate-manual.yml --tags dns
ansible-playbook validate-manual.yml --tags firewall
```

**Time:** ~5 menit

---

## ✅ Verification Checklist

### Network
- [ ] All VMs have MGMT IP (10.0.0.x)
- [ ] Can ping all VMs from Proxmox host
- [ ] Can SSH to all VMs from juri-srv

### SSH Keys
- [ ] Passwordless SSH from juri-srv to all servers
- [ ] `ansible all -m ping` returns SUCCESS for all

### Services (After Ansible)
- [ ] DNS resolving (dig @192.168.1.10 lksn2025.id)
- [ ] LDAP users created (ldapsearch)
- [ ] Web cluster accessible (curl https://172.16.1.100)
- [ ] Mail server accepting (telnet 172.16.1.10 25)
- [ ] Database accessible (mysql -h 192.168.1.10)

---

## 🔧 Troubleshooting

### qemu-guest-agent not responding

```bash
# Check if enabled in VM settings
qm config 401 | grep agent

# Should show: agent: enabled=1

# If not, enable it
qm set 401 --agent enabled=1

# Restart VM
qm reboot 401

# Wait and test
sleep 30
qm agent 401 ping
```

### MGMT IP not configured

**Fallback to manual:**
```bash
# Open VM console in Proxmox
# Login: root / 12345678

# For int-srv (example):
cat > /etc/network/interfaces.d/ens19 << EOF
auto ens19
iface ens19 inet static
    address 10.0.0.10
    netmask 255.255.255.0
EOF
ifup ens19
```

See `MGMT-IP-MANUAL-CONFIG.md` for all VMs.

### SSH key distribution failed

```bash
# Manual copy to failed server
ssh-copy-id root@<server-ip>
# Password: 12345678

# Or check network connectivity
ping <server-ip>
```

### Ansible connection failed

```bash
# Check SSH from juri-srv
ssh root@10.0.0.10  # Should work without password

# Check inventory
cat ansible/inventory/hosts.ini

# Test specific host
ansible int-srv -m ping
```

---

## 📊 Time Summary

| Step | Time | Description |
|------|------|-------------|
| 1 | 2 min | Create VMs |
| 2 | 0.5 min | Start VMs |
| 3 | 2 min | Configure MGMT IPs (automated) |
| 4 | 1 min | Verify connectivity |
| 5 | 3 min | Setup SSH keys |
| 6 | 0.5 min | Test Ansible |
| 7 | 15-30 min | Deploy services |
| 8 | 5 min | Validate |
| **Total** | **~30-45 min** | **Complete deployment** |

---

## 🎯 Quick Reference

### MGMT IP Mapping
```
fw-srv:   10.0.0.254
int-srv:  10.0.0.10
mail-srv: 10.0.0.20
web-01:   10.0.0.21
web-02:   10.0.0.22
db-srv:   10.0.0.30
mon-srv:  10.0.0.40
ani-clt:  10.0.0.100
juri-srv: 10.0.0.50
```

### Credentials
```
Username: root
Password: 12345678
```

### Key Scripts
```
create-vms.sh                 # Create all VMs
configure-mgmt-ips-auto.sh    # Auto-configure MGMT IPs
setup-juri-ssh-keys.sh        # Distribute SSH keys
delete-all-vms.sh             # Cleanup all VMs
```

---

**Ready for LKS 2025!** 🚀
