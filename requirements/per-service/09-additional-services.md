# Service 09-11: Additional Services (int-srv)

> **VM:** int-srv  
> **Services:** DHCP Server, FTP Server, Local Repository

## 📋 Service 09: DHCP Server

### Installation
```bash
apt update
apt install -y isc-dhcp-server
```

### /etc/dhcp/dhcpd.conf
```conf
# Global settings
option domain-name "lksn2025.id";
option domain-name-servers 192.168.1.10;
default-lease-time 600;
max-lease-time 7200;
authoritative;

# Subnet declaration (example for client network)
subnet 192.168.10.0 netmask 255.255.255.0 {
    range 192.168.10.100 192.168.10.200;
    option routers 192.168.10.1;
    option domain-name-servers 192.168.1.10;
    option broadcast-address 192.168.10.255;
    
    # Static reservation
    host linsrv2 {
        hardware ethernet 00:11:22:33:44:55;
        fixed-address 192.168.10.12;
    }
}
```

### /etc/default/isc-dhcp-server
```bash
INTERFACESv4="ens18"
```

```bash
systemctl restart isc-dhcp-server
systemctl enable isc-dhcp-server
```

### Validation
```bash
# Check service
systemctl status isc-dhcp-server

# Check leases
cat /var/lib/dhcp/dhcpd.leases

# Test from client
# Set client to DHCP, should get IP in range 192.168.10.100-200
```

---

## 📋 Service 10: FTP Server (ProFTPD)

### Installation
```bash
apt update
apt install -y proftpd
# Select: standalone
```

### /etc/proftpd/proftpd.conf
```conf
ServerName "LKSN2025 FTP Server"
ServerType standalone
DefaultServer on
Port 21

# Chroot users to home directory
DefaultRoot ~

# TLS Configuration
<IfModule mod_tls.c>
    TLSEngine on
    TLSLog /var/log/proftpd/tls.log
    TLSProtocol TLSv1.2
    
    TLSRSACertificateFile /etc/ssl/certs/ftp.crt
    TLSRSACertificateKeyFile /etc/ssl/private/ftp.key
    TLSCACertificateFile /etc/ssl/certs/ca.crt
    
    TLSOptions NoCertRequest
    TLSVerifyClient off
    TLSRequired on
</IfModule>

# Anonymous FTP (if required)
<Anonymous ~ftp>
    User ftp
    Group nogroup
    UserAlias anonymous ftp
    
    <Directory *>
        <Limit WRITE>
            DenyAll
        </Limit>
    </Directory>
</Anonymous>

# User restrictions (Banjarnegara)
<Directory /home/file>
    <Limit ALL>
        AllowUser file
        DenyAll
    </Limit>
</Directory>
```

### Create FTP Users
```bash
# Create user 'file' with restricted home
useradd -m -d /home/file -s /bin/bash file
echo "file:Skills39!" | chpasswd

# Create anonymous FTP directory
mkdir -p /srv/ftp
chown ftp:nogroup /srv/ftp
```

```bash
systemctl restart proftpd
systemctl enable proftpd
```

### Validation
```bash
# Test FTP connection
ftp localhost
# Login with user 'file' / Skills39!

# Test TLS
lftp -u file,Skills39! ftps://localhost

# Test anonymous (if enabled)
ftp localhost
# Login: anonymous / (any email)
```

---

## 📋 Service 11: Local Repository

### Option A: apt-mirror (Full Mirror)

```bash
apt install -y apt-mirror apache2
```

### /etc/apt/mirror.list
```
set base_path /var/spool/apt-mirror
set nthreads 20
set _tilde 0

deb http://deb.debian.org/debian bookworm main contrib non-free
deb http://deb.debian.org/debian bookworm-updates main contrib non-free
deb http://security.debian.org/debian-security bookworm-security main contrib non-free

clean http://deb.debian.org/debian
```

```bash
# Start mirroring (takes hours!)
apt-mirror

# Create symlink for Apache
ln -s /var/spool/apt-mirror/mirror/deb.debian.org/debian /var/www/html/debian
```

### Option B: Simple Package Cache (Faster)

```bash
# Just copy packages from ISO/DVD
mkdir -p /var/www/html/repo/debian
mount /dev/cdrom /mnt
cp -r /mnt/* /var/www/html/repo/debian/
umount /mnt
```

### Apache Configuration
```apache
<VirtualHost *:80>
    ServerName repo.lksn2025.id
    DocumentRoot /var/www/html/repo
    
    <Directory /var/www/html/repo>
        Options +Indexes +FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
```

### Client Configuration (/etc/apt/sources.list)
```
deb [trusted=yes] http://repo.lksn2025.id/debian bookworm main
```

```bash
apt update
```

### Validation
```bash
# Test repository access
curl http://repo.lksn2025.id/debian/

# Test from client
apt update
apt install -y <package>
```

---

## ✅ Combined Validation Checklist

### DHCP Server
- [ ] Service running
- [ ] Clients receiving IP addresses
- [ ] Static reservations working
- [ ] DNS option pushed to clients

### FTP Server
- [ ] Service running
- [ ] TLS enabled
- [ ] User 'file' can login
- [ ] Chroot working (users locked to home)
- [ ] Anonymous access (if required)

### Local Repository
- [ ] Apache serving repository
- [ ] Clients can access via HTTP
- [ ] apt update works from clients
- [ ] Packages can be installed

---

## 🐛 Common Issues

### DHCP: No IP assigned
**Fix:**
```bash
# Check interface configured
grep INTERFACESv4 /etc/default/isc-dhcp-server

# Check subnet matches interface network
ip addr show ens18
```

### FTP: Login failed
**Fix:**
```bash
# Check user exists
id file

# Check ProFTPD logs
tail -f /var/log/proftpd/proftpd.log

# Test without TLS first
```

### Repository: 404 Not Found
**Fix:**
```bash
# Check Apache serving correct directory
ls -la /var/www/html/repo/

# Check Apache config
apache2ctl -S
```

## 📚 References

- [ISC DHCP Server](https://www.isc.org/dhcp/)
- [ProFTPD Documentation](http://www.proftpd.org/docs/)
- [apt-mirror Guide](https://apt-mirror.github.io/)
