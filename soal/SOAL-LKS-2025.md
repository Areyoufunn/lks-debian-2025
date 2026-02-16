# SOAL LKS 2025 - DEBIAN SERVER INFRASTRUCTURE

**Waktu Pengerjaan:** 8 Jam  
**Total Poin:** 1000  
**Passing Grade:** 700

---

## 📋 INFORMASI UMUM

### Topology Network

Anda diminta mengkonfigurasi infrastruktur server dengan 8 VM yang terhubung dalam 4 network zone berbeda.

### Tabel IP Address

| Hostname  | WAN (vmbr0)     | INT (192.168.1.0/24) | DMZ (172.16.1.0/24) | MGMT (10.0.0.0/24) |
|-----------|-----------------|----------------------|---------------------|--------------------|
| fw-srv    | 192.168.27.200  | 192.168.1.254        | 172.16.1.254        | 10.0.0.254         |
| int-srv   | -               | 192.168.1.10         | -                   | 10.0.0.10          |
| mail-srv  | -               | -                    | 172.16.1.10         | 10.0.0.20          |
| web-01    | -               | -                    | 172.16.1.21         | 10.0.0.21          |
| web-02    | -               | -                    | 172.16.1.22         | 10.0.0.22          |
| db-srv    | -               | -                    | 172.16.1.30         | 10.0.0.30          |
| mon-srv   | -               | -                    | 172.16.1.40         | 10.0.0.40          |
| ani-clt   | 192.168.27.100  | -                    | -                   | 10.0.0.100         |

**Virtual IP (VIP):** 172.16.1.100 (Web Cluster)

### Domain dan Kredensial

- **Domain:** lksn2025.id
- **Password Default:** Skills39!
- **Database User:** root / Skills39!
- **LDAP Admin:** cn=admin,dc=lksn2025,dc=id / Skills39!

---

## 🔥 SERVER 1: FIREWALL & GATEWAY (fw-srv)

**IP:** WAN 192.168.27.200, INT 192.168.1.254, DMZ 172.16.1.254, MGMT 10.0.0.254  
**Poin:** 150

### 1.1 Network Configuration (30 poin)

Configure 4 network interfaces sesuai tabel IP di atas. Interface WAN harus mendapat akses internet dengan gateway 192.168.27.1 dan DNS 8.8.8.8.

**Verifikasi:**
- Semua interface memiliki IP yang benar
- Dapat ping ke internet dari fw-srv
- Dapat ping ke semua zone (INT, DMZ, MGMT)

### 1.2 IP Forwarding (20 poin)

Enable IP forwarding agar server dapat berfungsi sebagai router antar zone.

**Verifikasi:**
- IP forwarding enabled dan persistent setelah reboot

### 1.3 Firewall Rules dengan NFTables (100 poin)

Configure firewall dengan ketentuan:

**INPUT Chain:**
- Default policy: DROP
- Allow established/related connections
- Allow loopback
- Allow SSH hanya dari MGMT zone
- Allow DNS queries (port 53 TCP/UDP)
- Allow ICMP ping

**FORWARD Chain:**
- Default policy: DROP
- Allow established/related connections
- Allow INT zone ke WAN (internet access)
- Allow DMZ zone ke WAN (internet access)
- Allow DMZ ke INT untuk akses LDAP (port 389, 636) dan DNS (port 53)
- Allow WAN ke DMZ untuk akses Web VIP (port 80, 443)
- Allow WAN ke DMZ untuk akses Mail (port 25, 587, 993)

**NAT Configuration:**
- Masquerade (SNAT) untuk INT dan DMZ ke WAN
- Port forwarding (DNAT) HTTP/HTTPS dari WAN ke 172.16.1.100
- Port forwarding SMTP/Submission/IMAPS dari WAN ke 172.16.1.10

**Verifikasi:**
- Firewall rules loaded dan persistent
- NAT working (test dari INT/DMZ ke internet)
- Port forwarding working (test dari WAN ke services)
- Zone isolation enforced (DMZ tidak bisa akses INT kecuali LDAP/DNS)

---

## 🌐 SERVER 2: INTERNAL SERVICES (int-srv)

**IP:** INT 192.168.1.10, MGMT 10.0.0.10  
**Poin:** 300

### 2.1 DNS Server - Bind9 (100 poin)

Configure DNS server dengan ketentuan:

**Zone Configuration:**
- Primary domain: lksn2025.id
- Reverse zone untuk 192.168.1.0/24
- Reverse zone untuk 172.16.1.0/24
- DNS server listen pada 192.168.1.10
- Allow queries dari semua zone
- Forwarder ke 8.8.8.8 dan 8.8.4.4

**DNS Records yang harus dibuat:**

| Record Type | Name       | Value           |
|-------------|------------|-----------------|
| NS          | @          | ns1.lksn2025.id |
| A           | ns1        | 192.168.1.10    |
| A           | fw-srv     | 192.168.27.200  |
| A           | int-srv    | 192.168.1.10    |
| A           | mail-srv   | 172.16.1.10     |
| A           | web-01     | 172.16.1.21     |
| A           | web-02     | 172.16.1.22     |
| A           | mon-srv    | 172.16.1.40     |
| A           | www        | 172.16.1.100    |
| A           | vip        | 172.16.1.100    |
| A           | mail       | 172.16.1.10     |
| A           | webmail    | 172.16.1.10     |
| A           | phpmyadmin | 192.168.1.10    |
| A           | cacti      | 172.16.1.40     |
| MX          | @          | 10 mail.lksn2025.id |
| CNAME       | roundcube  | mail.lksn2025.id |

**Verifikasi:**
- DNS service running dan enabled
- Forward zone resolving untuk semua records
- Reverse zone resolving
- MX record correct
- Dapat query dari client di semua zone

### 2.2 LDAP Directory - OpenLDAP (100 poin)

Configure LDAP directory service dengan ketentuan:

**Base Configuration:**
- Base DN: dc=lksn2025,dc=id
- Organization: LKSN 2025
- Admin DN: cn=admin,dc=lksn2025,dc=id
- Admin Password: Skills39!

**Directory Structure:**
- Organizational Unit: ou=People,dc=lksn2025,dc=id
- Organizational Unit: ou=Groups,dc=lksn2025,dc=id

**Users yang harus dibuat:**

| UID   | Full Name  | Email              | UID Number | GID Number |
|-------|------------|--------------------|------------|------------|
| admin | Admin User | admin@lksn2025.id  | 10000      | 10000      |
| ani   | Ani User   | ani@lksn2025.id    | 10001      | 10001      |
| budi  | Budi User  | budi@lksn2025.id   | 10002      | 10002      |

Semua user menggunakan password: Skills39!

**User Attributes Required:**
- objectClass: inetOrgPerson, posixAccount, shadowAccount
- uid, sn, givenName, cn, displayName
- uidNumber, gidNumber, homeDirectory, loginShell
- userPassword (hashed dengan SSHA)
- mail

**Verifikasi:**
- LDAP service running
- Base structure created
- 3 users created dengan attributes lengkap
- Dapat search users
- Dapat authenticate dengan ldapwhoami

### 2.3 Certificate Authority (50 poin)

Setup Certificate Authority dengan ketentuan:

**Root CA:**
- Key size: 4096 bit
- Validity: 10 years
- Common Name: LKSN 2025 Root CA
- Organization: LKSN 2025
- Country: ID

**Server Certificates yang harus dibuat:**
1. Web Server Certificate
   - CN: www.lksn2025.id
   - SAN: lksn2025.id, www.lksn2025.id, *.lksn2025.id, 172.16.1.100
   - Validity: 1 year

2. Mail Server Certificate
   - CN: mail.lksn2025.id
   - SAN: mail.lksn2025.id, webmail.lksn2025.id, 172.16.1.10
   - Validity: 1 year

**Verifikasi:**
- Root CA certificate created
- Server certificates signed by Root CA
- Certificates valid dan dapat diverify
- Root CA trusted oleh system (update-ca-certificates)

### 2.4 Database Server - MariaDB (50 poin)

Configure database server dengan ketentuan:

**Server Configuration:**
- Listen pada semua interfaces (0.0.0.0)
- Root password: Skills39!
- Remove anonymous users
- Remove test database

**Databases yang harus dibuat:**
1. itnsa (untuk aplikasi umum)
2. roundcube (untuk webmail)
3. cacti (untuk monitoring)

**Database Users:**
- root@'%' dengan password Skills39! (full privileges)
- itnsa@'%' dengan password Skills39! (full privileges pada database itnsa)
- roundcube@'172.16.1.%' dengan password Skills39! (full privileges pada database roundcube)
- cacti@'172.16.1.%' dengan password Skills39! (full privileges pada database cacti)

**Sample Data:**
Pada database itnsa, buat table users dengan struktur:
- id (INT, AUTO_INCREMENT, PRIMARY KEY)
- nama (VARCHAR 100, NOT NULL)
- alamat (VARCHAR 255, NOT NULL)
- created_at (TIMESTAMP, DEFAULT CURRENT_TIMESTAMP)

Insert minimal 3 sample data.

**phpMyAdmin:**
Install dan configure phpMyAdmin accessible via https://phpmyadmin.lksn2025.id dengan SSL certificate.

**Verifikasi:**
- MariaDB running dan enabled
- Remote access working dari DMZ zone
- Semua databases created
- Users created dengan privileges correct
- Sample table dengan data
- phpMyAdmin accessible via HTTPS

---

## 📧 SERVER 3: MAIL SERVER (mail-srv)

**IP:** DMZ 172.16.1.10, MGMT 10.0.0.20  
**Poin:** 200

### 3.1 SMTP Server - Postfix (70 poin)

Configure SMTP server dengan ketentuan:

**Basic Configuration:**
- Hostname: mail.lksn2025.id
- Domain: lksn2025.id
- Listen pada semua interfaces
- Accept mail untuk domain lksn2025.id

**TLS Configuration:**
- TLS certificate dari CA (mail.crt, mail.key)
- Enforce TLS untuk SMTP (smtpd_tls_security_level = may)
- TLS required untuk authentication

**LDAP Integration:**
- Virtual mailbox lookup dari LDAP
- Search base: ou=People,dc=lksn2025,dc=id
- LDAP server: 192.168.1.10
- Query filter untuk mail attribute

**SASL Authentication:**
- Use Dovecot SASL
- Enable SASL authentication

**Submission Port:**
- Enable port 587 untuk authenticated submission
- Require TLS encryption
- Require SASL authentication

**Verifikasi:**
- Postfix running dan enabled
- Port 25 (SMTP) listening
- Port 587 (Submission) listening
- TLS working
- LDAP lookup working
- Can send mail

### 3.2 IMAP Server - Dovecot (70 poin)

Configure IMAP server dengan ketentuan:

**Protocol Configuration:**
- Enable IMAP dan LMTP protocols
- Disable POP3
- Mail location: maildir:~/Maildir

**TLS Configuration:**
- TLS certificate dari CA (mail.crt, mail.key)
- Require TLS (ssl = required)
- Minimum TLS version: 1.2
- Disable plain IMAP (port 143)
- Enable IMAPS only (port 993)

**LDAP Authentication:**
- Disable system authentication
- Enable LDAP authentication
- LDAP server: 192.168.1.10
- Base DN: ou=People,dc=lksn2025,dc=id
- User filter: (uid=%n)
- Password scheme: SSHA

**LMTP Integration:**
- Configure LMTP socket untuk Postfix
- Configure auth socket untuk Postfix SASL

**Verifikasi:**
- Dovecot running dan enabled
- Port 993 (IMAPS) listening
- Port 143 (IMAP) disabled
- TLS enforced
- LDAP authentication working
- LMTP working dengan Postfix

### 3.3 Webmail - Roundcube (60 poin)

Install dan configure Roundcube webmail dengan ketentuan:

**Database Configuration:**
- Database: roundcube pada int-srv (192.168.1.10)
- Database user: roundcube / Skills39!
- Import database schema

**Mail Server Configuration:**
- IMAP server: ssl://localhost:993
- SMTP server: tls://localhost:587
- Use user credentials untuk SMTP authentication

**Web Configuration:**
- Accessible via https://webmail.lksn2025.id
- Use SSL certificate dari CA
- Product name: LKSN 2025 Webmail

**Verifikasi:**
- Roundcube accessible via HTTPS
- Database connection working
- Can login dengan LDAP users
- Can send and receive emails
- SSL certificate valid

---

## 🌍 SERVER 4 & 5: WEB CLUSTER (web-01, web-02)

**IP:** web-01: 172.16.1.21, web-02: 172.16.1.22  
**VIP:** 172.16.1.100  
**Poin:** 200

### 4.1 High Availability - Keepalived (50 poin)

Configure Keepalived untuk Virtual IP dengan ketentuan:

**Configuration:**
- Virtual IP: 172.16.1.100/24
- Virtual Router ID: 51
- Authentication: PASS dengan password Skills39!
- web-01: MASTER dengan priority 110
- web-02: BACKUP dengan priority 100
- Advertisement interval: 1 second

**Verifikasi:**
- Keepalived running pada kedua server
- VIP active pada MASTER (web-01)
- VIP dapat di-ping
- Failover working (stop keepalived di MASTER, VIP pindah ke BACKUP)
- Failback working (start keepalived di MASTER, VIP kembali)

### 4.2 Load Balancer - HAProxy (70 poin)

Configure HAProxy pada kedua server dengan ketentuan:

**Frontend HTTP:**
- Listen pada port 80
- Redirect semua traffic ke HTTPS (301)

**Frontend HTTPS:**
- Listen pada port 443
- SSL certificate dari CA (web.crt, web.key)
- Add custom header: Via-Proxy dengan value hostname
- Backend: web_servers

**Backend Configuration:**
- Balance algorithm: roundrobin
- Health check: HTTP GET /
- Expected status: 200
- Backend servers:
  - web-01: 172.16.1.21:8080
  - web-02: 172.16.1.22:8080

**Stats Page:**
- Listen pada port 8404
- URI: /stats
- Authentication: admin / Skills39!
- Refresh: 30 seconds

**Verifikasi:**
- HAProxy running pada kedua server
- HTTP redirect ke HTTPS working
- HTTPS working dengan valid certificate
- Custom header Via-Proxy present
- Load balancing working (traffic distributed)
- Health checks working
- Stats page accessible

### 4.3 Web Server - Nginx (80 poin)

Configure Nginx pada kedua server dengan ketentuan:

**Basic Configuration:**
- Listen pada port 8080 (backend untuk HAProxy)
- Document root: /var/www/html
- Index file: index.html

**Content:**
- web-01: Tampilkan "Hello from web-01"
- web-02: Tampilkan "Hello from web-02"

**Protected Directory:**
- Path: /data/file/
- Require HTTP Basic Authentication
- Username: rahasia
- Password: Skills39
- Enable directory listing (autoindex)

**Verifikasi:**
- Nginx running pada kedua server
- Port 8080 listening
- Content berbeda di setiap server
- Protected directory require authentication
- Directory listing enabled di /data/file/

---

## 💾 SERVER 6: DATABASE (db-srv)

**IP:** DMZ 172.16.1.30, MGMT 10.0.0.30  
**Poin:** 50

**NOTE:** Server ini deprecated. Database sudah dipindah ke int-srv. Server ini hanya perlu dikonfigurasi network interface dan dapat di-ping.

**Verifikasi:**
- Network interfaces configured
- Dapat ping dari semua zone

---

## 📊 SERVER 7: MONITORING (mon-srv)

**IP:** DMZ 172.16.1.40, MGMT 10.0.0.40  
**Poin:** 100

### 7.1 SNMP Configuration pada Semua Server (30 poin)

Install dan configure SNMP daemon pada semua server (fw-srv, int-srv, mail-srv, web-01, web-02, mon-srv) dengan ketentuan:

**Configuration:**
- Listen pada UDP port 161
- Community string: lks-itnsa
- Access: read-only
- System location: LKS 2025 Data Center
- System contact: admin@lksn2025.id

**Verifikasi:**
- SNMP daemon running pada semua server
- Dapat query dari mon-srv menggunakan snmpwalk
- System information accessible

### 7.2 Monitoring System - Cacti (70 poin)

Install dan configure Cacti dengan ketentuan:

**Database Configuration:**
- Database: cacti pada int-srv (192.168.1.10)
- Database user: cacti / Skills39!
- Import Cacti database schema

**Web Configuration:**
- Accessible via http://cacti.lksn2025.id
- Alternative hostname: http://netmon.lksn2025.id
- Admin user: admin / admin

**Devices to Monitor:**
Tambahkan semua server sebagai devices:
- fw-srv (192.168.27.200)
- int-srv (192.168.1.10)
- mail-srv (172.16.1.10)
- web-01 (172.16.1.21)
- web-02 (172.16.1.22)
- mon-srv (172.16.1.40)

**Device Configuration:**
- SNMP Version: Version 2
- SNMP Community: lks-itnsa
- Device Template: Generic SNMP Device

**Graphs:**
- Create graphs untuk setiap device
- Minimal: Traffic, CPU, Memory, Disk usage

**Verifikasi:**
- Cacti web interface accessible
- Database connection working
- All devices added dan status UP
- Graphs generating data
- Poller running successfully

---

## 🖥️ SERVER 8: CLIENT (ani-clt)

**IP:** WAN 192.168.27.100, MGMT 10.0.0.100  
**Poin:** 0 (Testing purpose only)

Configure client untuk testing dengan ketentuan:

**Network Configuration:**
- WAN interface: 192.168.27.100
- Gateway: 192.168.27.200 (fw-srv)
- DNS: 192.168.1.10 (int-srv)

**Testing Tools:**
Install tools untuk testing:
- curl, wget
- dig, nslookup
- telnet, nc
- mail client

**Verifikasi:**
- Dapat akses internet
- DNS resolving working
- Dapat akses semua services via domain name

---

## ✅ CHECKLIST VERIFIKASI

### Network & Connectivity
- [ ] Semua server memiliki IP sesuai tabel
- [ ] Semua server dapat ping gateway
- [ ] Semua server dapat akses internet (kecuali yang isolated)
- [ ] Inter-zone communication sesuai firewall rules

### DNS
- [ ] Forward zone resolving semua records
- [ ] Reverse zone resolving
- [ ] MX record working
- [ ] Dapat query dari semua zone

### LDAP
- [ ] Service running dan enabled
- [ ] 3 users created dengan attributes lengkap
- [ ] Authentication working (ldapwhoami)
- [ ] Dapat search users

### Certificate Authority
- [ ] Root CA created dan valid
- [ ] Web certificate signed dan valid
- [ ] Mail certificate signed dan valid
- [ ] CA trusted oleh semua server

### Firewall
- [ ] NFTables rules loaded
- [ ] NAT working (INT/DMZ ke internet)
- [ ] Port forwarding working (WAN ke services)
- [ ] Zone isolation enforced
- [ ] Rules persistent setelah reboot

### Web Cluster
- [ ] VIP active pada MASTER
- [ ] Keepalived failover working
- [ ] HAProxy load balancing working
- [ ] HTTPS dengan valid certificate
- [ ] Custom header present
- [ ] Nginx serving content
- [ ] Protected directory require auth

### Mail Server
- [ ] Postfix accepting mail (port 25)
- [ ] Submission port working (port 587)
- [ ] Dovecot IMAPS working (port 993)
- [ ] LDAP authentication working
- [ ] TLS enforced
- [ ] Roundcube accessible via HTTPS
- [ ] Can send/receive email

### Database
- [ ] MariaDB running
- [ ] Remote access working
- [ ] Databases created (itnsa, roundcube, cacti)
- [ ] Users created dengan privileges correct
- [ ] Sample data inserted
- [ ] phpMyAdmin accessible via HTTPS

### Monitoring
- [ ] SNMP running pada semua server
- [ ] SNMP queries working
- [ ] Cacti web interface accessible
- [ ] All devices added dan UP
- [ ] Graphs generating data

---

## 📊 POIN BREAKDOWN

| Module                  | Poin |
|-------------------------|------|
| Firewall & Gateway      | 150  |
| DNS Server              | 100  |
| LDAP Directory          | 100  |
| Certificate Authority   | 50   |
| Database Server         | 50   |
| Mail Server (Postfix)   | 70   |
| Mail Server (Dovecot)   | 70   |
| Webmail (Roundcube)     | 60   |
| Web HA (Keepalived)     | 50   |
| Load Balancer (HAProxy) | 70   |
| Web Server (Nginx)      | 80   |
| SNMP Configuration      | 30   |
| Monitoring (Cacti)      | 70   |
| **TOTAL**               | **1000** |

**Passing Grade:** 700/1000 (70%)

---

## 📝 CATATAN PENTING

1. **Semua service harus persistent** - Tetap berjalan setelah reboot
2. **Gunakan systemctl** untuk enable service
3. **Test dari client** untuk memastikan accessibility
4. **Dokumentasikan** setiap perubahan konfigurasi
5. **Backup konfigurasi** sebelum melakukan perubahan
6. **Perhatikan firewall rules** - Service tidak akan accessible jika port diblock
7. **Certificate validity** - Pastikan certificate tidak expired dan trusted
8. **LDAP integration** - Mail server harus bisa authenticate via LDAP
9. **High availability** - Web cluster harus tetap accessible saat salah satu server down
10. **Monitoring** - Semua server harus ter-monitor di Cacti

---

**SELAMAT MENGERJAKAN!** 🚀
