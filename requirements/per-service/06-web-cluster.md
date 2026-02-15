# Service 06: Web Cluster (web-01 & web-02)

> **VMs:** web-01, web-02  
> **VIP:** 172.16.1.100  
> **Services:** Keepalived, HAProxy, Nginx/Apache

## 📋 Overview

Web cluster dengan High Availability menggunakan Keepalived untuk VIP failover dan HAProxy untuk load balancing.

## 🔧 Part 1: Keepalived (HA/Failover)

### Installation (Both Servers)
```bash
apt update
apt install -y keepalived
```

### web-01 (MASTER): /etc/keepalived/keepalived.conf
```conf
vrrp_script chk_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER
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
    
    track_script {
        chk_haproxy
    }
}
```

### web-02 (BACKUP): /etc/keepalived/keepalived.conf
```conf
vrrp_script chk_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface ens18
    virtual_router_id 51
    priority 90
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass Skills39!
    }
    
    virtual_ipaddress {
        172.16.1.100/24
    }
    
    track_script {
        chk_haproxy
    }
}
```

```bash
systemctl restart keepalived
systemctl enable keepalived
```

## 🔧 Part 2: HAProxy (Load Balancer)

### Installation (Both Servers)
```bash
apt install -y haproxy
```

### /etc/haproxy/haproxy.cfg (Both Servers)
```conf
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    
    # SSL
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
    log global
    mode http
    option httplog
    option dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend http_front
    bind *:80
    # Redirect to HTTPS
    redirect scheme https code 301

frontend https_front
    bind *:443 ssl crt /etc/ssl/private/web.pem
    
    # Add custom header
    http-response set-header Via-Proxy %H
    
    default_backend web_back

backend web_back
    balance roundrobin
    option httpchk GET /
    http-check expect status 200
    
    # Backend servers
    server web-01 172.16.1.21:8080 check
    server web-02 172.16.1.22:8080 check

listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats auth admin:Skills39!
```

### Combine Certificate & Key: /etc/ssl/private/web.pem
```bash
cat /etc/ssl/certs/web.crt /etc/ssl/private/web.key > /etc/ssl/private/web.pem
chmod 600 /etc/ssl/private/web.pem
```

```bash
systemctl restart haproxy
systemctl enable haproxy
```

## 🔧 Part 3: Web Server (Nginx)

### Installation (Both Servers)
```bash
apt install -y nginx
```

### /etc/nginx/sites-available/default
```nginx
server {
    listen 8080;
    server_name www.lksn2025.id;
    
    root /var/www/html;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Protected directory
    location /data/file/ {
        auth_basic "Restricted Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
```

### Create Protected Directory
```bash
mkdir -p /var/www/html/data/file
echo "Protected content" > /var/www/html/data/file/index.html

# Create htpasswd (user: rahasia, pass: Skills39)
apt install -y apache2-utils
htpasswd -c /etc/nginx/.htpasswd rahasia
```

### Custom Index (Show Hostname)
```bash
echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
```

### Mass Virtual Hosts (Jombang - Optional)
```nginx
# /etc/nginx/sites-available/mass-vhosts
server {
    listen 8080;
    server_name ~^www(?<num>\d+)\.lksn2025\.id$;
    
    root /home/www$num;
    index index.html;
}
```

```bash
# Create directories
for i in {1..20}; do
    mkdir -p /home/www$i
    echo "<h1>www$i.lksn2025.id</h1>" > /home/www$i/index.html
done
```

```bash
systemctl restart nginx
systemctl enable nginx
```

## ✅ Validation

### Test VIP
```bash
# Check VIP on master
ip addr show ens18 | grep 172.16.1.100

# Test failover: stop keepalived on master
systemctl stop keepalived

# VIP should move to backup
```

### Test Load Balancing
```bash
# Access via VIP
curl http://172.16.1.100
# Should show "Hello from web-01" or "Hello from web-02"

# Multiple requests should round-robin
for i in {1..10}; do curl http://172.16.1.100; done
```

### Test HAProxy Stats
```
http://172.16.1.100:8404/stats
Login: admin / Skills39!
```

### Validation Checklist

- [ ] **Keepalived**
  - [ ] VIP active on master
  - [ ] Failover works when master down
  - [ ] VRRP authentication configured
  
- [ ] **HAProxy**
  - [ ] Load balancing works
  - [ ] Health checks active
  - [ ] SSL termination works
  - [ ] Via-Proxy header added
  
- [ ] **Web Servers**
  - [ ] Both servers responding
  - [ ] Protected directory requires auth
  - [ ] Custom index shows hostname

## 📚 References

- [Keepalived Documentation](https://www.keepalived.org/doc/)
- [HAProxy Configuration](http://www.haproxy.org/#docs)
- [Nginx Documentation](https://nginx.org/en/docs/)
