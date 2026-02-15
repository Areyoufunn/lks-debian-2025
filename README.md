# LKS 2025 - Debian Server Infrastructure Automation

Complete automation and validation system untuk LKS 2025 Debian Server Infrastructure.

## 📋 Overview

Project ini berisi:
- **Proxmox VM automation** - Create 8 VMs otomatis
- **Ansible automation** - 13 roles untuk semua services
- **Validation system** - Check konfigurasi manual dengan penjelasan error
- **Complete documentation** - Setup guides dan troubleshooting

## 🏗️ Architecture

```
Ansible Control Node (int-srv)
    │
    ├──> fw-srv (Firewall/Gateway)
    ├──> mail-srv (Mail Server)
    ├──> web-01 (Web Server - MASTER)
    ├──> web-02 (Web Server - BACKUP)
    ├──> mon-srv (Monitoring)
    └──> ani-clt (Client)
```

## 🚀 Quick Start

### 1. Setup Ansible Control Node

```bash
# Clone repository
git clone https://github.com/YOUR-USERNAME/lks-debian.git
cd lks-debian

# Run setup script
chmod +x setup-control-node.sh
./setup-control-node.sh
```

### 2. Configure Inventory

Edit `ansible/inventory/hosts.ini` dengan IP servers Anda.

### 3. Deploy Services

```bash
cd ansible
ansible-playbook site.yml
```

### 4. Validate Configuration

```bash
ansible-playbook validate-manual.yml
```

## 📁 Project Structure

```
.
├── proxmox/           # Proxmox VM automation
├── ansible/           # Ansible automation (13 roles)
├── validation/        # Service validation scripts
└── docs/             # Documentation
```

## 🎯 Services (13 Roles)

1. Firewall, 2. DNS, 3. LDAP, 4. CA, 5. Mail, 6. Web Cluster, 7. Database, 8. Monitoring, 9. DHCP, 10. FTP, 11. Repository, 12. SSH Hardening, 13. RAID

## 📖 Documentation

- [Deployment Flow](docs/deployment-flow.md)
- [Ansible README](ansible/README.md)
- [Validation Guide](ansible/MANUAL-VALIDATION.md)
- [Proxmox Setup](proxmox/README.md)

---

**For educational and competition purposes.**
