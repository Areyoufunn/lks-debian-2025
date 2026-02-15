# Requirements Extraction Template

> **Instruksi:** Untuk setiap PDF soal, extract requirement dan isi template ini. Saya akan merge semua requirement dari 8 source menjadi satu master requirement.

## Source Information

- **Source Name:** [Nama file PDF]
- **Year:** [Tahun soal]
- **Type:** [Provinsi/Nasional/Regional]
- **Difficulty:** [Easy/Medium/Hard]

---

## 1. Firewall & Routing (fw-srv)

### Network Configuration
- [ ] Interface WAN: 
- [ ] Interface INT: 
- [ ] Interface DMZ: 
- [ ] Interface MGMT: 
- [ ] IP Forwarding: 
- [ ] Routing tables: 

### Firewall Rules (nftables/iptables)
- [ ] Default policies:
- [ ] Zone-based filtering:
- [ ] Port forwarding rules:
- [ ] Specific rules:

### NAT Configuration
- [ ] SNAT/MASQUERADE:
- [ ] DNAT:
- [ ] Port forwarding:

### Additional Features
- [ ] QoS/Traffic shaping:
- [ ] Connection tracking:
- [ ] Rate limiting:
- [ ] Other:

---

## 2. DNS Server (int-srv - Bind9)

### Basic Configuration
- [ ] Domain name:
- [ ] Server IP:
- [ ] Forwarders:

### Forward Zones
- [ ] Primary zone:
- [ ] Secondary zones:

### Reverse Zones
- [ ] PTR records for:

### DNS Records
**A Records:**
- [ ] Record 1:
- [ ] Record 2:

**MX Records:**
- [ ] Mail server:

**CNAME Records:**
- [ ] Alias 1:
- [ ] Alias 2:

**Other Records (TXT, SRV, etc):**
- [ ] SPF:
- [ ] DKIM:
- [ ] DMARC:
- [ ] Other:

### Advanced Features
- [ ] DNSSEC:
- [ ] Dynamic DNS:
- [ ] Split-horizon DNS:
- [ ] Views:
- [ ] Other:

---

## 3. Certificate Authority (int-srv - OpenSSL)

### CA Structure
- [ ] Root CA:
- [ ] Intermediate CA:
- [ ] Certificate validity period:

### Certificates to Generate
- [ ] Mail server cert:
- [ ] Web server cert:
- [ ] VPN server cert:
- [ ] Other certs:

### Certificate Features
- [ ] Subject Alternative Names (SAN):
- [ ] Key size:
- [ ] Certificate Revocation List (CRL):
- [ ] OCSP:
- [ ] Other:

---

## 4. LDAP Directory (int-srv - slapd)

### Directory Structure
- [ ] Base DN:
- [ ] Organizational Units:

### User Management
- [ ] User accounts to create:
- [ ] Groups to create:
- [ ] Password policies:

### LDAP Features
- [ ] LDAPS (SSL/TLS):
- [ ] Access Control Lists (ACL):
- [ ] Replication:
- [ ] Referrals:
- [ ] Other:

### Integration
- [ ] Services using LDAP auth:
  - [ ] Mail server
  - [ ] Web server
  - [ ] VPN
  - [ ] Other:

---

## 5. Mail Server (mail-srv)

### Postfix (SMTP)
- [ ] Domain:
- [ ] Hostname:
- [ ] Virtual mailbox domains:
- [ ] SMTP authentication:
- [ ] TLS/SSL:
- [ ] Relay configuration:
- [ ] Mail aliases:

### Dovecot (IMAP/POP3)
- [ ] Protocols enabled:
- [ ] SSL/TLS:
- [ ] Authentication method:
- [ ] Mailbox format:
- [ ] Quota:

### Webmail (Roundcube/SquirrelMail)
- [ ] Webmail software:
- [ ] URL:
- [ ] Features:
- [ ] Plugins:

### Anti-Spam/Anti-Virus
- [ ] SpamAssassin:
- [ ] ClamAV:
- [ ] Amavis:
- [ ] Other:

### Email Security
- [ ] SPF records:
- [ ] DKIM signing:
- [ ] DMARC policy:
- [ ] Other:

### Virtual Users
- [ ] LDAP integration:
- [ ] Virtual mailbox users:
- [ ] Mail aliases:

---

## 6. Web Cluster (web-01 & web-02)

### High Availability (Keepalived)
- [ ] Virtual IP (VIP):
- [ ] Master server:
- [ ] Backup server:
- [ ] Priority values:
- [ ] VRRP authentication:
- [ ] Health check script:

### Load Balancer (HAProxy)
- [ ] Frontend configuration:
- [ ] Backend servers:
- [ ] Load balancing algorithm:
- [ ] Health checks:
- [ ] Session persistence:
- [ ] SSL termination:
- [ ] Statistics page:

### Web Server (Apache/Nginx)
- [ ] Web server software:
- [ ] Virtual hosts:
- [ ] Document root:
- [ ] SSL/TLS:
- [ ] Authentication:
  - [ ] Basic auth
  - [ ] LDAP auth
  - [ ] Other

### Web Applications
- [ ] Application 1:
- [ ] Application 2:
- [ ] Database backend:
- [ ] Other:

### Security
- [ ] ModSecurity/WAF:
- [ ] SSL/TLS configuration:
- [ ] Access restrictions:
- [ ] Other:

---

## 7. VPN Server (fw-srv - OpenVPN)

### Server Configuration
- [ ] Protocol:
- [ ] Port:
- [ ] VPN network:
- [ ] Server IP:
- [ ] Client IP range:

### Authentication
- [ ] Certificate-based:
- [ ] Username/password:
- [ ] Two-factor:

### Routing
- [ ] Routes pushed to clients:
- [ ] Access to zones:
  - [ ] INT zone
  - [ ] DMZ zone
  - [ ] Other

### Client Configuration
- [ ] Number of clients:
- [ ] Client config files:
- [ ] Other:

---

## 8. Additional Services

### DHCP Server
- [ ] Network:
- [ ] IP range:
- [ ] Gateway:
- [ ] DNS servers:
- [ ] Other options:

### NTP Server
- [ ] Upstream servers:
- [ ] Local clients:

### Monitoring
- [ ] Monitoring software:
- [ ] Metrics collected:
- [ ] Alerting:

### Backup
- [ ] Backup strategy:
- [ ] Backup location:
- [ ] Retention:

### Other Services
- [ ] Service 1:
- [ ] Service 2:

---

## 9. Security Requirements

### Firewall Rules
- [ ] Specific security rules:

### SELinux/AppArmor
- [ ] Enabled:
- [ ] Policies:

### Fail2ban
- [ ] Services protected:
- [ ] Ban time:
- [ ] Max retry:

### Other Security
- [ ] Requirement 1:
- [ ] Requirement 2:

---

## 10. Testing & Validation

### Functional Tests
- [ ] Test 1:
- [ ] Test 2:

### Integration Tests
- [ ] Test 1:
- [ ] Test 2:

### Performance Tests
- [ ] Test 1:
- [ ] Test 2:

---

## 11. Unique Features

> **Penting:** List semua requirement yang UNIK dari soal ini yang mungkin tidak ada di soal lain

1. 
2. 
3. 

---

## Notes

> Catatan tambahan atau hal-hal khusus dari soal ini:

