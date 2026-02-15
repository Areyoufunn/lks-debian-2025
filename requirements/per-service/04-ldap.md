# Service 04: LDAP Directory (int-srv)

> **VM:** int-srv  
> **Role:** LDAP Directory Service (slapd)  
> **IP:** 192.168.1.10/24  
> **Port:** 389 (LDAP), 636 (LDAPS)

## 📋 Overview

LDAP menyediakan **centralized authentication** untuk semua services (Mail, VPN, Web).

## 🔧 Installation

```bash
# Install OpenLDAP
apt update
apt install -y slapd ldap-utils

# Reconfigure (set admin password: Skills39!)
dpkg-reconfigure slapd
# - Omit OpenLDAP server configuration? No
# - DNS domain name: lksn2025.id
# - Organization name: LKSN2025
# - Administrator password: Skills39!
# - Database backend: MDB
# - Remove database when slapd is purged? No
# - Move old database? Yes
```

## 📝 Directory Structure

### Base DN: dc=lksn2025,dc=id

```
dc=lksn2025,dc=id
├── ou=People          (Users)
├── ou=Groups          (Groups)
├── ou=VPN             (VPN users)
└── ou=Mail            (Mail users)
```

## 🔧 LDIF Files

### 1. Create OUs: base.ldif
```ldif
dn: ou=People,dc=lksn2025,dc=id
objectClass: organizationalUnit
ou: People

dn: ou=Groups,dc=lksn2025,dc=id
objectClass: organizationalUnit
ou: Groups

dn: ou=VPN,dc=lksn2025,dc=id
objectClass: organizationalUnit
ou: VPN

dn: ou=Mail,dc=lksn2025,dc=id
objectClass: organizationalUnit
ou: Mail
```

```bash
ldapadd -x -D cn=admin,dc=lksn2025,dc=id -W -f base.ldif
```

### 2. Create Users: users.ldif
```ldif
# User: admin
dn: uid=admin,ou=People,dc=lksn2025,dc=id
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: admin
cn: Administrator
sn: Admin
mail: admin@lksn2025.id
uidNumber: 10000
gidNumber: 10000
homeDirectory: /home/admin
loginShell: /bin/bash
userPassword: {SSHA}hashedpassword

# User: ani (VPN + Mail)
dn: uid=ani,ou=People,dc=lksn2025,dc=id
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: ani
cn: Ani User
sn: User
mail: ani@lksn2025.id
uidNumber: 10001
gidNumber: 10001
homeDirectory: /home/ani
loginShell: /bin/bash
userPassword: {SSHA}hashedpassword

# User: budi
dn: uid=budi,ou=People,dc=lksn2025,dc=id
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: budi
cn: Budi User
sn: User
mail: budi@lksn2025.id
uidNumber: 10002
gidNumber: 10002
homeDirectory: /home/budi
loginShell: /bin/bash
userPassword: {SSHA}hashedpassword

# User: kyw1
dn: uid=kyw1,ou=People,dc=lksn2025,dc=id
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: kyw1
cn: KYW1 User
sn: User
mail: kyw1@lksn2025.id
uidNumber: 10003
gidNumber: 10003
homeDirectory: /home/kyw1
loginShell: /bin/bash
userPassword: {SSHA}hashedpassword
```

**Generate SSHA Password:**
```bash
slappasswd -h {SSHA} -s Skills39!
# Output: {SSHA}xxxxxxxxxxxxx
```

```bash
ldapadd -x -D cn=admin,dc=lksn2025,dc=id -W -f users.ldif
```

### 3. Create Groups: groups.ldif
```ldif
# VPN Group
dn: cn=vpnusers,ou=Groups,dc=lksn2025,dc=id
objectClass: groupOfNames
cn: vpnusers
member: uid=ani,ou=People,dc=lksn2025,dc=id

# Mail Group
dn: cn=mailusers,ou=Groups,dc=lksn2025,dc=id
objectClass: groupOfNames
cn: mailusers
member: uid=ani,ou=People,dc=lksn2025,dc=id
member: uid=budi,ou=People,dc=lksn2025,dc=id
member: uid=admin,ou=People,dc=lksn2025,dc=id
```

```bash
ldapadd -x -D cn=admin,dc=lksn2025,dc=id -W -f groups.ldif
```

## 🔐 Enable LDAPS (SSL/TLS)

### 1. Copy Certificates (from CA)
```bash
# Copy from int-srv CA
cp /etc/ssl/lksn-ca/certs/ca.crt /etc/ldap/ssl/
cp /etc/ssl/lksn-ca/certs/ldap.crt /etc/ldap/ssl/
cp /etc/ssl/lksn-ca/private/ldap.key /etc/ldap/ssl/

chown openldap:openldap /etc/ldap/ssl/*
chmod 600 /etc/ldap/ssl/ldap.key
```

### 2. Configure LDAPS: ldaps.ldif
```ldif
dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/ssl/ldap.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/ssl/ldap.key
-
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/ssl/ca.crt
```

```bash
ldapmodify -Y EXTERNAL -H ldapi:/// -f ldaps.ldif
```

### 3. Enable LDAPS in /etc/default/slapd
```bash
SLAPD_SERVICES="ldap://127.0.0.1:389/ ldaps:/// ldapi:///"
```

```bash
systemctl restart slapd
```

## ✅ Validation

### Test LDAP Connection
```bash
# Test plain LDAP
ldapsearch -x -H ldap://192.168.1.10 -b dc=lksn2025,dc=id

# Test LDAPS
ldapsearch -x -H ldaps://192.168.1.10 -b dc=lksn2025,dc=id

# Search specific user
ldapsearch -x -H ldap://192.168.1.10 -b dc=lksn2025,dc=id "(uid=ani)"

# Test authentication
ldapwhoami -x -H ldap://192.168.1.10 -D uid=ani,ou=People,dc=lksn2025,dc=id -W
```

### Validation Checklist

- [ ] **Service Status**
  - [ ] slapd service running
  - [ ] Listening on ports 389 (LDAP) and 636 (LDAPS)
  
- [ ] **Directory Structure**
  - [ ] Base DN created
  - [ ] All OUs exist (People, Groups, VPN, Mail)
  
- [ ] **Users**
  - [ ] admin, ani, budi, kyw1 created
  - [ ] Passwords set correctly (Skills39!)
  - [ ] Mail attributes present
  
- [ ] **Groups**
  - [ ] vpnusers group exists
  - [ ] mailusers group exists
  - [ ] Members correctly assigned
  
- [ ] **LDAPS**
  - [ ] Certificates configured
  - [ ] LDAPS port 636 listening
  - [ ] SSL/TLS connection works

## 🐛 Common Issues

### Issue 1: Can't bind as admin
**Symptom:** `ldap_bind: Invalid credentials`

**Fix:**
```bash
# Reset admin password
dpkg-reconfigure slapd
```

### Issue 2: LDAPS not working
**Symptom:** Connection refused on port 636

**Diagnosis:**
```bash
# Check if listening
netstat -tulpn | grep 636

# Check logs
journalctl -u slapd -f
```

**Fix:**
1. Verify certificates exist
2. Check SLAPD_SERVICES in /etc/default/slapd
3. Restart slapd

## 📚 References

- [OpenLDAP Admin Guide](https://www.openldap.org/doc/admin24/)
- [LDIF Format](https://ldap.com/ldif-the-ldap-data-interchange-format/)
