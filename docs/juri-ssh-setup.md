# Juri Server SSH Key Setup Guide

Panduan untuk setup SSH keys di juri-srv untuk akses passwordless ke semua server.

## 🔑 Quick Setup

### Automated (Recommended)

```bash
# Di juri-srv, setelah run setup-juri-server.sh
cd /root/lks-debian-2025
./setup-juri-ssh-keys.sh
```

Script akan:
1. ✅ Generate SSH key pair (RSA 4096-bit)
2. ✅ Distribute public key ke 8 servers
3. ✅ Enable passwordless SSH access

### Manual Setup

```bash
# 1. Generate SSH key
ssh-keygen -t rsa -b 4096 -C "juri-srv@lksn2025"
# Tekan Enter 3x (default location, no passphrase)

# 2. Copy ke setiap server
ssh-copy-id root@192.168.27.200  # fw-srv
ssh-copy-id root@192.168.1.10    # int-srv
ssh-copy-id root@172.16.1.10     # mail-srv
ssh-copy-id root@172.16.1.21     # web-01
ssh-copy-id root@172.16.1.22     # web-02
ssh-copy-id root@172.16.1.30     # db-srv
ssh-copy-id root@172.16.1.40     # mon-srv
ssh-copy-id root@192.168.27.100  # ani-clt
```

## 📋 Server List

| Hostname  | IP Address      | Zone     |
|-----------|-----------------|----------|
| fw-srv    | 192.168.27.200  | WAN      |
| int-srv   | 192.168.1.10    | Internal |
| mail-srv  | 172.16.1.10     | DMZ      |
| web-01    | 172.16.1.21     | DMZ      |
| web-02    | 172.16.1.22     | DMZ      |
| db-srv    | 172.16.1.30     | DMZ      |
| mon-srv   | 172.16.1.40     | DMZ      |
| ani-clt   | 192.168.27.100  | WAN      |

## ✅ Verification

### Test SSH Connection

```bash
# Test connection ke setiap server (tanpa password)
ssh root@fw-srv "hostname"
ssh root@int-srv "hostname"
ssh root@mail-srv "hostname"
ssh root@web-01 "hostname"
ssh root@web-02 "hostname"
ssh root@db-srv "hostname"
ssh root@mon-srv "hostname"
ssh root@ani-clt "hostname"
```

### Test Ansible Connectivity

```bash
cd /root/lks-debian-2025/ansible

# Ping all servers
ansible all -m ping

# Expected output:
# fw-srv | SUCCESS => { "ping": "pong" }
# int-srv | SUCCESS => { "ping": "pong" }
# ...
```

## 🔧 Troubleshooting

### Error: "Permission denied (publickey)"

**Problem:** SSH key tidak ter-copy dengan benar.

**Solution:**
```bash
# Copy ulang ke server yang bermasalah
ssh-copy-id root@<server-ip>

# Atau manual copy
cat ~/.ssh/id_rsa.pub | ssh root@<server-ip> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### Error: "Connection refused"

**Problem:** Server tidak reachable atau SSH service tidak running.

**Solution:**
```bash
# Check network connectivity
ping <server-ip>

# Check SSH port
nc -zv <server-ip> 22

# Di server target, check SSH service
systemctl status sshd
systemctl start sshd
```

### Error: "Host key verification failed"

**Problem:** Server SSH fingerprint berubah atau belum di-trust.

**Solution:**
```bash
# Remove old fingerprint
ssh-keygen -R <server-ip>

# Reconnect (akan add new fingerprint)
ssh root@<server-ip>
```

## 🔐 Security Best Practices

### 1. Use Strong Key

Script sudah generate RSA 4096-bit key (recommended).

### 2. Protect Private Key

```bash
# Ensure correct permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 700 ~/.ssh
```

### 3. Disable Password Authentication (Optional)

Setelah SSH key working, bisa disable password auth di semua server:

```bash
# Di setiap server
nano /etc/ssh/sshd_config

# Set:
PasswordAuthentication no
PubkeyAuthentication yes

# Restart SSH
systemctl restart sshd
```

⚠️ **Warning:** Pastikan SSH key sudah working sebelum disable password auth!

## 📝 Usage After Setup

### Run Validation

```bash
cd /root/lks-debian-2025/ansible

# Validate all servers
ansible-playbook validate-manual.yml

# Validate specific service
ansible-playbook validate-manual.yml --tags dns
ansible-playbook validate-manual.yml --tags firewall

# Validate specific server
ansible-playbook validate-manual.yml --limit int-srv
```

### Deploy Configuration

```bash
# Deploy all services
ansible-playbook site.yml

# Deploy specific phase
ansible-playbook site.yml --tags phase1
ansible-playbook site.yml --tags phase2
```

### Ad-hoc Commands

```bash
# Run command on all servers
ansible all -a "uptime"
ansible all -a "df -h"

# Run command on specific group
ansible webcluster -a "systemctl status nginx"
ansible internal -a "systemctl status bind9"

# Copy file to all servers
ansible all -m copy -a "src=/root/test.txt dest=/tmp/test.txt"
```

## 🎯 Next Steps

After SSH keys are distributed:

1. ✅ Test Ansible connectivity: `ansible all -m ping`
2. ✅ Update inventory IPs if needed: `nano ansible/inventory/hosts.ini`
3. ✅ Run validation: `ansible-playbook validate-manual.yml`
4. ✅ Deploy services: `ansible-playbook site.yml`

---

**Note:** Juri-srv sekarang punya full access ke semua servers untuk validation dan configuration management.
