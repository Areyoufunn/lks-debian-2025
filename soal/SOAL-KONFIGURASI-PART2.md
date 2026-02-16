# SOAL KONFIGURASI - PART 2: WEB, MAIL, DATABASE, MONITORING

## 🌐 MODUL 5: WEB CLUSTER HIGH AVAILABILITY

**Servers:** web-01 (VMID 403), web-02 (VMID 404)  
**Waktu:** 90 menit  
**Poin:** 150

### Task 5.1: Install Keepalived (Both Servers)

```bash
apt install keepalived -y
```

**web-01 (MASTER):**
```bash
# /etc/keepalived/keepalived.conf

vrrp_instance VI_1 {
    state MASTER
    interface ens18
    virtual_router_id 51
    priority 110
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass Skills39!
    }
    
    virtual_ipaddress {
        172.16.1.100/24
    }
}
```

**web-02 (BACKUP):**
```bash
# /etc/keepalived/keepalived.conf

vrrp_instance VI_1 {
    state BACKUP
    interface ens18
    virtual_router_id 51
    priority 100
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass Skills39!
    }
    
    virtual_ipaddress {
        172.16.1.100/24
    }
}
```

```bash
# Start keepalived on both servers
systemctl enable keepalived
systemctl start keepalived

# Verify VIP
ip addr show ens18 | grep 172.16.1.100
```

### Task 5.2: Install HAProxy (Both Servers)

```bash
apt install haproxy -y
```

```bash
# /etc/haproxy/haproxy.cfg

global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

# Stats page
listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats auth admin:Skills39!

# HTTP Frontend (Redirect to HTTPS)
frontend http_front
    bind *:80
    redirect scheme https code 301

# HTTPS Frontend
frontend https_front
    bind *:443 ssl crt /etc/ssl/lksn2025/web.pem
    
    # Add custom header
    http-response set-header Via-Proxy %H
    
    default_backend web_servers

# Backend Web Servers
backend web_servers
    balance roundrobin
    option httpchk GET /
    http-check expect status 200
    
    server web-01 172.16.1.21:8080 check
    server web-02 172.16.1.22:8080 check
```

**Prepare SSL certificate:**
```bash
mkdir -p /etc/ssl/lksn2025

# Copy from CA server (int-srv)
scp root@192.168.1.10:/root/ca/certs/web.crt /etc/ssl/lksn2025/
scp root@192.168.1.10:/root/ca/private/web.key /etc/ssl/lksn2025/

# Combine for HAProxy
cat /etc/ssl/lksn2025/web.crt /etc/ssl/lksn2025/web.key > /etc/ssl/lksn2025/web.pem
chmod 600 /etc/ssl/lksn2025/web.pem
```

```bash
systemctl enable haproxy
systemctl restart haproxy
```

### Task 5.3: Install Nginx (Both Servers)

```bash
apt install nginx -y
```

```bash
# /etc/nginx/sites-available/default

server {
    listen 8080;
    server_name _;
    
    root /var/www/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Protected directory
    location /data/file/ {
        auth_basic "Restricted Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
        autoindex on;
    }
}
```

**Create content:**
```bash
# web-01
echo "<h1>Hello from web-01</h1>" > /var/www/html/index.html

# web-02
echo "<h1>Hello from web-02</h1>" > /var/www/html/index.html

# Create protected directory
mkdir -p /var/www/html/data/file
echo "Protected content" > /var/www/html/data/file/test.txt

# Create htpasswd
apt install apache2-utils -y
htpasswd -bc /etc/nginx/.htpasswd rahasia Skills39
```

```bash
systemctl enable nginx
systemctl restart nginx
```

### Task 5.4: Verify Web Cluster

```bash
# From ani-clt or external
curl http://172.16.1.100
curl -k https://172.16.1.100
curl -I https://172.16.1.100 | grep Via-Proxy

# Test load balancing (should alternate)
for i in {1..10}; do curl http://172.16.1.21:8080; done

# Test failover
# Stop keepalived on web-01, VIP should move to web-02
systemctl stop keepalived
ip addr show ens18 | grep 172.16.1.100  # Should be on web-02
```

**Verifikasi:**
- [ ] VIP active on MASTER
- [ ] HAProxy running on both servers
- [ ] Nginx running on port 8080
- [ ] HTTPS working with valid certificate
- [ ] Load balancing working
- [ ] Failover working
- [ ] Protected directory requires auth

---

## 📧 MODUL 6: MAIL SERVER

**Server:** mail-srv (VMID 402)  
**Waktu:** 90 menit  
**Poin:** 150

### Task 6.1: Install Mail Packages

```bash
apt install postfix dovecot-core dovecot-imapd dovecot-lmtpd -y
apt install postfix-ldap dovecot-ldap -y
```

### Task 6.2: Configure Postfix (SMTP)

```bash
# /etc/postfix/main.cf

# Basic settings
myhostname = mail.lksn2025.id
mydomain = lksn2025.id
myorigin = $mydomain
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
mynetworks = 127.0.0.0/8, 192.168.1.0/24, 172.16.1.0/24

# TLS settings
smtpd_tls_cert_file = /etc/ssl/lksn2025/mail.crt
smtpd_tls_key_file = /etc/ssl/lksn2025/mail.key
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_received_header = yes

smtp_tls_security_level = may
smtp_tls_note_starttls_offer = yes

# LDAP virtual mailbox
virtual_mailbox_domains = lksn2025.id
virtual_transport = lmtp:unix:private/dovecot-lmtp

# LDAP lookups
virtual_mailbox_maps = ldap:/etc/postfix/ldap-users.cf
virtual_alias_maps = ldap:/etc/postfix/ldap-aliases.cf

# SASL authentication
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes

# Restrictions
smtpd_recipient_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination
```

**LDAP User Lookup:**
```bash
# /etc/postfix/ldap-users.cf

server_host = 192.168.1.10
server_port = 389
search_base = ou=People,dc=lksn2025,dc=id
query_filter = (&(objectClass=inetOrgPerson)(mail=%s))
result_attribute = mail
bind = no
```

**LDAP Alias Lookup:**
```bash
# /etc/postfix/ldap-aliases.cf

server_host = 192.168.1.10
server_port = 389
search_base = ou=People,dc=lksn2025,dc=id
query_filter = (&(objectClass=inetOrgPerson)(uid=%u))
result_attribute = mail
bind = no
```

**Master config:**
```bash
# /etc/postfix/master.cf

# Add submission port
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
```

**Copy certificates:**
```bash
mkdir -p /etc/ssl/lksn2025
scp root@192.168.1.10:/root/ca/certs/mail.crt /etc/ssl/lksn2025/
scp root@192.168.1.10:/root/ca/private/mail.key /etc/ssl/lksn2025/
chmod 600 /etc/ssl/lksn2025/mail.key
```

### Task 6.3: Configure Dovecot (IMAP)

```bash
# /etc/dovecot/dovecot.conf

protocols = imap lmtp
listen = *
```

```bash
# /etc/dovecot/conf.d/10-mail.conf

mail_location = maildir:~/Maildir
mail_privileged_group = mail
```

```bash
# /etc/dovecot/conf.d/10-auth.conf

disable_plaintext_auth = yes
auth_mechanisms = plain login

# Disable system auth
!include auth-system.conf.ext

# Enable LDAP auth
!include auth-ldap.conf.ext
```

```bash
# /etc/dovecot/conf.d/auth-ldap.conf.ext

passdb {
  driver = ldap
  args = /etc/dovecot/dovecot-ldap.conf.ext
}

userdb {
  driver = ldap
  args = /etc/dovecot/dovecot-ldap.conf.ext
}
```

```bash
# /etc/dovecot/dovecot-ldap.conf.ext

hosts = 192.168.1.10
dn = cn=admin,dc=lksn2025,dc=id
dnpass = Skills39!
base = ou=People,dc=lksn2025,dc=id
scope = subtree

user_attrs = homeDirectory=home,uidNumber=uid,gidNumber=gid
user_filter = (&(objectClass=posixAccount)(uid=%n))

pass_attrs = uid=user,userPassword=password
pass_filter = (&(objectClass=posixAccount)(uid=%n))

default_pass_scheme = SSHA
```

```bash
# /etc/dovecot/conf.d/10-ssl.conf

ssl = required
ssl_cert = </etc/ssl/lksn2025/mail.crt
ssl_key = </etc/ssl/lksn2025/mail.key
ssl_min_protocol = TLSv1.2
```

```bash
# /etc/dovecot/conf.d/10-master.conf

service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}

service imap-login {
  inet_listener imap {
    port = 0  # Disable non-SSL
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
}
```

### Task 6.4: Install Roundcube Webmail

```bash
apt install roundcube roundcube-mysql -y
```

**Database setup:**
```bash
mysql -u root -p

CREATE DATABASE roundcube CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON roundcube.* TO 'roundcube'@'localhost' IDENTIFIED BY 'Skills39!';
FLUSH PRIVILEGES;
EXIT;

# Import schema
mysql -u roundcube -p roundcube < /usr/share/roundcube/SQL/mysql.initial.sql
```

**Configure Roundcube:**
```bash
# /etc/roundcube/config.inc.php

$config['db_dsnw'] = 'mysql://roundcube:Skills39!@localhost/roundcube';
$config['default_host'] = 'ssl://localhost';
$config['default_port'] = 993;
$config['smtp_server'] = 'tls://localhost';
$config['smtp_port'] = 587;
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';
$config['support_url'] = '';
$config['product_name'] = 'LKSN 2025 Webmail';
$config['des_key'] = 'random_24_character_string';
$config['plugins'] = array();
```

**Nginx vhost:**
```bash
# /etc/nginx/sites-available/roundcube

server {
    listen 80;
    server_name webmail.lksn2025.id;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name webmail.lksn2025.id;
    
    ssl_certificate /etc/ssl/lksn2025/mail.crt;
    ssl_certificate_key /etc/ssl/lksn2025/mail.key;
    
    root /usr/share/roundcube;
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}
```

```bash
ln -s /etc/nginx/sites-available/roundcube /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

### Task 6.5: Restart and Verify

```bash
systemctl restart postfix dovecot
systemctl enable postfix dovecot

# Test SMTP
telnet localhost 25
EHLO lksn2025.id
QUIT

# Test IMAP
openssl s_client -connect localhost:993

# Test webmail
curl -k https://webmail.lksn2025.id

# Send test email
echo "Test email" | mail -s "Test" ani@lksn2025.id
```

**Verifikasi:**
- [ ] Postfix running and accepting mail
- [ ] Dovecot IMAPS working (port 993)
- [ ] LDAP authentication working
- [ ] Roundcube accessible via HTTPS
- [ ] Can send/receive email
- [ ] TLS encryption enforced

---

## 💾 MODUL 7: DATABASE SERVER

**Server:** int-srv (VMID 401)  
**Waktu:** 45 menit  
**Poin:** 80

### Task 7.1: Install MariaDB

```bash
apt install mariadb-server mariadb-client -y
```

### Task 7.2: Secure Installation

```bash
mysql_secure_installation

# Set root password: Skills39!
# Remove anonymous users: Yes
# Disallow root login remotely: No (we need remote access)
# Remove test database: Yes
# Reload privilege tables: Yes
```

### Task 7.3: Configure Remote Access

```bash
# /etc/mysql/mariadb.conf.d/50-server.cnf

[mysqld]
bind-address = 0.0.0.0
```

```bash
systemctl restart mariadb
```

### Task 7.4: Create Databases and Users

```bash
mysql -u root -p

-- Create databases
CREATE DATABASE itnsa CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE roundcube CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create users with remote access
CREATE USER 'itnsa'@'%' IDENTIFIED BY 'Skills39!';
GRANT ALL PRIVILEGES ON itnsa.* TO 'itnsa'@'%';

CREATE USER 'roundcube'@'172.16.1.%' IDENTIFIED BY 'Skills39!';
GRANT ALL PRIVILEGES ON roundcube.* TO 'roundcube'@'172.16.1.%';

CREATE USER 'cacti'@'172.16.1.%' IDENTIFIED BY 'Skills39!';
GRANT ALL PRIVILEGES ON cacti.* TO 'cacti'@'172.16.1.%';

-- Allow root remote access
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'Skills39!' WITH GRANT OPTION;

FLUSH PRIVILEGES;
EXIT;
```

### Task 7.5: Create Sample Table

```bash
mysql -u root -p itnsa

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nama VARCHAR(100) NOT NULL,
    alamat VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (nama, alamat) VALUES 
('Admin', 'Jakarta'),
('Ani', 'Bandung'),
('Budi', 'Surabaya');

SELECT * FROM users;
EXIT;
```

### Task 7.6: Install phpMyAdmin

```bash
apt install phpmyadmin -y

# During installation:
# Web server: apache2
# Configure database: Yes
# Password: Skills39!
```

**Nginx vhost:**
```bash
# /etc/nginx/sites-available/phpmyadmin

server {
    listen 80;
    server_name phpmyadmin.lksn2025.id;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name phpmyadmin.lksn2025.id;
    
    ssl_certificate /etc/ssl/lksn2025/web.crt;
    ssl_certificate_key /etc/ssl/lksn2025/web.key;
    
    root /usr/share/phpmyadmin;
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}
```

```bash
ln -s /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

### Task 7.7: Verify Database

```bash
# Test local connection
mysql -u root -p -e "SHOW DATABASES;"

# Test remote connection (from another server)
mysql -h 192.168.1.10 -u root -p -e "SHOW DATABASES;"

# Test phpMyAdmin
curl -k https://phpmyadmin.lksn2025.id
```

**Verifikasi:**
- [ ] MariaDB running
- [ ] Remote access enabled
- [ ] Databases created (itnsa, roundcube, cacti)
- [ ] Users created with proper permissions
- [ ] Sample table with data
- [ ] phpMyAdmin accessible via HTTPS

---

## 📊 MODUL 8: MONITORING SERVER

**Server:** mon-srv (VMID 406)  
**Waktu:** 60 menit  
**Poin:** 100

### Task 8.1: Install SNMP on Target Servers

**Run on all servers to be monitored:**
```bash
apt install snmpd -y

# /etc/snmp/snmpd.conf

# Listen on all interfaces
agentAddress udp:161

# Community string
rocommunity lks-itnsa default

# System information
sysLocation    LKS 2025 Data Center
sysContact     admin@lksn2025.id

# Restart
systemctl restart snmpd
systemctl enable snmpd
```

### Task 8.2: Install Cacti

```bash
apt update
apt install cacti cacti-spine -y

# During installation:
# Web server: apache2
# Configure database: Yes
# MySQL password: Skills39!
# Cacti admin password: admin
```

### Task 8.3: Configure Cacti Database

```bash
# Create database on int-srv
mysql -h 192.168.1.10 -u root -p

CREATE DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON cacti.* TO 'cacti'@'172.16.1.%' IDENTIFIED BY 'Skills39!';
FLUSH PRIVILEGES;
EXIT;

# Import Cacti schema
mysql -h 192.168.1.10 -u cacti -p cacti < /usr/share/cacti/cacti.sql
```

**Configure Cacti:**
```bash
# /etc/cacti/debian.php

$database_type = 'mysql';
$database_default = 'cacti';
$database_hostname = '192.168.1.10';
$database_username = 'cacti';
$database_password = 'Skills39!';
$database_port = '3306';
$database_ssl = false;
```

### Task 8.4: Configure Nginx for Cacti

```bash
# /etc/nginx/sites-available/cacti

server {
    listen 80;
    server_name cacti.lksn2025.id netmon.lksn2025.id;
    
    root /usr/share/cacti;
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
```

```bash
apt install php-fpm php-mysql php-snmp php-xml php-ldap php-mbstring php-gd php-gmp -y

ln -s /etc/nginx/sites-available/cacti /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx php-fpm
```

### Task 8.5: Add Devices to Cacti

**Via Web Interface:**
1. Access: http://cacti.lksn2025.id
2. Login: admin / admin
3. Complete setup wizard
4. Go to: Console → Devices → Add
5. Add each server:
   - Description: fw-srv
   - Hostname: 192.168.27.200
   - SNMP Community: lks-itnsa
   - SNMP Version: Version 2
   - Device Template: Generic SNMP Device
6. Create graphs for each device

### Task 8.6: Verify Monitoring

```bash
# Test SNMP from mon-srv
snmpwalk -v2c -c lks-itnsa 192.168.27.200 system
snmpwalk -v2c -c lks-itnsa 192.168.1.10 system
snmpwalk -v2c -c lks-itnsa 172.16.1.10 system

# Check Cacti poller
php /usr/share/cacti/poller.php

# Access web interface
curl http://cacti.lksn2025.id
```

**Verifikasi:**
- [ ] SNMP installed on all servers
- [ ] Cacti web interface accessible
- [ ] Database connection working
- [ ] Devices added to Cacti
- [ ] Graphs generating data
- [ ] Poller running successfully

---

## ✅ CHECKLIST AKHIR

### Network Connectivity
- [ ] All servers can ping gateway
- [ ] All servers can access internet
- [ ] Inter-zone communication working

### DNS
- [ ] Forward zone resolving
- [ ] Reverse zone resolving
- [ ] All A records correct
- [ ] MX record working

### LDAP
- [ ] Service running
- [ ] 3 users created
- [ ] Authentication working

### Certificate Authority
- [ ] Root CA created
- [ ] Server certificates signed
- [ ] CA trusted by all servers

### Firewall
- [ ] NFTables rules loaded
- [ ] NAT working
- [ ] Port forwarding working
- [ ] Zone isolation enforced

### Web Cluster
- [ ] VIP active
- [ ] HAProxy load balancing
- [ ] HTTPS working
- [ ] Failover working

### Mail Server
- [ ] SMTP accepting mail
- [ ] IMAP working
- [ ] Roundcube accessible
- [ ] LDAP authentication working
- [ ] TLS enforced

### Database
- [ ] MariaDB running
- [ ] Remote access working
- [ ] Databases created
- [ ] phpMyAdmin accessible

### Monitoring
- [ ] SNMP responding on all servers
- [ ] Cacti web interface working
- [ ] Devices added
- [ ] Graphs generating

---

## 🎯 SCORING RUBRIC

| Module | Points | Criteria |
|--------|--------|----------|
| Firewall | 100 | NAT (30), Port Forwarding (30), Zone Rules (40) |
| DNS | 80 | Forward Zone (30), Reverse Zone (30), MX Record (20) |
| LDAP | 100 | Installation (20), Users (40), Authentication (40) |
| CA | 80 | Root CA (30), Server Certs (30), Distribution (20) |
| Web Cluster | 150 | Keepalived (40), HAProxy (50), Nginx (30), SSL (30) |
| Mail | 150 | Postfix (40), Dovecot (40), Roundcube (40), LDAP (30) |
| Database | 80 | Installation (20), Remote Access (30), Data (30) |
| Monitoring | 100 | SNMP (40), Cacti (40), Graphs (20) |
| **TOTAL** | **840** | |

**Passing Score:** 600/840 (71%)

---

**Good Luck!** 🚀
