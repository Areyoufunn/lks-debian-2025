# Service 07: Database Server (db-srv)

> **VM:** db-srv  
> **FQDN:** db.lksn2025.id  
> **IP:** 172.16.1.17/24 (DMZ)  
> **Services:** MariaDB, phpMyAdmin

## 📋 Overview

Database server untuk aplikasi web dengan phpMyAdmin untuk management.

## 🔧 Part 1: MariaDB

### Installation
```bash
apt update
apt install -y mariadb-server
```

### Secure Installation
```bash
mysql_secure_installation
# - Set root password: Skills39!
# - Remove anonymous users: Yes
# - Disallow root login remotely: No (untuk remote access)
# - Remove test database: Yes
# - Reload privilege tables: Yes
```

### Create Database & User (Jombang)
```bash
mysql -u root -p
```

```sql
-- Create database
CREATE DATABASE itnsa;

-- Create table
USE itnsa;
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nama VARCHAR(255) NOT NULL,
    alamat VARCHAR(255) NOT NULL
);

-- Insert sample data
INSERT INTO users (nama, alamat) VALUES
('Admin User', 'Jakarta'),
('Test User', 'Bandung');

-- Create user with remote access
CREATE USER 'itnsa'@'%' IDENTIFIED BY 'Skills39!';
GRANT ALL PRIVILEGES ON itnsa.* TO 'itnsa'@'%';

-- Also allow root remote access
CREATE USER 'root'@'172.16.1.%' IDENTIFIED BY 'Skills39!';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'172.16.1.%' WITH GRANT OPTION;

FLUSH PRIVILEGES;
EXIT;
```

### /etc/mysql/mariadb.conf.d/50-server.cnf
```ini
[mysqld]
# Bind to all interfaces
bind-address = 0.0.0.0

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
```

```bash
systemctl restart mariadb
systemctl enable mariadb
```

## 🔧 Part 2: phpMyAdmin

### Installation
```bash
apt install -y phpmyadmin apache2 php php-mysql libapache2-mod-php
# During installation:
# - Web server: apache2
# - Configure database: Yes
# - MySQL application password: Skills39!
```

### Apache Configuration
```bash
# Enable phpMyAdmin config
ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
a2enconf phpmyadmin
```

### SSL Configuration: /etc/apache2/sites-available/phpmyadmin-ssl.conf
```apache
<VirtualHost *:443>
    ServerName phpmyadmin.lksn2025.id
    DocumentRoot /usr/share/phpmyadmin
    
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/phpmyadmin.crt
    SSLCertificateKeyFile /etc/ssl/private/phpmyadmin.key
    
    <Directory /usr/share/phpmyadmin>
        Options FollowSymLinks
        DirectoryIndex index.php
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/phpmyadmin_error.log
    CustomLog ${APACHE_LOG_DIR}/phpmyadmin_access.log combined
</VirtualHost>
```

```bash
a2enmod ssl
a2ensite phpmyadmin-ssl
systemctl reload apache2
```

### /etc/phpmyadmin/config.inc.php
```php
<?php
$cfg['blowfish_secret'] = 'random32characterstringhere1234';

$i = 0;
$i++;
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['host'] = 'localhost';
$cfg['Servers'][$i]['compress'] = false;
$cfg['Servers'][$i]['AllowNoPassword'] = false;

$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
?>
```

## ✅ Validation

### Test MariaDB
```bash
# Local connection
mysql -u root -p

# Remote connection (from another server)
mysql -h 172.16.1.17 -u itnsa -p itnsa

# Test query
mysql -u itnsa -p itnsa -e "SELECT * FROM users;"
```

### Test phpMyAdmin
```
https://phpmyadmin.lksn2025.id
Login: root / Skills39!
```

### Validation Checklist

- [ ] **MariaDB**
  - [ ] Service running
  - [ ] Database 'itnsa' created
  - [ ] Table 'users' exists with correct schema
  - [ ] Remote access works from DMZ network
  - [ ] User 'itnsa' can access database
  
- [ ] **phpMyAdmin**
  - [ ] Accessible via HTTPS
  - [ ] Can login with root/itnsa user
  - [ ] Can browse database
  - [ ] SSL certificate valid (90 days)

## 🐛 Common Issues

### Issue 1: Can't connect remotely
**Symptom:** `ERROR 2003: Can't connect to MySQL server`

**Fix:**
```bash
# Check bind-address
grep bind-address /etc/mysql/mariadb.conf.d/50-server.cnf
# Should be 0.0.0.0

# Check firewall
nft list ruleset | grep 3306
```

### Issue 2: Access denied for user
**Symptom:** `ERROR 1045: Access denied`

**Fix:**
```sql
-- Check user grants
SELECT user, host FROM mysql.user;
SHOW GRANTS FOR 'itnsa'@'%';

-- Recreate user if needed
DROP USER 'itnsa'@'%';
CREATE USER 'itnsa'@'%' IDENTIFIED BY 'Skills39!';
GRANT ALL PRIVILEGES ON itnsa.* TO 'itnsa'@'%';
FLUSH PRIVILEGES;
```

## 📚 References

- [MariaDB Documentation](https://mariadb.org/documentation/)
- [phpMyAdmin Documentation](https://docs.phpmyadmin.net/)
