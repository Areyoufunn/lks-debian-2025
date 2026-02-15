# Service 02: DNS Server (int-srv)

> **VM:** int-srv  
> **FQDN:** int-srv.lksn2025.id  
> **Role:** DNS Server (Bind9)  
> **IP:** 192.168.1.10/24 (INT Zone)

## 📋 Overview

DNS Server menyediakan name resolution untuk seluruh topologi. Semua service memerlukan DNS untuk resolve FQDN.

## 🔧 Service: Bind9

### Installation
```bash
apt update
apt install -y bind9 bind9utils bind9-doc dnsutils
```

## 📍 Configuration Files

### /etc/bind/named.conf.options
```bind
options {
    directory "/var/cache/bind";
    
    // Listen on INT interface
    listen-on { 192.168.1.10; 127.0.0.1; };
    listen-on-v6 { none; };
    
    // Allow queries from internal networks
    allow-query { 
        localhost;
        192.168.1.0/24;    // INT zone
        172.16.1.0/24;     // DMZ zone
        10.0.0.0/24;       // MGMT zone
        10.10.0.0/24;      // VPN zone
    };
    
    // Forwarders (untuk external DNS)
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    
    // DNSSEC validation
    dnssec-validation auto;
    
    // Recursion
    recursion yes;
    allow-recursion { 
        localhost;
        192.168.1.0/24;
        172.16.1.0/24;
        10.0.0.0/24;
        10.10.0.0/24;
    };
};
```

**Penjelasan:**
- `listen-on` - Bind hanya listen di INT interface (192.168.1.10)
- `allow-query` - Hanya network internal yang bisa query
- `forwarders` - Untuk resolve external domains (google.com, dll)
- `recursion yes` - DNS server akan resolve secara rekursif

### /etc/bind/named.conf.local
```bind
// Forward Zone
zone "lksn2025.id" {
    type master;
    file "/etc/bind/zones/db.lksn2025.id";
    allow-transfer { none; };  // Atau IP slave DNS jika ada
};

// Reverse Zones
zone "27.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.192.168.27";
};

zone "1.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.192.168.1";
};

zone "1.16.172.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.172.16.1";
};

zone "0.0.10.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.10.0.0";
};
```

## 📝 Zone Files

### Forward Zone: /etc/bind/zones/db.lksn2025.id
```bind
$TTL    604800
@       IN      SOA     int-srv.lksn2025.id. admin.lksn2025.id. (
                              2026021501    ; Serial (YYYYMMDDNN)
                              604800        ; Refresh
                              86400         ; Retry
                              2419200       ; Expire
                              604800 )      ; Negative Cache TTL

; Name Servers
@       IN      NS      int-srv.lksn2025.id.

; A Records - Infrastructure
fw              IN      A       192.168.27.200
int-srv         IN      A       192.168.1.10
mail-srv        IN      A       172.16.1.10
db              IN      A       172.16.1.17
netmon          IN      A       172.16.1.15
web-01          IN      A       172.16.1.21
web-02          IN      A       172.16.1.22

; A Records - Services
www             IN      A       192.168.27.200  ; NAT to VIP
vip             IN      A       172.16.1.100    ; Keepalived VIP
mail            IN      A       172.16.1.10
vpn             IN      A       192.168.27.200
phpmyadmin      IN      A       172.16.1.17

; MX Records
@               IN      MX      10 mail-srv.lksn2025.id.

; CNAME Records
webmail         IN      CNAME   mail-srv
cacti           IN      CNAME   netmon
ns1             IN      CNAME   int-srv

; Mass Virtual Hosts (Jombang requirement)
$GENERATE 1-20 www$ IN A 172.16.1.21
```

**Penjelasan:**
- `SOA` - Start of Authority, info tentang zone
- `Serial` - Increment setiap kali edit zone (format: YYYYMMDDNN)
- `NS` - Name server untuk zone ini
- `A` - Address record (hostname → IP)
- `MX` - Mail exchanger (priority 10)
- `CNAME` - Alias (webmail → mail-srv)
- `$GENERATE` - Generate www1-www20 otomatis

### Reverse Zone: /etc/bind/zones/db.192.168.27
```bind
$TTL    604800
@       IN      SOA     int-srv.lksn2025.id. admin.lksn2025.id. (
                              2026021501
                              604800
                              86400
                              2419200
                              604800 )

@       IN      NS      int-srv.lksn2025.id.

; PTR Records
200     IN      PTR     fw.lksn2025.id.
100     IN      PTR     ani-clt.lksn2025.id.
```

### Reverse Zone: /etc/bind/zones/db.192.168.1
```bind
$TTL    604800
@       IN      SOA     int-srv.lksn2025.id. admin.lksn2025.id. (
                              2026021501
                              604800
                              86400
                              2419200
                              604800 )

@       IN      NS      int-srv.lksn2025.id.

; PTR Records
10      IN      PTR     int-srv.lksn2025.id.
254     IN      PTR     fw.lksn2025.id.
```

### Reverse Zone: /etc/bind/zones/db.172.16.1
```bind
$TTL    604800
@       IN      SOA     int-srv.lksn2025.id. admin.lksn2025.id. (
                              2026021501
                              604800
                              86400
                              2419200
                              604800 )

@       IN      NS      int-srv.lksn2025.id.

; PTR Records
10      IN      PTR     mail-srv.lksn2025.id.
15      IN      PTR     netmon.lksn2025.id.
17      IN      PTR     db.lksn2025.id.
21      IN      PTR     web-01.lksn2025.id.
22      IN      PTR     web-02.lksn2025.id.
100     IN      PTR     vip.lksn2025.id.
254     IN      PTR     fw.lksn2025.id.
```

### Reverse Zone: /etc/bind/zones/db.10.0.0
```bind
$TTL    604800
@       IN      SOA     int-srv.lksn2025.id. admin.lksn2025.id. (
                              2026021501
                              604800
                              86400
                              2419200
                              604800 )

@       IN      NS      int-srv.lksn2025.id.

; PTR Records - Management Network
10      IN      PTR     int-srv.lksn2025.id.
11      IN      PTR     fw.lksn2025.id.
12      IN      PTR     mail-srv.lksn2025.id.
13      IN      PTR     web-01.lksn2025.id.
14      IN      PTR     web-02.lksn2025.id.
15      IN      PTR     ani-clt.lksn2025.id.
16      IN      PTR     db.lksn2025.id.
17      IN      PTR     netmon.lksn2025.id.
```

## 🔧 Setup Commands

```bash
# Create zones directory
mkdir -p /etc/bind/zones

# Create zone files (copy content di atas)
nano /etc/bind/zones/db.lksn2025.id
nano /etc/bind/zones/db.192.168.27
nano /etc/bind/zones/db.192.168.1
nano /etc/bind/zones/db.172.16.1
nano /etc/bind/zones/db.10.0.0

# Set permissions
chown -R bind:bind /etc/bind/zones
chmod 644 /etc/bind/zones/*

# Check configuration
named-checkconf
named-checkzone lksn2025.id /etc/bind/zones/db.lksn2025.id
named-checkzone 27.168.192.in-addr.arpa /etc/bind/zones/db.192.168.27

# Restart service
systemctl restart bind9
systemctl enable bind9
```

## ✅ Validation

### Test DNS Resolution
```bash
# Test forward lookup
dig @192.168.1.10 www.lksn2025.id
dig @192.168.1.10 mail-srv.lksn2025.id

# Test reverse lookup
dig @192.168.1.10 -x 172.16.1.10

# Test MX record
dig @192.168.1.10 lksn2025.id MX

# Test CNAME
dig @192.168.1.10 webmail.lksn2025.id

# Test from client
# (Set DNS di client ke 192.168.1.10)
nslookup www.lksn2025.id
ping mail-srv.lksn2025.id
```

### Validation Checklist

- [ ] **Service Status**
  - [ ] bind9 service running
  - [ ] Listening on 192.168.1.10:53
  
- [ ] **Configuration**
  - [ ] named-checkconf passes
  - [ ] All zone files valid (named-checkzone)
  - [ ] Serial numbers correct
  
- [ ] **Forward Resolution**
  - [ ] All A records resolve correctly
  - [ ] MX record returns mail-srv
  - [ ] CNAME records work
  - [ ] Mass virtual hosts (www1-www20) resolve
  
- [ ] **Reverse Resolution**
  - [ ] PTR records for all IPs
  - [ ] Reverse lookup matches forward
  
- [ ] **External Resolution**
  - [ ] Can resolve google.com (forwarders work)
  - [ ] Recursion working

## 🐛 Common Issues

### Issue 1: Zone file syntax error
**Symptom:** `named-checkzone` fails

**Fix:**
```bash
# Check syntax
named-checkzone lksn2025.id /etc/bind/zones/db.lksn2025.id

# Common errors:
# - Missing dot (.) at end of FQDN
# - Wrong serial number format
# - Missing semicolon
```

### Issue 2: DNS not resolving
**Symptom:** `dig` returns SERVFAIL

**Diagnosis:**
```bash
# Check if bind9 running
systemctl status bind9

# Check logs
journalctl -u bind9 -f

# Check if listening
netstat -tulpn | grep :53
```

**Fix:**
1. Restart bind9
2. Check firewall allows port 53
3. Verify zone files loaded

### Issue 3: Serial number not incrementing
**Symptom:** Slave DNS tidak update

**Fix:**
- Increment serial number di SOA record
- Format: YYYYMMDDNN (NN = revision number hari ini)
- Reload: `rndc reload`

## 📚 References

- [Bind9 Documentation](https://bind9.readthedocs.io/)
- [DNS Zone File Format](https://en.wikipedia.org/wiki/Zone_file)
- [RNDC Commands](https://bind9.readthedocs.io/en/latest/manpages.html#rndc)
