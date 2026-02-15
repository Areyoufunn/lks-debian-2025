# GitHub Deployment Guide

Panduan untuk deploy project ke GitHub dan setup di server.

## 📤 Push ke GitHub

### 1. Create Repository di GitHub

1. Buka https://github.com
2. Click "New repository"
3. Name: `lks-debian-2025`
4. Description: "LKS 2025 Debian Server Infrastructure Automation"
5. Public/Private: Pilih sesuai kebutuhan
6. **JANGAN** centang "Initialize with README" (sudah ada)
7. Click "Create repository"

### 2. Push dari Windows

```powershell
# Di folder project
cd C:\laragon\www\LKS\debian

# Initialize git (jika belum)
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit: Complete LKS 2025 automation"

# Add remote
git remote add origin https://github.com/YOUR-USERNAME/lks-debian-2025.git

# Push
git push -u origin main
```

## 📥 Setup di Server (Ansible Control Node)

### 1. Clone Repository

```bash
# SSH ke int-srv
ssh root@int-srv

# Clone repository
cd /root
git clone https://github.com/YOUR-USERNAME/lks-debian-2025.git
cd lks-debian-2025
```

### 2. Run Setup Script

```bash
chmod +x setup-control-node.sh
./setup-control-node.sh
```

### 3. Configure SSH Keys

```bash
# Copy SSH key ke semua managed nodes
ssh-copy-id root@fw-srv
ssh-copy-id root@mail-srv
ssh-copy-id root@web-01
ssh-copy-id root@web-02
ssh-copy-id root@mon-srv
ssh-copy-id root@ani-clt
```

### 4. Update Inventory

```bash
nano ansible/inventory/hosts.ini
```

Update dengan IP yang sesuai:
```ini
[firewall]
fw-srv ansible_host=192.168.1.254

[internal]
int-srv ansible_host=192.168.1.10

[mail]
mail-srv ansible_host=172.16.1.10
```

### 5. Test Connectivity

```bash
cd ansible
ansible all -m ping
```

Expected output:
```
fw-srv | SUCCESS => {
    "ping": "pong"
}
mail-srv | SUCCESS => {
    "ping": "pong"
}
...
```

## 🔄 Update Workflow

### Dari Windows (Update)

```powershell
# Edit files
# ...

# Commit and push
git add .
git commit -m "Update: description of changes"
git push
```

### Di Server (Pull Updates)

```bash
cd /root/lks-debian-2025
git pull

# Run updated playbooks
cd ansible
ansible-playbook site.yml
```

## 🎯 Usage Examples

### Deploy All Services

```bash
cd /root/lks-debian-2025/ansible
ansible-playbook site.yml
```

### Deploy Specific Service

```bash
# Deploy DNS only
ansible-playbook site.yml --tags dns

# Deploy firewall and DNS
ansible-playbook site.yml --tags firewall,dns
```

### Validate Configuration

```bash
# Validate all servers
ansible-playbook validate-manual.yml

# Validate specific service
ansible-playbook validate-manual.yml --tags dns

# Validate specific server
ansible-playbook validate-manual.yml --limit mail-srv
```

## 🔐 Security Best Practices

### 1. Use SSH Keys (Not Passwords)

```bash
# Generate strong key
ssh-keygen -t ed25519 -C "lks-ansible"

# Copy to servers
ssh-copy-id -i ~/.ssh/id_ed25519 root@server
```

### 2. Use Ansible Vault for Secrets

```bash
# Create vault file
ansible-vault create secrets.yml

# Edit vault
ansible-vault edit secrets.yml

# Use in playbook
ansible-playbook site.yml --ask-vault-pass
```

### 3. Limit Repository Access

- Use private repository untuk production
- Add collaborators dengan specific permissions
- Use branch protection rules

## 📝 Git Best Practices

### Commit Messages

```bash
# Good commit messages
git commit -m "Add: Mail role with Roundcube"
git commit -m "Fix: Database connection in Roundcube config"
git commit -m "Update: Firewall rules for SMTP"

# Bad commit messages
git commit -m "update"
git commit -m "fix bug"
```

### Branching

```bash
# Create feature branch
git checkout -b feature/add-vpn-role

# Make changes
# ...

# Commit
git commit -m "Add: VPN role with OpenVPN"

# Push branch
git push origin feature/add-vpn-role

# Merge to main (via Pull Request di GitHub)
```

## 🐛 Troubleshooting

### Git Push Rejected

```bash
# Pull first
git pull origin main

# Resolve conflicts if any
# Then push
git push
```

### SSH Key Issues

```bash
# Check SSH agent
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa

# Test SSH to GitHub
ssh -T git@github.com
```

### Ansible Connection Issues

```bash
# Test SSH manually
ssh root@server-ip

# Check SSH config
cat ~/.ssh/config

# Verbose Ansible
ansible all -m ping -vvv
```

## 📚 Additional Resources

- [Git Documentation](https://git-scm.com/doc)
- [GitHub Guides](https://guides.github.com/)
- [Ansible Documentation](https://docs.ansible.com/)
- [SSH Key Setup](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
