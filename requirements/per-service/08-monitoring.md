# Service 08: Monitoring Server (mon-srv)

> **VM:** mon-srv  
> **FQDN:** netmon.lksn2025.id  
> **IP:** 172.16.1.15/24 (DMZ)  
> **Services:** Cacti, SNMP

## 📋 Overview

Monitoring server menggunakan Cacti untuk network monitoring dengan SNMP.

## 🔧 Part 1: SNMP (On Monitored Servers)

### Installation (On Each Server to Monitor)
```bash
apt update
apt install -y snmpd snmp
```

### /etc/snmp/snmpd.conf
```conf
# Listen on all interfaces
agentAddress udp:161

# Community string
rocommunity lks-itnsa

# System information
sysLocation    LKSN 2025 Data Center
sysContact     admin@lksn2025.id
sysName        $(hostname)

# Access control
view   systemonly  included   .1.3.6.1.2.1.1
view   systemonly  included   .1.3.6.1.2.1.25.1
rocom unity lks-itnsa default -V systemonly
```

```bash
systemctl restart snmpd
systemctl enable snmpd
```

### Test SNMP
```bash
# From monitoring server
snmpwalk -v2c -c lks-itnsa 172.16.1.10 system
```

## 🔧 Part 2: Cacti

### Installation
```bash
apt update
apt install -y cacti cacti-spine apache2 mariadb-server php php-mysql php-snmp php-xml php-ldap php-gd rrdtool
```

### During Installation
- Configure database: Yes
- MySQL application password: Skills39!
- Web server: apache2

### Database Setup
```bash
mysql -u root -p
```

```sql
CREATE DATABASE cacti;
GRANT ALL PRIVILEGES ON cacti.* TO 'cacti'@'localhost' IDENTIFIED BY 'Skills39!';
FLUSH PRIVILEGES;
EXIT;
```

```bash
# Import Cacti database
mysql -u cacti -p cacti < /usr/share/doc/cacti/cacti.sql
```

### /etc/cacti/debian.php
```php
<?php
$database_type = 'mysql';
$database_default = 'cacti';
$database_hostname = 'localhost';
$database_username = 'cacti';
$database_password = 'Skills39!';
$database_port = '3306';
$database_ssl = false;
?>
```

### Apache Configuration
```bash
# Enable Cacti
ln -s /etc/cacti/apache.conf /etc/apache2/conf-available/cacti.conf
a2enconf cacti
systemctl reload apache2
```

### Access Cacti Web Interface
```
http://netmon.lksn2025.id/cacti
# Default login: admin / admin
# Change password to: Skills39!
```

### Initial Setup Wizard
1. Accept license agreement
2. Select "New Installation"
3. Verify all prerequisites are met
4. Select "Spine" as poller type
5. Complete installation

## 🔧 Part 3: Add Devices to Monitor

### Via Web Interface

1. **Console → Management → Devices → Add**
2. **Add Device:**
   - Description: fw-srv
   - Hostname: 172.16.1.254
   - Device Template: Generic SNMP Device
   - SNMP Version: Version 2
   - SNMP Community: lks-itnsa
   - Click "Create"

3. **Create Graphs:**
   - Select device
   - Click "Create Graphs for this Device"
   - Select graph templates (Interface Statistics, CPU Usage, Memory Usage)
   - Click "Create"

### Devices to Add

| Device | IP | Description |
|--------|----|----|
| fw-srv | 192.168.1.254 | Firewall |
| int-srv | 192.168.1.10 | Internal Services |
| mail-srv | 172.16.1.10 | Mail Server |
| db-srv | 172.16.1.17 | Database Server |
| web-01 | 172.16.1.21 | Web Server 1 |
| web-02 | 172.16.1.22 | Web Server 2 |

## 🔧 Part 4: Configure Poller

### /etc/cron.d/cacti
```cron
*/5 * * * * www-data php /usr/share/cacti/site/poller.php > /dev/null 2>&1
```

### Test Poller
```bash
sudo -u www-data php /usr/share/cacti/site/poller.php
```

## ✅ Validation

### Test SNMP from Monitoring Server
```bash
# Test connectivity
snmpwalk -v2c -c lks-itnsa 172.16.1.10 system

# Get specific OID (hostname)
snmpget -v2c -c lks-itnsa 172.16.1.10 sysName.0
```

### Test Cacti
```
http://netmon.lksn2025.id/cacti
Login: admin / Skills39!

Check:
- Devices are added
- Graphs are being created
- Data is being collected
```

### Validation Checklist

- [ ] **SNMP (on monitored servers)**
  - [ ] snmpd service running
  - [ ] Community string 'lks-itnsa' configured
  - [ ] Responding to SNMP queries
  
- [ ] **Cacti**
  - [ ] Web interface accessible
  - [ ] All devices added
  - [ ] Graphs created for each device
  - [ ] Poller running every 5 minutes
  - [ ] Data being collected

## 🐛 Common Issues

### Issue 1: SNMP timeout
**Symptom:** Device shows as "Down" in Cacti

**Diagnosis:**
```bash
# Test SNMP manually
snmpwalk -v2c -c lks-itnsa <device-ip> system

# Check if snmpd running on target
ssh <device> "systemctl status snmpd"
```

**Fix:**
1. Verify snmpd running on target
2. Check firewall allows UDP 161
3. Verify community string matches

### Issue 2: No graphs generating
**Symptom:** Graphs are empty

**Fix:**
```bash
# Check poller
sudo -u www-data php /usr/share/cacti/site/poller.php --force

# Check logs
tail -f /var/log/cacti/cacti.log

# Verify RRD files created
ls -la /var/lib/cacti/rra/
```

## 📚 References

- [Cacti Documentation](https://docs.cacti.net/)
- [SNMP Configuration](http://www.net-snmp.org/docs/man/snmpd.conf.html)
