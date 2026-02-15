# Service Validation Scripts

Educational validation scripts dengan auto-correction capabilities.

## 🎯 Features

- **Educational Error Messages**: Setiap error dijelaskan dengan detail
- **Auto-Fix Mode**: Automatic correction dengan user confirmation
- **Service-Specific**: Validation per service
- **Color-Coded Output**: Easy to read results

## 🚀 Usage

### Basic Validation

```bash
# Run on specific server
./validate-services.sh

# Script akan auto-detect hostname dan run appropriate checks
```

### Auto-Fix Mode

```bash
# Enable interactive auto-fix
./validate-services.sh --fix

# Script akan offer to fix setiap error yang ditemukan
```

### Examples

```bash
# On int-srv (DNS server)
root@int-srv:~# ./validate-services.sh
🌐 DNS SERVER VALIDATION
[CHECK 1] Checking: Bind9 Service Running
✓ PASS

[CHECK 2] Checking: DNS Listening on Port 53
✗ FAIL

━━━ ERROR EXPLANATION ━━━
Problem: DNS not listening on port 53

Why this matters:
Port 53 adalah standard port untuk DNS. Jika tidak listen, 
client tidak bisa query DNS.

How to fix:
  systemctl restart bind9
```

## 📋 Validation Checks

### DNS Server (int-srv)
- ✓ Bind9 service running
- ✓ DNS listening on port 53
- ✓ Forward zone file exists
- ✓ Configuration syntax valid
- ✓ Zone file syntax valid

### Firewall (fw-srv)
- ✓ nftables service running
- ✓ IP forwarding enabled
- ✓ NAT rules configured
- ✓ Firewall rules loaded

### Mail Server (mail-srv)
- ✓ Postfix service running
- ✓ Dovecot service running
- ✓ SMTP port 25 listening
- ✓ IMAPS port 993 listening
- ✓ SSL certificate exists

### Web Cluster (web-01, web-02)
- ✓ Keepalived service running
- ✓ HAProxy service running
- ✓ Nginx service running
- ✓ VIP configured

### Database (db-srv)
- ✓ MariaDB service running
- ✓ Database 'itnsa' exists
- ✓ Remote access enabled

## 🎓 Educational Features

### Error Explanation Format

```
✗ FAIL

━━━ ERROR EXPLANATION ━━━
Problem: [What's wrong]

Why this matters:
[Detailed explanation of why this is important]

How to fix:
  [Exact command to fix the issue]
```

### Auto-Fix Workflow

1. Script detects error
2. Shows detailed explanation
3. Asks user: "Auto-fix this issue? [y/N]"
4. If yes, applies fix automatically
5. Verifies fix was successful

## 🔧 Customization

Edit `validate-services.sh` to add more checks:

```bash
check_service \
    "Service Name" \
    "test command" \
    "Error message" \
    "Detailed explanation" \
    "fix command"
```

## 📊 Exit Codes

- `0` - All checks passed
- `1` - Some checks failed

## 🔗 Integration with Ansible

Run validation after Ansible deployment:

```bash
# Deploy services
ansible-playbook site.yml

# Validate on each server
ansible all -m script -a "validate-services.sh"

# Or with auto-fix
ansible all -m script -a "validate-services.sh --fix"
```

## 📝 Example Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🔍 LKS 2025 - SERVICE VALIDATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🌐 DNS SERVER VALIDATION (int-srv)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[CHECK 1] Checking: Bind9 Service Running
✓ PASS

[CHECK 2] Checking: DNS Listening on Port 53
✓ PASS

[CHECK 3] Checking: Forward Zone File Exists
✓ PASS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📊 VALIDATION SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Checks:  5
Passed:        5
Failed:        0

✓ All checks passed! System is healthy.
```
