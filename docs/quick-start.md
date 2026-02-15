# Quick Start Guide - LKS Automation Framework

## 🎯 Tujuan

Panduan ini akan membantu Anda:
1. Extract requirement dari PDF soal
2. Deploy automation framework
3. Validate konfigurasi

---

## 📋 Prerequisites

### System Requirements
- Proxmox VE environment
- 6 VM Debian 13 (Trixie) atau Debian 12 (Bookworm)
- Minimum specs per VM:
  - fw-srv: 2 vCPU, 2GB RAM, 20GB disk
  - int-srv: 2 vCPU, 2GB RAM, 20GB disk
  - mail-srv: 2 vCPU, 2GB RAM, 20GB disk
  - web-01: 1 vCPU, 1GB RAM, 20GB disk
  - web-02: 1 vCPU, 1GB RAM, 20GB disk
  - ani-clt: 1 vCPU, 1GB RAM, 20GB disk

### Network Setup di Proxmox
Buat 4 network bridges:

| Bridge | VLAN | Network | Purpose |
|--------|------|---------|---------|
| vmbr0 | - | 192.168.27.0/24 | Internet (WAN) |
| vmbr1 | 10 | 192.168.1.0/24 | Internal Zone |
| vmbr2 | 20 | 172.16.1.0/24 | DMZ Zone |
| vmbr3 | 99 | 10.0.0.0/24 | Management |

---

## 🚀 Step 1: Extract Requirements dari PDF

### 1.1 Buka Template
```bash
cd c:\laragon\www\LKS\debian\requirements
notepad TEMPLATE-requirement-extraction.md
```

### 1.2 Untuk Setiap PDF (8 source):

1. Buka PDF soal
2. Copy template ke file baru:
   ```bash
   copy TEMPLATE-requirement-extraction.md source-01-provinsi-2025.md
   ```
3. Isi template berdasarkan requirement di PDF
4. **Fokus pada unique features** - tandai requirement yang unik
5. Save file

### 1.3 Share dengan AI untuk Merge

Setelah semua 8 source di-extract, saya akan:
- Merge semua requirement
- Eliminasi duplikasi
- Generate `merged-requirements.md`
- Create per-service breakdown

---

## 🛠️ Step 2: Setup VM di Proxmox

### 2.1 Create VMs

Untuk setiap VM, set network interfaces sesuai topology:

**fw-srv** (4 interfaces):
- net0: vmbr0 (WAN)
- net1: vmbr1 (INT)
- net2: vmbr2 (DMZ)
- net3: vmbr3 (MGMT)

**int-srv** (2 interfaces):
- net0: vmbr1 (INT)
- net1: vmbr3 (MGMT)

**mail-srv** (2 interfaces):
- net0: vmbr2 (DMZ)
- net1: vmbr3 (MGMT)

**web-01 & web-02** (2 interfaces each):
- net0: vmbr2 (DMZ)
- net1: vmbr3 (MGMT)

**ani-clt** (2 interfaces):
- net0: vmbr0 (Internet)
- net1: vmbr3 (MGMT)

### 2.2 Install Debian

Pada setiap VM:
1. Install Debian 13 (minimal installation)
2. Set hostname sesuai topology
3. Configure network interfaces (manual IP)
4. Install basic tools:
   ```bash
   apt update
   apt install -y git curl wget vim sudo net-tools
   ```

---

## 📦 Step 3: Deploy Automation Framework

### 3.1 Clone/Copy Framework ke Setiap VM

```bash
# Di setiap VM
cd /opt
git clone [repository] lks-automation
# Atau copy manual dari USB/network share
```

### 3.2 Verify Topology Configuration

```bash
cd /opt/lks-automation
cat topology/topology-config.json
# Pastikan IP dan interface sesuai dengan VM Anda
```

---

## 🔧 Step 4: Deploy Services

### Option A: Deploy Individual Service (Recommended untuk Learning)

#### 4.1 Deploy Firewall (fw-srv)
```bash
# SSH ke fw-srv
cd /opt/lks-automation/services/01-firewall

# Review dokumentasi dulu
cat docs.md

# Deploy dengan penjelasan
sudo ./auto-config.sh --explain

# Validate
sudo ./auto-check.sh --verbose
```

#### 4.2 Deploy DNS (int-srv)
```bash
# SSH ke int-srv
cd /opt/lks-automation/services/02-dns

# Review dokumentasi
cat docs.md

# Deploy
sudo ./auto-config.sh --explain

# Validate
sudo ./auto-check.sh --verbose
```

#### 4.3 Lanjutkan untuk service lainnya
Ikuti urutan di [Deployment Flow](deployment-flow.md)

### Option B: Deploy All (Fast Mode)

```bash
# SSH ke control machine (bisa dari ani-clt atau laptop)
cd /opt/lks-automation/orchestrator

# Deploy semua service sesuai dependency
sudo ./deploy-all.sh --interactive

# Validate semua
sudo ./check-all.sh --report
```

---

## ✅ Step 5: Validation

### 5.1 Per-Service Validation

Setiap service punya auto-check script:

```bash
cd /opt/lks-automation/services/[service-name]
sudo ./auto-check.sh --verbose
```

Output example:
```
=== Firewall Configuration Check ===
[✓] Network interfaces configured
[✓] IP forwarding enabled
[✓] Firewall rules loaded (45 rules)
[✓] NAT configuration active
[✗] VPN service - NOT RUNNING
    └─ Fix: systemctl start openvpn@server

Status: 80% Complete (4/5 checks passed)
```

### 5.2 Integration Testing

```bash
cd /opt/lks-automation/orchestrator
sudo ./check-all.sh --integration
```

Tests:
- ✅ DNS resolution dari semua zones
- ✅ Mail flow (send & receive)
- ✅ Web cluster failover
- ✅ LDAP authentication
- ✅ VPN connectivity

---

## 📚 Step 6: Baca Dokumentasi

### Per-Service Documentation

Setiap service punya `docs.md` yang menjelaskan:
- **Apa** yang dilakukan setiap command
- **Kenapa** perlu dikonfigurasi
- **Bagaimana** cara kerjanya
- **Troubleshooting** common errors

```bash
# Example: Baca dokumentasi DNS
cat /opt/lks-automation/services/02-dns/docs.md
```

### Command Reference

```bash
cat /opt/lks-automation/docs/command-reference.md
```

---

## 🐛 Troubleshooting

### Error saat deployment?

1. **Check logs:**
   ```bash
   tail -f /var/log/lks-automation/[service].log
   ```

2. **Run check dengan debug:**
   ```bash
   sudo ./auto-check.sh --verbose --debug
   ```

3. **Review troubleshooting guide:**
   ```bash
   cat /opt/lks-automation/docs/troubleshooting.md
   ```

4. **Rollback jika perlu:**
   ```bash
   cd /opt/lks-automation/orchestrator
   sudo ./rollback.sh --service [service-name]
   ```

---

## 📊 Monitoring Progress

### Task Checklist

Framework include task checklist untuk track progress:

```bash
cat /opt/lks-automation/PROGRESS.md
```

Example:
```
[ ] 1. Firewall & Routing
    [✓] Network interfaces
    [✓] Firewall rules
    [✓] NAT configuration
    [ ] VPN server
[ ] 2. DNS Server
    [ ] Bind9 installation
    [ ] Zone configuration
    [ ] DNS records
```

---

## ⏱️ Time Estimates

| Task | Estimated Time |
|------|----------------|
| Extract requirements (8 PDFs) | 2-3 hours |
| Setup Proxmox VMs | 1 hour |
| Deploy with automation | 1-2 hours |
| Validation & testing | 30 minutes |
| **Total** | **4.5-6.5 hours** |

Compare dengan manual (tanpa automation): **15-20 hours**

---

## 🎓 Learning Path

### Untuk Pemahaman Maksimal:

1. **Deploy manual 1 service pertama** (Firewall)
   - Baca docs.md
   - Jalankan command satu per satu
   - Pahami setiap step

2. **Deploy dengan automation untuk service berikutnya**
   - Gunakan `--explain` flag
   - Review generated config files
   - Understand what automation did

3. **Use full automation untuk final deployment**
   - Deploy all dengan orchestrator
   - Focus pada integration testing
   - Practice troubleshooting

---

## 📞 Next Steps

1. ✅ Extract requirements dari 8 PDF soal
2. ✅ Setup Proxmox VMs
3. ✅ Deploy framework
4. ✅ Validate configuration
5. ✅ Practice troubleshooting
6. ✅ Ready for LKS! 🚀

---

**Questions?** Check [Troubleshooting Guide](troubleshooting.md) atau review service-specific `docs.md`
