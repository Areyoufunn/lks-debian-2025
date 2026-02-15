# Proxmox VM Creation Scripts

Bash scripts untuk membuat semua VM LKS 2025 di Proxmox dengan konfigurasi network bridge yang benar.

## 📋 Network Bridge Mapping

| Bridge | Zone | Network | Description |
|--------|------|---------|-------------|
| vmbr0 | WAN | 192.168.27.0/24 | Internet dari Proxmox host |
| INT | INT | 192.168.1.0/24 | Internal services zone |
| DMZ | DMZ | 172.16.1.0/24 | Public-facing services |
| MGMT | MGMT | 10.0.0.0/24 | Management network |

## 🖥️ VM Configuration

| VMID | Hostname | Cores | RAM | Disk | NICs | Bridges |
|------|----------|-------|-----|------|------|---------|
| 400 | fw-srv | 2 | 2GB | 32GB | 4 | vmbr0, INT, DMZ, MGMT |
| 401 | int-srv | 2 | 2GB | 32GB | 2 | INT, MGMT |
| 402 | mail-srv | 2 | 2GB | 32GB | 2 | DMZ, MGMT |
| 403 | web-01 | 2 | 2GB | 32GB | 2 | DMZ, MGMT |
| 404 | web-02 | 2 | 2GB | 32GB | 2 | DMZ, MGMT |
| 405 | db-srv | 2 | 2GB | 32GB | 2 | DMZ, MGMT |
| 406 | mon-srv | 2 | 2GB | 32GB | 2 | DMZ, MGMT |
| 407 | ani-clt | 2 | 2GB | 32GB | 2 | vmbr0, MGMT |

## 🚀 Usage

### Prerequisites

1. **Create Debian Template (ID 100)**:
   ```bash
   # Create a Debian 13 VM with ID 100
   # Install Debian with minimal packages
   # Configure cloud-init (optional)
   # Convert to template:
   qm template 100
   ```

2. **Create Network Bridges** di Proxmox (jika belum ada):
   ```bash
   # Edit /etc/network/interfaces
   # Add INT, DMZ, MGMT bridges
   
   auto INT
   iface INT inet static
       address 192.168.1.1
       netmask 255.255.255.0
       bridge-ports none
       bridge-stp off
       bridge-fd 0
   
   auto DMZ
   iface DMZ inet static
       address 172.16.1.1
       netmask 255.255.255.0
       bridge-ports none
       bridge-stp off
       bridge-fd 0
   
   auto MGMT
   iface MGMT inet static
       address 10.0.0.1
       netmask 255.255.255.0
       bridge-ports none
       bridge-stp off
       bridge-fd 0
   
   # Restart networking
   systemctl restart networking
   ```

### Method 1: Clone All VMs at Once

```bash
# Upload script to Proxmox
scp create-vms.sh root@proxmox:/root/

# SSH to Proxmox
ssh root@proxmox

# Make executable
chmod +x create-vms.sh

# Run script (will clone from template 100)
./create-vms.sh
```

### Method 2: Clone VMs Individually

```bash
# Upload script to Proxmox
scp create-vm-individual.sh root@proxmox:/root/

# SSH to Proxmox
ssh root@proxmox

# Make executable
chmod +x create-vm-individual.sh

# Run interactive script
./create-vm-individual.sh
```

## 📝 Post-Cloning Steps

### 1. Start VMs

```bash
# Start all VMs
for vmid in {400..407}; do
    qm start $vmid
done

# Or start individually
qm start 400  # fw-srv
qm start 401  # int-srv
# etc...
```

### 2. Configure Hostnames & IPs

Since VMs are cloned from template, you need to set unique hostnames and IPs.

**Option A: Manual Configuration**

SSH to each VM and configure `/etc/network/interfaces` and `/etc/hostname`

#### fw-srv (400)
```bash
auto ens18
iface ens18 inet static
    address 192.168.27.200
    netmask 255.255.255.0
    gateway 192.168.27.1

auto ens19
iface ens19 inet static
    address 192.168.1.254
    netmask 255.255.255.0

auto ens20
iface ens20 inet static
    address 172.16.1.254
    netmask 255.255.255.0

auto ens21
iface ens21 inet static
    address 10.0.0.11
    netmask 255.255.255.0
```

#### int-srv (401)
```bash
auto ens18
iface ens18 inet static
    address 192.168.1.10
    netmask 255.255.255.0
    gateway 192.168.1.254

auto ens19
iface ens19 inet static
    address 10.0.0.10
    netmask 255.255.255.0
```

*(Ulangi untuk VM lainnya sesuai topology-config.json)*

### 4. Setup SSH Keys

```bash
# From your workstation
ssh-keygen -t ed25519

# Copy to all VMs
for ip in 192.168.27.200 192.168.1.10 172.16.1.10 172.16.1.21 172.16.1.22 172.16.1.17 172.16.1.15 192.168.27.100; do
    ssh-copy-id root@$ip
done
```

### 5. Run Ansible Automation

```bash
cd /path/to/LKS/debian/ansible
ansible-playbook site.yml
```

## 🔧 Customization

Edit variables di script jika perlu:

```bash
TEMPLATE_ID=100              # Template VM ID
STORAGE="local-lvm"          # Storage pool (for cloning)
BRIDGE_WAN="vmbr0"
BRIDGE_INT="INT"
BRIDGE_DMZ="DMZ"
BRIDGE_MGMT="MGMT"
```

## 🗑️ Cleanup (Delete All VMs)

```bash
# Stop and delete all VMs
for vmid in {400..407}; do
    qm stop $vmid
    qm destroy $vmid
done
```

## 📊 Verification

```bash
# List all VMs
qm list | grep -E "40[0-7]"

# Check VM configuration
qm config 400

# Check network interfaces
qm config 400 | grep net
```

## 🔗 References

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Topology Configuration](../topology/topology-config.json)
- [Network Diagram](../topology/network-diagram.md)
