# SOAL KONFIGURASI - LKS 2025 DEBIAN SERVER INFRASTRUCTURE

**Waktu:** 8 Jam  
**Domain:** lksn2025.id  
**Kredensial:** Skills39!

---

## 📋 INFORMASI UMUM

### Topology Overview

Anda diminta untuk mengkonfigurasi infrastruktur server dengan 8 VM yang terhubung dalam 4 network zone:

- **WAN Zone** (vmbr0): 192.168.27.0/24 - Internet access
- **INT Zone** (INT): 192.168.1.0/24 - Internal services
- **DMZ Zone** (DMZ): 172.16.1.0/24 - Public-facing services
- **MGMT Zone** (MGMT): 10.0.0.0/24 - Management network

### Server List

| VM ID | Hostname  | Fungsi                          | Zones                    |
|-------|-----------|----------------------------------|--------------------------|
| 400   | fw-srv    | Firewall & Gateway              | WAN, INT, DMZ, MGMT      |
| 401   | int-srv   | DNS, LDAP, CA, Database         | INT, MGMT                |
| 402   | mail-srv  | Mail Server (Postfix, Dovecot)  | DMZ, MGMT                |
| 403   | web-01    | Web Cluster - MASTER            | DMZ, MGMT                |
| 404   | web-02    | Web Cluster - BACKUP            | DMZ, MGMT                |
| 405   | db-srv    | Database (Deprecated)           | DMZ, MGMT                |
| 406   | mon-srv   | Monitoring (Cacti, SNMP)        | DMZ, MGMT                |
| 407   | ani-clt   | Client                          | WAN, MGMT                |

### Kredensial

| Service      | Username | Password  |
|--------------|----------|-----------|
| LDAP Users   | admin, ani, budi | Skills39! |
| Database     | root     | Skills39! |
| Roundcube    | admin    | Skills39! |
| Cacti        | admin    | admin     |

---

## 🔥 MODUL 1: FIREWALL & GATEWAY (fw-srv)

**Server:** fw-srv (VMID 400)  
**Waktu:** 60 menit  
**Poin:** 100

### Task 1.1: Network Interface Configuration

Configure 4 network interfaces:

```bash
# /etc/network/interfaces

# WAN Interface (Internet)
auto ens18
iface ens18 inet static
    address 192.168.27.200
    netmask 255.255.255.0
    gateway 192.168.27.1
    dns-nameservers 8.8.8.8

# INT Interface (Internal Zone)
auto ens19
iface ens19 inet static
    address 192.168.1.254
    netmask 255.255.255.0

# DMZ Interface (DMZ Zone)
auto ens20
iface ens20 inet static
    address 172.16.1.254
    netmask 255.255.255.0

# MGMT Interface (Management)
auto ens21
iface ens21 inet static
    address 10.0.0.254
    netmask 255.255.255.0
```

**Verifikasi:**
```bash
ip addr show
ping -c 3 8.8.8.8
```

### Task 1.2: IP Forwarding

Enable IP forwarding untuk routing antar zone:

```bash
# /etc/sysctl.conf
net.ipv4.ip_forward=1

# Apply
sysctl -p
```

### Task 1.3: NFTables Firewall Rules

Configure firewall dengan nftables:

```bash
# /etc/nftables.conf

#!/usr/sbin/nft -f

flush ruleset

table ip filter {
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Allow established connections
        ct state established,related accept
        
        # Allow loopback
        iifname "lo" accept
        
        # Allow SSH from MGMT
        iifname "ens21" tcp dport 22 accept
        
        # Allow DNS
        tcp dport 53 accept
        udp dport 53 accept
        
        # Allow ICMP (ping)
        icmp type echo-request accept
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
        
        # Allow established connections
        ct state established,related accept
        
        # INT to WAN (Internet access)
        iifname "ens19" oifname "ens18" accept
        
        # DMZ to WAN (Internet access)
        iifname "ens20" oifname "ens18" accept
        
        # DMZ to INT (Mail to LDAP/DNS)
        iifname "ens20" oifname "ens19" ip daddr 192.168.1.10 tcp dport { 389, 636, 53 } accept
        
        # WAN to DMZ (Web, Mail)
        iifname "ens18" oifname "ens20" ip daddr 172.16.1.100 tcp dport { 80, 443 } accept
        iifname "ens18" oifname "ens20" ip daddr 172.16.1.10 tcp dport { 25, 587, 993 } accept
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        
        # Masquerade (NAT) for INT and DMZ to WAN
        oifname "ens18" masquerade
    }
    
    chain prerouting {
        type nat hook prerouting priority -100; policy accept;
        
        # Port forwarding HTTP/HTTPS to Web VIP
        iifname "ens18" tcp dport { 80, 443 } dnat to 172.16.1.100
        
        # Port forwarding SMTP/IMAP to Mail Server
        iifname "ens18" tcp dport { 25, 587, 993 } dnat to 172.16.1.10
    }
}
```

**Enable dan start:**
```bash
systemctl enable nftables
systemctl start nftables
nft list ruleset
```

**Verifikasi:**
- [ ] Firewall rules loaded
- [ ] NAT working (test dari INT/DMZ ke internet)
- [ ] Port forwarding working

---

## 🌐 MODUL 2: DNS SERVER (int-srv)

**Server:** int-srv (VMID 401)  
**Waktu:** 45 menit  
**Poin:** 80

### Task 2.1: Install Bind9

```bash
apt update
apt install bind9 bind9utils -y
```

### Task 2.2: Configure Named Options

```bash
# /etc/bind/named.conf.options

options {
    directory "/var/cache/bind";
    
    # Listen on INT interface
    listen-on { 192.168.1.10; 127.0.0.1; };
    
    # Allow queries from all zones
    allow-query { any; };
    
    # Forwarders
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    
    dnssec-validation auto;
    
    recursion yes;
    allow-recursion { 192.168.1.0/24; 172.16.1.0/24; 10.0.0.0/24; };
};
```

### Task 2.3: Configure Zones

```bash
# /etc/bind/named.conf.local

zone "lksn2025.id" {
    type master;
    file "/etc/bind/db.lksn2025.id";
};

zone "1.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168.1";
};

zone "1.16.172.in-addr.arpa" {
    type master;
    file "/etc/bind/db.172.16.1";
};
```

### Task 2.4: Create Forward Zone File

```bash
# /etc/bind/db.lksn2025.id

$TTL    604800
@       IN      SOA     ns1.lksn2025.id. admin.lksn2025.id. (
                        2026021601      ; Serial (YYYYMMDDNN)
                        604800          ; Refresh
                        86400           ; Retry
                        2419200         ; Expire
                        604800 )        ; Negative Cache TTL

; Name Servers
@       IN      NS      ns1.lksn2025.id.

; A Records
ns1             IN      A       192.168.1.10
int-srv         IN      A       192.168.1.10
fw-srv          IN      A       192.168.27.200
mail-srv        IN      A       172.16.1.10
web-01          IN      A       172.16.1.21
web-02          IN      A       172.16.1.22
db-srv          IN      A       172.16.1.30
mon-srv         IN      A       172.16.1.40
ani-clt         IN      A       192.168.27.100

; Service Records
mail            IN      A       172.16.1.10
www             IN      A       172.16.1.100
vip             IN      A       172.16.1.100
webmail         IN      A       172.16.1.10
phpmyadmin      IN      A       192.168.1.10
cacti           IN      A       172.16.1.40

; MX Record
@               IN      MX      10      mail.lksn2025.id.

; CNAME Records
roundcube       IN      CNAME   mail.lksn2025.id.
```

### Task 2.5: Create Reverse Zone Files

```bash
# /etc/bind/db.192.168.1

$TTL    604800
@       IN      SOA     ns1.lksn2025.id. admin.lksn2025.id. (
                        2026021601
                        604800
                        86400
                        2419200
                        604800 )

@       IN      NS      ns1.lksn2025.id.

10      IN      PTR     int-srv.lksn2025.id.
10      IN      PTR     ns1.lksn2025.id.
```

```bash
# /etc/bind/db.172.16.1

$TTL    604800
@       IN      SOA     ns1.lksn2025.id. admin.lksn2025.id. (
                        2026021601
                        604800
                        86400
                        2419200
                        604800 )

@       IN      NS      ns1.lksn2025.id.

10      IN      PTR     mail-srv.lksn2025.id.
21      IN      PTR     web-01.lksn2025.id.
22      IN      PTR     web-02.lksn2025.id.
30      IN      PTR     db-srv.lksn2025.id.
40      IN      PTR     mon-srv.lksn2025.id.
100     IN      PTR     vip.lksn2025.id.
```

### Task 2.6: Restart and Verify

```bash
# Check syntax
named-checkconf
named-checkzone lksn2025.id /etc/bind/db.lksn2025.id
named-checkzone 1.168.192.in-addr.arpa /etc/bind/db.192.168.1

# Restart
systemctl restart bind9
systemctl enable bind9

# Test
dig @localhost lksn2025.id
dig @localhost www.lksn2025.id
dig @localhost -x 192.168.1.10
nslookup mail.lksn2025.id localhost
```

**Verifikasi:**
- [ ] DNS service running
- [ ] Forward zone resolving
- [ ] Reverse zone resolving
- [ ] MX record correct

---

## 👥 MODUL 3: LDAP DIRECTORY (int-srv)

**Server:** int-srv (VMID 401)  
**Waktu:** 60 menit  
**Poin:** 100

### Task 3.1: Install OpenLDAP

```bash
apt install slapd ldap-utils -y

# Reconfigure
dpkg-reconfigure slapd
```

**Configuration:**
- Omit OpenLDAP server configuration? **No**
- DNS domain name: **lksn2025.id**
- Organization name: **LKSN 2025**
- Administrator password: **Skills39!**
- Database backend: **MDB**
- Remove database when purged? **No**
- Move old database? **Yes**

### Task 3.2: Create Base Structure

```bash
# base.ldif

dn: ou=People,dc=lksn2025,dc=id
objectClass: organizationalUnit
ou: People

dn: ou=Groups,dc=lksn2025,dc=id
objectClass: organizationalUnit
ou: Groups
```

```bash
ldapadd -x -D "cn=admin,dc=lksn2025,dc=id" -W -f base.ldif
```

### Task 3.3: Create Users

```bash
# users.ldif

dn: uid=admin,ou=People,dc=lksn2025,dc=id
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: admin
sn: Administrator
givenName: Admin
cn: Admin User
displayName: Admin User
uidNumber: 10000
gidNumber: 10000
userPassword: {SSHA}generated_hash
gecos: Admin User
loginShell: /bin/bash
homeDirectory: /home/admin
mail: admin@lksn2025.id

dn: uid=ani,ou=People,dc=lksn2025,dc=id
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: ani
sn: Ani
givenName: Ani
cn: Ani User
displayName: Ani User
uidNumber: 10001
gidNumber: 10001
userPassword: {SSHA}generated_hash
gecos: Ani User
loginShell: /bin/bash
homeDirectory: /home/ani
mail: ani@lksn2025.id

dn: uid=budi,ou=People,dc=lksn2025,dc=id
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: budi
sn: Budi
givenName: Budi
cn: Budi User
displayName: Budi User
uidNumber: 10002
gidNumber: 10002
userPassword: {SSHA}generated_hash
gecos: Budi User
loginShell: /bin/bash
homeDirectory: /home/budi
mail: budi@lksn2025.id
```

**Generate password hash:**
```bash
slappasswd -s Skills39!
# Copy output ke userPassword
```

```bash
ldapadd -x -D "cn=admin,dc=lksn2025,dc=id" -W -f users.ldif
```

### Task 3.4: Verify LDAP

```bash
# Search all users
ldapsearch -x -LLL -b "dc=lksn2025,dc=id" "(objectClass=posixAccount)"

# Search specific user
ldapsearch -x -LLL -b "dc=lksn2025,dc=id" "(uid=ani)"

# Test authentication
ldapwhoami -x -D "uid=ani,ou=People,dc=lksn2025,dc=id" -W
```

**Verifikasi:**
- [ ] LDAP service running
- [ ] Base structure created
- [ ] 3 users created (admin, ani, budi)
- [ ] Authentication working

---

## 🔐 MODUL 4: CERTIFICATE AUTHORITY (int-srv)

**Server:** int-srv (VMID 401)  
**Waktu:** 45 menit  
**Poin:** 80

### Task 4.1: Create Root CA

```bash
mkdir -p /root/ca/{private,certs,newcerts,crl}
cd /root/ca
touch index.txt
echo 1000 > serial
```

**OpenSSL Config:**
```bash
# /root/ca/openssl.cnf

[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = /root/ca
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand

private_key       = $dir/private/ca.key
certificate       = $dir/certs/ca.crt

default_md        = sha256
default_days      = 3650
preserve          = no
policy            = policy_loose

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256
x509_extensions     = v3_ca

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = lksn2025.id
DNS.2 = www.lksn2025.id
DNS.3 = mail.lksn2025.id
DNS.4 = webmail.lksn2025.id
DNS.5 = *.lksn2025.id
IP.1 = 172.16.1.100
IP.2 = 172.16.1.10
IP.3 = 192.168.1.10
```

**Generate Root CA:**
```bash
# Generate private key
openssl genrsa -out private/ca.key 4096

# Generate root certificate
openssl req -config openssl.cnf -key private/ca.key -new -x509 -days 3650 -sha256 -extensions v3_ca -out certs/ca.crt

# Fill in:
# Country: ID
# State: Jakarta
# Locality: Jakarta
# Organization: LKSN 2025
# OU: IT Department
# CN: LKSN 2025 Root CA
# Email: admin@lksn2025.id
```

### Task 4.2: Generate Web Server Certificate

```bash
# Generate private key
openssl genrsa -out private/web.key 2048

# Generate CSR
openssl req -config openssl.cnf -key private/web.key -new -sha256 -out certs/web.csr

# Fill in:
# CN: www.lksn2025.id
# (others same as CA)

# Sign certificate
openssl ca -config openssl.cnf -extensions server_cert -days 365 -notext -md sha256 -in certs/web.csr -out certs/web.crt
```

### Task 4.3: Generate Mail Server Certificate

```bash
# Generate private key
openssl genrsa -out private/mail.key 2048

# Generate CSR
openssl req -config openssl.cnf -key private/mail.key -new -sha256 -out certs/mail.csr

# CN: mail.lksn2025.id

# Sign
openssl ca -config openssl.cnf -extensions server_cert -days 365 -notext -md sha256 -in certs/mail.csr -out certs/mail.crt
```

### Task 4.4: Distribute CA Certificate

```bash
# Copy to system trust store
cp certs/ca.crt /usr/local/share/ca-certificates/lksn2025-ca.crt
update-ca-certificates

# Verify
openssl verify -CAfile certs/ca.crt certs/web.crt
openssl verify -CAfile certs/ca.crt certs/mail.crt
```

**Verifikasi:**
- [ ] Root CA created
- [ ] Web certificate signed
- [ ] Mail certificate signed
- [ ] CA trusted by system

---

**(Continued in next file due to length...)**

**Remaining modules:**
- MODUL 5: WEB CLUSTER (Keepalived + HAProxy + Nginx)
- MODUL 6: MAIL SERVER (Postfix + Dovecot + Roundcube)
- MODUL 7: DATABASE (MariaDB + phpMyAdmin)
- MODUL 8: MONITORING (Cacti + SNMP)

Would you like me to continue with the remaining modules?
