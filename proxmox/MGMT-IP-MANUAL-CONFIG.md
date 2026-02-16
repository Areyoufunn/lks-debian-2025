# MGMT IP Configuration Guide

Karena cloud-init tidak berfungsi, berikut cara manual configure MGMT IPs.

## 🔧 Problem

Cloud-init tidak apply IP configuration karena:
- Template belum punya cloud-init installed/configured
- Network interface names berbeda
- Cloud-init datasource tidak detected

## ✅ Solution: Manual Configuration

### Quick Method (Per VM via Console)

**1. Open VM Console di Proxmox**

**2. Login:**
```
Username: root
Password: 12345678
```

**3. Configure MGMT Interface:**

Untuk setiap VM, jalankan command sesuai tabel di bawah.

### MGMT IP Configuration Table

| VMID | Hostname  | MGMT IP     | Interface | Command |
|------|-----------|-------------|-----------|---------|
| 400  | fw-srv    | 10.0.0.254  | ens21     | See below |
| 401  | int-srv   | 10.0.0.10   | ens19     | See below |
| 402  | mail-srv  | 10.0.0.20   | ens19     | See below |
| 403  | web-01    | 10.0.0.21   | ens19     | See below |
| 404  | web-02    | 10.0.0.22   | ens19     | See below |
| 405  | db-srv    | 10.0.0.30   | ens19     | See below |
| 406  | mon-srv   | 10.0.0.40   | ens19     | See below |
| 407  | ani-clt   | 10.0.0.100  | ens19     | See below |
| 408  | juri-srv  | 10.0.0.50   | ens19     | See below |

### Configuration Commands

**fw-srv (VMID 400) - Interface ens21:**
```bash
cat > /etc/network/interfaces.d/ens21 << EOF
auto ens21
iface ens21 inet static
    address 10.0.0.254
    netmask 255.255.255.0
EOF
ifup ens21
```

**int-srv (VMID 401) - Interface ens19:**
```bash
cat > /etc/network/interfaces.d/ens19 << EOF
auto ens19
iface ens19 inet static
    address 10.0.0.10
    netmask 255.255.255.0
EOF
ifup ens19
```

**mail-srv (VMID 402) - Interface ens19:**
```bash
cat > /etc/network/interfaces.d/ens19 << EOF
auto ens19
iface ens19 inet static
    address 10.0.0.20
    netmask 255.255.255.0
EOF
ifup ens19
```

**web-01 (VMID 403) - Interface ens19:**
```bash
cat > /etc/network/interfaces.d/ens19 << EOF
auto ens19
iface ens19 inet static
    address 10.0.0.21
    netmask 255.255.255.0
EOF
ifup ens19
```

**web-02 (VMID 404) - Interface ens19:**
```bash
cat > /etc/network/interfaces.d/ens19 << EOF
auto ens19
iface ens19 inet static
    address 10.0.0.22
    netmask 255.255.255.0
EOF
ifup ens19
```

**db-srv (VMID 405) - Interface ens19:**
```bash
cat > /etc/network/interfaces.d/ens19 << EOF
auto ens19
iface ens19 inet static
    address 10.0.0.30
    netmask 255.255.255.0
EOF
ifup ens19
```

**mon-srv (VMID 406) - Interface ens19:**
```bash
cat > /etc/network/interfaces.d/ens19 << EOF
auto ens19
iface ens19 inet static
    address 10.0.0.40
    netmask 255.255.255.0
EOF
ifup ens19
```

**ani-clt (VMID 407) - Interface ens19:**
```bash
cat > /etc/network/interfaces.d/ens19 << EOF
auto ens19
iface ens19 inet static
    address 10.0.0.100
    netmask 255.255.255.0
EOF
ifup ens19
```

**juri-srv (VMID 408) - Interface ens19:**
```bash
cat > /etc/network/interfaces.d/ens19 << EOF
auto ens19
iface ens19 inet static
    address 10.0.0.50
    netmask 255.255.255.0
EOF
ifup ens19
```

## 🚀 Verification

Setelah configure, verify dengan:

```bash
# Check IP
ip addr show ens19  # atau ens21 untuk fw-srv

# Should show:
# inet 10.0.0.X/24 ...

# Test ping dari Proxmox host
ping 10.0.0.10  # int-srv
ping 10.0.0.50  # juri-srv
```

## 🔄 Alternative: Automated Script

Jika sudah punya network access ke VMs:

```bash
cd /root/lks-debian-2025/proxmox
./configure-mgmt-ips.sh
```

Script akan generate config files di `/tmp/mgmt-configs/`

## 📝 Next Steps

Setelah MGMT IPs configured:

```bash
# 1. SSH to juri-srv
ssh root@10.0.0.50
# Password: 12345678

# 2. Setup SSH keys
cd /root/lks-debian-2025
./setup-juri-ssh-keys.sh

# 3. Run Ansible
cd ansible
ansible all -m ping
ansible-playbook site.yml
```

## 🔧 Troubleshooting

### Interface name berbeda

Check interface names:
```bash
ip link show
```

Jika bukan `ens19/ens21`, sesuaikan config dengan interface yang benar.

### IP tidak muncul setelah ifup

```bash
# Manual add IP
ip addr add 10.0.0.10/24 dev ens19
ip link set ens19 up

# Check
ip addr show ens19
```

### Config tidak persistent setelah reboot

Pastikan file ada di `/etc/network/interfaces.d/` dan interface di-set `auto`:

```bash
ls -la /etc/network/interfaces.d/
cat /etc/network/interfaces.d/ens19
```

---

**Note:** Cloud-init akan di-fix di template preparation guide, tapi untuk sekarang gunakan manual configuration ini.
