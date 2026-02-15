# Service 12-13: System Security & Storage

> **Applies to:** All VMs  
> **Topics:** SSH Hardening, RAID Configuration

## 📋 Service 12: SSH Hardening

### /etc/ssh/sshd_config
```conf
# Port and Protocol
Port 22
Protocol 2

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Security
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 60

# Disable unused features
X11Forwarding no
AllowTcpForwarding no
PermitTunnel no

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Allowed users/groups
AllowUsers admin ani
AllowGroups ssh-users

# Ciphers and MACs (strong only)
Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,diffie-hellman-group-exchange-sha256

# Banner
Banner /etc/ssh/banner
```

### Create SSH Banner: /etc/ssh/banner
```
*******************************************************************
*                   AUTHORIZED ACCESS ONLY                        *
*                                                                 *
*  This system is for authorized use only. All activity may be   *
*  monitored and reported. Unauthorized access is prohibited.    *
*                                                                 *
*                      LKSN 2025 - IT Network Systems            *
*******************************************************************
```

### Setup SSH Keys
```bash
# On client (ani-clt)
ssh-keygen -t ed25519 -C "ani@lksn2025.id"
# Save to: /home/ani/.ssh/id_ed25519

# Copy public key to servers
ssh-copy-id -i ~/.ssh/id_ed25519.pub ani@192.168.1.10
ssh-copy-id -i ~/.ssh/id_ed25519.pub ani@172.16.1.10
# etc for all servers

# On server: verify authorized_keys
cat ~/.ssh/authorized_keys
```

### Create SSH Group
```bash
groupadd ssh-users
usermod -aG ssh-users ani
usermod -aG ssh-users admin
```

### Apply Configuration
```bash
# Test configuration
sshd -t

# Restart SSH
systemctl restart sshd
```

### Validation
```bash
# Test SSH with key
ssh -i ~/.ssh/id_ed25519 ani@192.168.1.10

# Verify password auth disabled
ssh -o PreferredAuthentications=password ani@192.168.1.10
# Should fail

# Check banner appears
ssh ani@192.168.1.10
```

---

## 📋 Service 13: RAID Configuration

### RAID 1 (Mirroring) - Jakarta 2025

**Requirement:** 2 disks of equal size

### 1. Install mdadm
```bash
apt update
apt install -y mdadm
```

### 2. Identify Disks
```bash
lsblk
# Example output:
# sdb     8:16   0   20G  0 disk
# sdc     8:32   0   20G  0 disk
```

### 3. Create RAID 1 Array
```bash
# Create RAID array
mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc

# Verify
cat /proc/mdstat
mdadm --detail /dev/md0
```

### 4. Create Filesystem
```bash
# Create ext4 filesystem
mkfs.ext4 /dev/md0

# Create mount point
mkdir -p /mnt/raid1

# Mount
mount /dev/md0 /mnt/raid1
```

### 5. Auto-mount on Boot
```bash
# Get UUID
blkid /dev/md0
# Output: /dev/md0: UUID="xxxxx-xxxx-xxxx" TYPE="ext4"

# Add to /etc/fstab
echo "UUID=xxxxx-xxxx-xxxx /mnt/raid1 ext4 defaults 0 2" >> /etc/fstab

# Save RAID configuration
mdadm --detail --scan >> /etc/mdadm/mdadm.conf

# Update initramfs
update-initramfs -u
```

### 6. Test RAID
```bash
# Write test file
echo "RAID test" > /mnt/raid1/test.txt

# Check RAID status
mdadm --detail /dev/md0
```

### Simulate Disk Failure
```bash
# Mark disk as failed
mdadm --manage /dev/md0 --fail /dev/sdb

# Remove failed disk
mdadm --manage /dev/md0 --remove /dev/sdb

# Check status (should show degraded)
cat /proc/mdstat

# Add replacement disk
mdadm --manage /dev/md0 --add /dev/sdb

# Monitor rebuild
watch cat /proc/mdstat
```

### Validation Checklist

**SSH Hardening:**
- [ ] Root login disabled
- [ ] Password authentication disabled
- [ ] SSH key authentication works
- [ ] Banner displays on login
- [ ] Only allowed users can connect
- [ ] Strong ciphers configured

**RAID:**
- [ ] RAID array created and active
- [ ] Filesystem mounted
- [ ] Auto-mount configured in /etc/fstab
- [ ] RAID config saved in mdadm.conf
- [ ] Can survive single disk failure
- [ ] Rebuild works after disk replacement

---

## 🐛 Common Issues

### SSH: Locked out after hardening
**Prevention:**
```bash
# ALWAYS test before closing current session
# Open NEW terminal and test SSH
ssh -i ~/.ssh/id_ed25519 user@server

# If works, then close old session
# If fails, fix in old session before closing
```

**Recovery:**
```bash
# Access via Proxmox console
# Edit /etc/ssh/sshd_config
PasswordAuthentication yes
PermitRootLogin yes

# Restart SSH
systemctl restart sshd
```

### RAID: Array won't start on boot
**Fix:**
```bash
# Verify mdadm.conf
cat /etc/mdadm/mdadm.conf

# Should contain:
# ARRAY /dev/md0 metadata=1.2 UUID=xxxxx

# Update initramfs
update-initramfs -u

# Reboot and check
reboot
cat /proc/mdstat
```

## 📚 References

- [SSH Hardening Guide](https://www.ssh.com/academy/ssh/sshd_config)
- [mdadm RAID Guide](https://raid.wiki.kernel.org/index.php/RAID_setup)
- [Linux RAID Documentation](https://www.kernel.org/doc/html/latest/admin-guide/md.html)
