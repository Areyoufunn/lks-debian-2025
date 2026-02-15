# Service 01: Firewall & Routing (fw-srv)

> **VM:** fw-srv  
> **FQDN:** fw.lksn2025.id  
> **Role:** Gateway, Firewall, NAT, VPN Server

## 📋 Overview

Firewall server adalah **foundation** dari seluruh topologi. Semua traffic antar zone harus melalui firewall ini.

## 🔧 Services

1. **Firewall (nftables)**
2. **NAT/Masquerading**
3. **Routing**
4. **VPN Server (OpenVPN/WireGuard)**

## 📍 Network Configuration

### Interfaces

| Interface | Zone | IP Address | Gateway | Description |
|-----------|------|------------|---------|-------------|
| ens18 | WAN (Internet) | 192.168.27.200/24 | 192.168.27.1 | Internet connection |
| ens19 | INT (Internal) | 192.168.1.254/24 | - | Internal services |
| ens20 | DMZ | 172.16.1.254/24 | - | Public-facing services |
| ens21 | MGMT | 10.0.0.11/24 | - | Management access |

### IP Forwarding

```bash
# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Persist
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
```

**Kenapa?** IP forwarding diperlukan agar kernel bisa meneruskan paket dari satu interface ke interface lain (routing).

## 🛡️ Firewall Configuration (nftables)

### Zone Definitions

| Zone | Interface | Default Policy | Description |
|------|-----------|----------------|-------------|
| WAN | ens18 | DROP | Untrusted internet |
| INT | ens19 | ACCEPT | Trusted internal |
| DMZ | ens20 | DROP | Semi-trusted public services |
| MGMT | ens21 | ACCEPT | Management only |

### Rules Requirements

#### INPUT Chain
```nftables
chain input {
    type filter hook input priority 0; policy drop;
    
    # Allow established/related
    ct state established,related accept
    
    # Allow loopback
    iifname "lo" accept
    
    # Management & DNS
    tcp dport { 22, 53 } accept
    udp dport 53 accept
    
    # VPN
    udp dport 1194 accept   # OpenVPN
    udp dport 51820 accept  # WireGuard
}
```

**Penjelasan:**
- `ct state established,related accept` - Allow response traffic dari koneksi yang sudah established
- `tcp dport 22` - SSH untuk management
- `tcp/udp dport 53` - DNS queries
- `udp dport 1194` - OpenVPN server
- `udp dport 51820` - WireGuard VPN

#### FORWARD Chain
```nftables
chain forward {
    type filter hook forward priority 0; policy drop;
    
    # Allow established/related
    ct state established,related accept
    
    # Allow LAN to WAN
    iifname "ens19" oifname "ens18" accept
    
    # Allow VPN to LAN/DMZ
    ip saddr 10.10.0.0/24 accept
    
    # Allow Mail (DMZ) to LDAP (INT)
    ip saddr 172.16.1.10 ip daddr 192.168.1.10 tcp dport { 389, 636 } accept
    
    # Allow DMZ to INT (DNS only)
    iifname "ens20" oifname "ens19" tcp dport 53 accept
    iifname "ens20" oifname "ens19" udp dport 53 accept
}
```

**Penjelasan:**
- LAN to WAN: Internal users bisa akses internet
- VPN to LAN/DMZ: VPN clients bisa akses internal resources
- Mail to LDAP: Mail server perlu LDAP untuk authentication
- DMZ to INT DNS: Public services perlu DNS resolution

### NAT Configuration

#### SNAT/Masquerade
```nftables
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100;
        
        # Masquerade (LAN/DMZ to Internet)
        oifname "ens18" masquerade
    }
}
```

**Kenapa Masquerade?**
- Internal IPs (192.168.x.x, 172.16.x.x) tidak routable di internet
- Masquerade mengubah source IP menjadi IP public (192.168.27.200)
- Response traffic akan di-translate balik ke IP internal

#### DNAT/Port Forwarding
```nftables
table ip nat {
    chain prerouting {
        type nat hook prerouting priority -100;
        
        # Port Forwarding (DNAT)
        iifname "ens18" tcp dport { 80, 443 } dnat to 172.16.1.100  # Web VIP
        iifname "ens18" tcp dport 25 dnat to 172.16.1.10            # SMTP
        iifname "ens18" tcp dport { 143, 993 } dnat to 172.16.1.10  # IMAP
    }
}
```

**Penjelasan:**
- Traffic dari internet ke port 80/443 diteruskan ke Web VIP (172.16.1.100)
- Traffic ke port 25 (SMTP) diteruskan ke mail server
- Traffic ke port 143/993 (IMAP) diteruskan ke mail server

## 🔐 VPN Configuration

### Option 1: OpenVPN (Recommended untuk LKSN 2025)

**File:** `/etc/openvpn/server.conf`

```conf
# Network
port 1194
proto udp
dev tun
topology subnet

# VPN Network
server 10.10.0.0 255.255.255.0

# Certificates (dari int-srv CA)
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh2048.pem

# Routing
push "route 192.168.1.0 255.255.255.0"  # INT zone
push "route 172.16.1.0 255.255.255.0"   # DMZ zone
push "redirect-gateway def1"             # Route all traffic

# DNS
push "dhcp-option DNS 192.168.1.10"

# LDAP Authentication (Plugin)
plugin /usr/lib/openvpn/openvpn-auth-ldap.so /etc/openvpn/auth-ldap.conf

# Security
cipher AES-256-CBC
auth SHA256
tls-auth /etc/openvpn/ta.key 0
```

**LDAP Auth Config:** `/etc/openvpn/auth-ldap.conf`
```xml
<LDAP>
    URL ldap://192.168.1.10
    BindDN cn=admin,dc=lksn2025,dc=id
    Password Skills39!
    Timeout 15
    
    <Group>
        BaseDN ou=VPN,dc=lksn2025,dc=id
        SearchFilter (uid=%u)
        MemberAttribute member
    </Group>
</LDAP>
```

### Option 2: WireGuard (Jakarta 2025)

**File:** `/etc/wireguard/wg0.conf`

```conf
[Interface]
Address = 10.10.0.1/24
ListenPort = 51820
PrivateKey = <server-private-key>

# Client 1
[Peer]
PublicKey = <client1-public-key>
PresharedKey = <preshared-key>
AllowedIPs = 10.10.0.10/32

# Client 2
[Peer]
PublicKey = <client2-public-key>
PresharedKey = <preshared-key>
AllowedIPs = 10.10.0.11/32
```

**Routing untuk WireGuard:**
```bash
# Add routing
ip route add 192.168.1.0/24 dev wg0
ip route add 172.16.1.0/24 dev wg0
```

## 📝 Configuration Files

### /etc/network/interfaces
```
auto lo
iface lo inet loopback

# WAN Interface
auto ens18
iface ens18 inet static
    address 192.168.27.200
    netmask 255.255.255.0
    gateway 192.168.27.1
    dns-nameservers 192.168.1.10

# INT Interface
auto ens19
iface ens19 inet static
    address 192.168.1.254
    netmask 255.255.255.0

# DMZ Interface
auto ens20
iface ens20 inet static
    address 172.16.1.254
    netmask 255.255.255.0

# MGMT Interface
auto ens21
iface ens21 inet static
    address 10.0.0.11
    netmask 255.255.255.0
```

### /etc/nftables.conf
```nftables
#!/usr/sbin/nft -f

flush ruleset

table ip filter {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        iifname "lo" accept
        tcp dport { 22, 53 } accept
        udp dport 53 accept
        udp dport 1194 accept
        udp dport 51820 accept
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
        ct state established,related accept
        iifname "ens19" oifname "ens18" accept
        ip saddr 10.10.0.0/24 accept
        ip saddr 172.16.1.10 ip daddr 192.168.1.10 tcp dport { 389, 636 } accept
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100;
        oifname "ens18" masquerade
    }
    
    chain prerouting {
        type nat hook prerouting priority -100;
        iifname "ens18" tcp dport { 80, 443 } dnat to 172.16.1.100
        iifname "ens18" tcp dport 25 dnat to 172.16.1.10
        iifname "ens18" tcp dport { 143, 993 } dnat to 172.16.1.10
    }
}
```

## ✅ Validation Checklist

- [ ] **Network Interfaces**
  - [ ] All 4 interfaces configured with correct IPs
  - [ ] Default gateway set to 192.168.27.1
  - [ ] All interfaces UP and running
  
- [ ] **IP Forwarding**
  - [ ] `net.ipv4.ip_forward = 1` in sysctl
  - [ ] Persisted in `/etc/sysctl.conf`
  
- [ ] **Firewall Rules**
  - [ ] nftables service active
  - [ ] INPUT chain: SSH, DNS, VPN ports open
  - [ ] FORWARD chain: LAN to WAN allowed
  - [ ] Default policies correct (DROP for untrusted)
  
- [ ] **NAT Configuration**
  - [ ] Masquerade rule for outgoing traffic
  - [ ] DNAT rules for web, mail services
  - [ ] Test: Internal hosts can reach internet
  
- [ ] **VPN Server**
  - [ ] OpenVPN/WireGuard service running
  - [ ] Certificates configured (from CA)
  - [ ] LDAP authentication working
  - [ ] VPN clients can access INT/DMZ zones
  
- [ ] **Routing**
  - [ ] Routing table correct
  - [ ] Can ping between zones
  - [ ] Traffic flows as expected

## 🐛 Common Issues

### Issue 1: Internal hosts can't reach internet
**Symptom:** Ping 8.8.8.8 dari INT zone gagal

**Diagnosis:**
```bash
# Check IP forwarding
sysctl net.ipv4.ip_forward

# Check NAT rules
nft list table ip nat

# Check routing
ip route show
```

**Fix:**
1. Enable IP forwarding (jika belum)
2. Verify masquerade rule exists
3. Check default gateway

### Issue 2: Port forwarding tidak work
**Symptom:** Akses dari internet ke web server gagal

**Diagnosis:**
```bash
# Check DNAT rules
nft list chain ip nat prerouting

# Check if service running di backend
ssh 172.16.1.100 "systemctl status nginx"

# Test dari firewall
curl http://172.16.1.100
```

**Fix:**
1. Verify DNAT rule syntax
2. Ensure backend service running
3. Check firewall FORWARD chain allows traffic

## 📚 References

- [nftables Wiki](https://wiki.nftables.org/)
- [OpenVPN Documentation](https://openvpn.net/community-resources/)
- [WireGuard Quick Start](https://www.wireguard.com/quickstart/)
- [Linux IP Forwarding](https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt)
