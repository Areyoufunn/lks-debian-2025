# Service 05: Mail Server (mail-srv)

> **VM:** mail-srv  
> **FQDN:** mail-srv.lksn2025.id  
> **IP:** 172.16.1.10/24 (DMZ)  
> **Services:** Postfix (SMTP), Dovecot (IMAP), Roundcube (Webmail)

## 📋 Overview

Mail server menyediakan email services dengan LDAP authentication.

## 🔧 Part 1: Postfix (SMTP Server)

### Installation
```bash
apt update
apt install -y postfix postfix-ldap
```

### /etc/postfix/main.cf
```conf
# Basic Settings
myhostname = mail-srv.lksn2025.id
mydomain = lksn2025.id
myorigin = $mydomain
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
mynetworks = 127.0.0.0/8, 192.168.1.0/24, 172.16.1.0/24, 10.0.0.0/24

# Virtual Mailbox
virtual_mailbox_domains = lksn2025.id
virtual_mailbox_base = /var/mail/vhosts
virtual_mailbox_maps = ldap:/etc/postfix/ldap-users.cf
virtual_alias_maps = hash:/etc/postfix/virtual

# LDAP Settings
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000

# TLS Settings (MANDATORY)
smtpd_tls_cert_file = /etc/ssl/certs/mail-srv.crt
smtpd_tls_key_file = /etc/ssl/private/mail-srv.key
smtpd_tls_security_level = encrypt
smtpd_tls_auth_only = yes
smtpd_tls_loglevel = 1

smtp_tls_security_level = may
smtp_tls_loglevel = 1

# SASL Authentication
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = $myhostname

# Restrictions
smtpd_recipient_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination
```

### /etc/postfix/ldap-users.cf
```conf
server_host = 192.168.1.10
search_base = ou=People,dc=lksn2025,dc=id
query_filter = (&(objectClass=inetOrgPerson)(mail=%s))
result_attribute = mail
bind = yes
bind_dn = cn=admin,dc=lksn2025,dc=id
bind_pw = Skills39!
version = 3
```

### /etc/postfix/virtual (Aliases)
```
contact@lksn2025.id    admin@lksn2025.id
```

```bash
postmap /etc/postfix/virtual
```

### Create Virtual Mailbox Directory
```bash
mkdir -p /var/mail/vhosts/lksn2025.id
groupadd -g 5000 vmail
useradd -g vmail -u 5000 vmail -d /var/mail/vhosts
chown -R vmail:vmail /var/mail/vhosts
```

### Restart Postfix
```bash
systemctl restart postfix
systemctl enable postfix
```

## 🔧 Part 2: Dovecot (IMAP Server)

### Installation
```bash
apt install -y dovecot-core dovecot-imapd dovecot-ldap
```

### /etc/dovecot/dovecot.conf
```conf
protocols = imap
listen = *
```

### /etc/dovecot/conf.d/10-mail.conf
```conf
mail_location = maildir:/var/mail/vhosts/%d/%n
mail_privileged_group = vmail

first_valid_uid = 5000
last_valid_uid = 5000
first_valid_gid = 5000
last_valid_gid = 5000
```

### /etc/dovecot/conf.d/10-auth.conf
```conf
disable_plaintext_auth = yes
auth_mechanisms = plain login

!include auth-ldap.conf.ext
```

### /etc/dovecot/conf.d/auth-ldap.conf.ext
```conf
passdb {
  driver = ldap
  args = /etc/dovecot/dovecot-ldap.conf.ext
}

userdb {
  driver = static
  args = uid=vmail gid=vmail home=/var/mail/vhosts/%d/%n
}
```

### /etc/dovecot/dovecot-ldap.conf.ext
```conf
hosts = 192.168.1.10
dn = cn=admin,dc=lksn2025,dc=id
dnpass = Skills39!
base = ou=People,dc=lksn2025,dc=id
scope = subtree
auth_bind = yes
auth_bind_userdn = uid=%n,ou=People,dc=lksn2025,dc=id
pass_filter = (&(objectClass=inetOrgPerson)(uid=%n))
```

### /etc/dovecot/conf.d/10-ssl.conf
```conf
ssl = required
ssl_cert = </etc/ssl/certs/mail-srv.crt
ssl_key = </etc/ssl/private/mail-srv.key
ssl_ca = </etc/ssl/certs/ca.crt
```

### /etc/dovecot/conf.d/10-master.conf
```conf
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
```

### Restart Dovecot
```bash
systemctl restart dovecot
systemctl enable dovecot
```

## 🔧 Part 3: Roundcube (Webmail)

### Installation
```bash
apt install -y apache2 php php-mysql php-mbstring php-intl php-xml php-ldap php-zip
apt install -y mariadb-server

# Download Roundcube
cd /tmp
wget https://github.com/roundcube/roundcubemail/releases/download/1.6.5/roundcubemail-1.6.5-complete.tar.gz
tar xzf roundcubemail-1.6.5-complete.tar.gz
mv roundcubemail-1.6.5 /var/www/html/roundcube
chown -R www-data:www-data /var/www/html/roundcube
```

### Create Database
```bash
mysql -u root -p
```

```sql
CREATE DATABASE roundcube;
GRANT ALL PRIVILEGES ON roundcube.* TO 'roundcube'@'localhost' IDENTIFIED BY 'Skills39!';
FLUSH PRIVILEGES;
EXIT;
```

```bash
mysql -u roundcube -p roundcube < /var/www/html/roundcube/SQL/mysql.initial.sql
```

### /var/www/html/roundcube/config/config.inc.php
```php
<?php
$config['db_dsnw'] = 'mysql://roundcube:Skills39!@localhost/roundcube';
$config['default_host'] = 'ssl://localhost';
$config['default_port'] = 993;
$config['smtp_server'] = 'tls://localhost';
$config['smtp_port'] = 587;
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';
$config['support_url'] = '';
$config['product_name'] = 'LKSN2025 Webmail';
$config['des_key'] = 'random24characterstring';
$config['plugins'] = array();
$config['language'] = 'id_ID';
$config['spellcheck_engine'] = 'googie';
?>
```

### Apache VirtualHost: /etc/apache2/sites-available/webmail.conf
```apache
<VirtualHost *:443>
    ServerName webmail.lksn2025.id
    DocumentRoot /var/www/html/roundcube
    
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/mail-srv.crt
    SSLCertificateKeyFile /etc/ssl/private/mail-srv.key
    SSLCertificateChainFile /etc/ssl/certs/ca.crt
    
    <Directory /var/www/html/roundcube>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/webmail_error.log
    CustomLog ${APACHE_LOG_DIR}/webmail_access.log combined
</VirtualHost>
```

```bash
a2enmod ssl
a2ensite webmail
systemctl reload apache2
```

## ✅ Validation

### Test SMTP
```bash
# Test from command line
echo "Test email" | mail -s "Test" ani@lksn2025.id

# Check logs
tail -f /var/log/mail.log
```

### Test IMAP
```bash
# Test with telnet
openssl s_client -connect localhost:993
# Login: a1 LOGIN ani Skills39!
# List: a2 LIST "" "*"
```

### Test Webmail
```
https://webmail.lksn2025.id
Login: ani@lksn2025.id / Skills39!
```

### Validation Checklist

- [ ] **Postfix**
  - [ ] Service running
  - [ ] TLS enabled
  - [ ] LDAP lookup works
  - [ ] Can send email
  
- [ ] **Dovecot**
  - [ ] Service running
  - [ ] IMAP SSL works
  - [ ] LDAP authentication works
  - [ ] Can receive email
  
- [ ] **Roundcube**
  - [ ] Accessible via HTTPS
  - [ ] Can login with LDAP users
  - [ ] Can send/receive emails

## 📚 References

- [Postfix Documentation](http://www.postfix.org/documentation.html)
- [Dovecot Wiki](https://doc.dovecot.org/)
- [Roundcube](https://roundcube.net/)
