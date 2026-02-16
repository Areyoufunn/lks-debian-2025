# Proxmox Template Preparation Guide

Panduan untuk membuat Debian template dengan cloud-init, SSH, dan **qemu-guest-agent** pre-installed.

## 🎯 Overview

Template ini akan digunakan untuk clone semua VMs dengan fitur:
- ✅ **qemu-guest-agent** - REQUIRED untuk automated MGMT IP configuration
- ✅ **openssh-server** - Pre-installed dan enabled
- ✅ Cloud-init untuk basic user/password setup
- ✅ Ready for automation

> **IMPORTANT:** qemu-guest-agent adalah WAJIB untuk automated MGMT IP configuration!

## 📋 Step-by-Step

### 1. Create Base VM

```bash
# Di Proxmox Web UI atau CLI
# Create VM dengan ID 100
qm create 100 --name debian-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Download Debian 12 cloud image
cd /var/lib/vz/template/iso
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2

# Import disk
qm importdisk 100 debian-12-generic-amd64.qcow2 local-lvm

# Attach disk
qm set 100 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-100-disk-0

# Set boot disk
qm set 100 --boot c --bootdisk scsi0

# Add cloud-init drive
qm set 100 --ide2 local-lvm:cloudinit

# Add serial console
qm set 100 --serial0 socket --vga serial0
```

### 2. Start and Configure VM

```bash
# Start VM
qm start 100

# Login via console (default cloud image credentials vary)
# Or set temporary cloud-init user
qm set 100 --ciuser debian
qm set 100 --cipassword temppass
qm set 100 --ipconfig0 ip=dhcp

# Reboot to apply cloud-init
qm reboot 100

# SSH to VM
ssh debian@<vm-ip>
```

### 3. Install Required Packages

```bash
# Update system
sudo apt update
sudo apt upgrade -y

# Install essential packages
sudo apt install -y \
    openssh-server \
    cloud-init \
    qemu-guest-agent \
    curl \
    wget \
    vim \
    net-tools \
    iputils-ping \
    dnsutils

# Enable services
sudo systemctl enable ssh
sudo systemctl enable qemu-guest-agent
sudo systemctl enable cloud-init
```

### 4. Configure SSH

```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Ensure these settings:
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes

# Restart SSH
sudo systemctl restart ssh
```

### 5. Configure Cloud-init

```bash
# Ensure cloud-init is configured for all datasources
sudo nano /etc/cloud/cloud.cfg

# Make sure these are present:
datasource_list: [ NoCloud, ConfigDrive, OpenStack, None ]

# Preserve hostname
preserve_hostname: false

# Install packages on first boot
packages:
  - openssh-server
  - qemu-guest-agent

# Run commands on first boot
runcmd:
  - systemctl enable ssh
  - systemctl start ssh
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
```

### 6. Clean Up Before Template Conversion

```bash
# Clean cloud-init
sudo cloud-init clean --logs --seed

# Clean package cache
sudo apt clean
sudo apt autoclean

# Remove SSH host keys (will be regenerated on clone)
sudo rm -f /etc/ssh/ssh_host_*

# Clean machine-id
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id

# Clean logs
sudo find /var/log -type f -exec truncate -s 0 {} \;

# Clean bash history
history -c
cat /dev/null > ~/.bash_history

# Shutdown
sudo shutdown -h now
```

### 7. Convert to Template

```bash
# Di Proxmox host
qm template 100
```

## ✅ Verification

Template sudah siap! Test dengan clone:

```bash
# Clone test
qm clone 100 999 --name test-vm --full

# Configure cloud-init
qm set 999 --ide2 local-lvm:cloudinit
qm set 999 --ciuser root
qm set 999 --cipassword Skills39!
qm set 999 --ipconfig0 ip=192.168.1.99/24,gw=192.168.1.1

# Start
qm start 999

# Wait ~1 minute, then test SSH
ssh root@192.168.1.99
# Password: Skills39!

# If successful, delete test VM
qm stop 999
qm destroy 999 --purge
```

## 🔧 Troubleshooting

### SSH not working

```bash
# Check if SSH is installed
dpkg -l | grep openssh-server

# Check if SSH is running
systemctl status ssh

# Check SSH config
cat /etc/ssh/sshd_config | grep -E "PermitRootLogin|PasswordAuthentication"
```

### Cloud-init not applying

```bash
# Check cloud-init status
cloud-init status

# Check cloud-init logs
cat /var/log/cloud-init.log
cat /var/log/cloud-init-output.log

# Manually run cloud-init
cloud-init clean
cloud-init init
```

### QEMU Guest Agent not responding

```bash
# Check if installed
dpkg -l | grep qemu-guest-agent

# Check if running
systemctl status qemu-guest-agent

# Restart
systemctl restart qemu-guest-agent
```

## 📝 Template Checklist

Before converting to template, ensure:

- [ ] openssh-server installed and enabled
- [ ] qemu-guest-agent installed and enabled
- [ ] cloud-init installed and configured
- [ ] Root login permitted
- [ ] Password authentication enabled
- [ ] SSH host keys removed
- [ ] machine-id cleared
- [ ] Logs cleaned
- [ ] Cloud-init cleaned
- [ ] VM shutdown

## 🚀 Usage with create-vms.sh

Setelah template ready:

```bash
cd /root/lks-debian-2025/proxmox
./create-vms.sh

# VMs akan di-clone dengan:
# - MGMT IP auto-configured
# - SSH enabled
# - Root login: Skills39!
# - Ready for setup-juri-ssh-keys.sh
```

## 📚 Related Documentation

- [VM Creation Script](create-vms.sh)
- [Juri SSH Setup](../docs/juri-ssh-setup.md)
- [Ansible Documentation](../ansible/README.md)

---

**Template ID:** 100  
**Ready for LKS 2025!** 🚀
