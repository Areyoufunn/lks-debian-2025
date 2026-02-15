Berikut adalah MASTER GUIDE: ITNSA LINUX COMPLETE EDITION. Dokumentasi ini adalah gabungan detail dari seluruh sumber (LKS Nasional 2024/2025, Provinsi Jakarta/Jateng, Banjarnegara, & Jombang).
Dokumen ini dirancang agar tidak ada yang salah, mencakup seluruh service, troubleshooting, dan automation secara mendetail.

--------------------------------------------------------------------------------
📘 THE ULTIMATE ITNSA LINUX CONFIGURATION GUIDE
Gabungan Sumber: LKSN 25/24, Prov DKJ/Jateng, Kab. Banjarnegara/Jombang.

--------------------------------------------------------------------------------
🔐 BAGIAN 0: VARIABEL & KREDENSIAL (JANGAN TERTUKAR)
Sebelum mengetik config, pastikan Anda tahu sedang mengerjakan modul yang mana.
Modul
Username
Password
Keterangan
LKSN 2025 / Prov DKJ
admin, ani, budi
Skills39!
User LDAP & OS
LKSN 2024
rahasia
Skills39
Basic Auth Web
Jombang 2025
itnsa0X
(Dari Juri)
Login Proxmox
Banjarnegara
brahmana, nakula
Lks2024 / lks2025
User SSH & Router
Database (Jombang)
itnsa
(Sesuaikan)
DB User
Cacti (Jombang)
admin
admin
Monitoring

--------------------------------------------------------------------------------
🛠️ BAGIAN 1: SYSTEM FOUNDATION
1.1. RAID 1 (Software RAID)
[Sumber: LKSN 2024] Menggabungkan 2 disk fisik menjadi 1 logical mirror.
# Asumsi disk baru: /dev/sdb dan /dev/sdc
mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc
mkfs.ext4 /dev/md0
mkdir /data
mount /dev/md0 /data
# Persisten di fstab
echo '/dev/md0 /data ext4 defaults 0 0' >> /etc/fstab
1.2. SSH Hardening
[Sumber: Banjarnegara & Client Server] File: /etc/ssh/sshd_config
Port 2024                 # Atau 2025 (Sesuai Soal)
PermitRootLogin no        # Kecuali diminta Yes oleh Ansible
PasswordAuthentication no # Wajib pakai SSH Key
PubkeyAuthentication yes
• User Restriction: Buat user file / brahmana, kunci di home dir, disable sudo.
1.3. Local Repository
[Sumber: Banjarnegara] Install apt-mirror atau copy ISO/DVD ke folder web /var/www/html/repo.
• Client config (/etc/apt/sources.list): deb [trusted=yes] http://repo.jateng.id/debian bookworm main

--------------------------------------------------------------------------------
🔐 BAGIAN 2: CERTIFICATE AUTHORITY (ROOT OF TRUST)
[Sumber: SEMUA MODUL - WAJIB] Tanpa ini, HTTPS, LDAPS, SMTPS, dan VPN akan gagal/untrusted.
1. Buat Root CA:
    ◦ Command: openssl req -x509 -new -nodes -key rootca.key -sha256 -days 3650 -out rootca.pem
    ◦ CN: ITNSA Root CA / LKSN2025-CA.
    ◦ PENTING: Pastikan atribut basicConstraints=CA:TRUE ada di config openssl.
2. Distribusi:
    ◦ Copy rootca.pem ke /usr/local/share/ca-certificates/ di semua server & client.
    ◦ Run: update-ca-certificates.
3. Generate Server Certs:
    ◦ Buat CSR dan Key untuk: web, mail, vpn.
    ◦ Sign menggunakan Root CA.
    ◦ Khusus VPN: Tambahkan ekstensi extendedKeyUsage=serverAuth.
    ◦ Khusus Jombang: Buat Self-Signed Cert validitas 90 hari untuk phpmyadmin.

--------------------------------------------------------------------------------
🌐 BAGIAN 3: NETWORK SERVICES (DNS & DHCP)
3.1. DNS Server (Bind9)
[Sumber: LKSN, Jombang, Banjarnegara]
File: /etc/bind/named.conf.local
// Master Zone
zone "lksn2025.id" { type master; file "/etc/bind/db.lksn"; };
zone "1.16.172.in-addr.arpa" { type master; file "/etc/bind/db.172"; };

// Slave Zone (Jika ada server kedua)
zone "lksn2025.id" { type slave; masters { 192.168.1.10; }; file "/var/cache/bind/db.lksn"; };
File Zone (db.lksn) - Perhatikan Record Khusus:
; Record Standar
@       IN  A   172.16.1.10
ns1     IN  A   172.16.1.10
www     IN  A   100.100.100.200 ; IP Public Firewall (NAT)
mail    IN  A   172.16.1.10
vip     IN  A   172.16.1.100    ; Virtual IP Keepalived
vpn     IN  A   100.100.100.200

; Record Khusus Jombang
phpmyadmin IN A 172.16.1.11
db         IN A 172.16.1.17
netmon     IN A 172.16.1.15
; Mass Virtual Host (www1 - www20)
www1       IN A 172.16.1.11
...
www20      IN A 172.16.1.11
3.2. DHCP Server
[Sumber: Jateng, Banjarnegara] File: /etc/dhcp/dhcpd.conf
subnet 192.168.10.0 netmask 255.255.255.0 {
  range 192.168.10.100 192.168.10.200;
  option routers 192.168.10.1;
  option domain-name-servers 192.168.10.11;
  # Static Reservation
  host linsrv2 { hardware ethernet 00:11:22:33:44:55; fixed-address 192.168.10.12; }
}

--------------------------------------------------------------------------------
👥 BAGIAN 4: DIRECTORY SERVICE (LDAP)
[Sumber: LKSN 2025, Prov Jakarta] Layanan ini krusial untuk login Email dan VPN.
1. Install: slapd, ldap-utils.
2. Struktur (LDIF):
3. User:
    ◦ Buat user ani, budi, kyw1.
    ◦ Atribut wajib: uid, userPassword (Hash SSHA), mail (email address).
    ◦ User ani member ou=VPN dan ou=Mail.

--------------------------------------------------------------------------------
🛡️ BAGIAN 5: FIREWALL & VPN
5.1. Firewall (NFTables) - STANDAR BARU
[Sumber: LKSN 2025, Jakarta] File: /etc/nftables.conf
flush ruleset
table ip filter {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        iifname "lo" accept
        tcp dport { 22, 53 } accept  # Mgmt & DNS
        udp dport 53 accept
        udp dport 1194 accept        # OpenVPN
        udp dport 51820 accept       # WireGuard
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
        ct state established,related accept
        # Allow LAN to WAN
        iifname "eth1" oifname "eth0" accept
        # Allow VPN to LAN/DMZ
        ip saddr 10.10.0.0/24 accept
        # Allow Mail (DMZ) to LDAP (INT)
        ip saddr 172.16.1.10 ip daddr 192.168.1.10 tcp dport { 389, 636 } accept
    }
}
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100;
        # Masquerade (LAN/DMZ ke Internet)
        oifname "eth0" masquerade
    }
    chain prerouting {
        type nat hook prerouting priority -100;
        # Port Forwarding (DNAT)
        iifname "eth0" tcp dport { 80, 443 } dnat to 172.16.1.100
    }
}
5.2. VPN (Pilih Salah Satu Sesuai Soal)
• WireGuard [Jakarta]: /etc/wireguard/wg0.conf. Wajib pakai Pre-Shared Key. Routing 0.0.0.0/0 (Redirect Gateway).
• OpenVPN [LKSN 2025]: /etc/openvpn/server.conf. Mode tun (UDP 1194). Tambahkan plugin openvpn-auth-ldap.so untuk autentikasi user LDAP.

--------------------------------------------------------------------------------
🌍 BAGIAN 6: WEB INFRASTRUCTURE
6.1. High Availability & Load Balancer
[Sumber: LKSN 2025]
1. Keepalived (Virtual IP):
    ◦ Master: Priority 110. Backup: Priority 100.
    ◦ VIP: 172.16.1.100 (atau sesuai soal).
2. HAProxy:
    ◦ Frontend: Bind *:80 (Redirect HTTPS), Bind *:443 (SSL Term).
    ◦ Backend: Balance roundrobin ke server Web01 & Web02 (Port 8080).
    ◦ Header: http-response set-header Via-Proxy %H.
6.2. Web Server (Nginx/Apache)
[Sumber: Jombang, Banjarnegara]
• Isi Index: "Hello from ${hostname}" atau "ini hasil dari ansible".
• Security: Folder /data/file/ diproteksi htpasswd.
• Mass Virtual Host (Jombang):
    ◦ Mapping www1 - www20 ke /home/wwwX.
    ◦ Config Apache: VirtualDocumentRoot /home/%1 (Butuh mod_vhost_alias).
• IIS (Jombang/Windows): Site win1 dan win2 dengan konten HTML spesifik.

--------------------------------------------------------------------------------
📧 BAGIAN 7: MAIL SERVER
[Sumber: Semua Modul]
1. Postfix (SMTP):
    ◦ Wajib TLS Enforcement (smtpd_tls_security_level = encrypt).
    ◦ Integrasi LDAP untuk lookup user.
2. Dovecot (IMAP):
    ◦ Wajib TLS. Location maildir:~/Maildir.
    ◦ Integrasi LDAP di dovecot-ldap.conf.ext.
3. Roundcube:
    ◦ Webmail HTTPS. Config default_host = 'localhost'.
4. Alias: contact -> admin.

--------------------------------------------------------------------------------
💾 BAGIAN 8: DATA & FILES (DB, FTP, SAMBA)
8.1. Database (MariaDB) - Khusus Jombang
• Create DB itnsa.
• Create Table users (id [int, ai], nama [varchar], alamat [varchar]).
• Grant remote access ke user root atau itnsa dari IP 172.16.X.X.
8.2. FTP Server (ProFTPD)
• Banjarnegara: User Chroot (DefaultRoot ~). Wajib TLS.
• Jombang: Fix error login anonymous (pastikan tidak diblok).

--------------------------------------------------------------------------------
🤖 BAGIAN 9: AUTOMATION (ANSIBLE)
Playbook Lengkap (Web, User, DNS, FTP) - Sesuai Permintaan: File: /etc/ansible/site.yml
---
- name: Deploy Services
  hosts: all
  become: yes
  tasks:
    # 1. WEB SERVER (NGINX) - LKSN/Jombang
    - name: Install Nginx
      apt: name=nginx state=present
      when: "'web_servers' in group_names"

    - name: Custom Index Content
      copy:
        content: "<h1>ini hasil dari ansible</h1>"
        dest: /var/www/html/index.html
      when: "'web_servers' in group_names"

    # 2. DNS SERVER (BIND9) - Permintaan Tambahan
    - name: Install Bind9
      apt: name=bind9 state=present
      when: "'dns_servers' in group_names"

    - name: Copy Zone Config
      blockinfile:
        path: /etc/bind/named.conf.local
        block: |
          zone "lks-itnsa.id" { type master; file "/etc/bind/db.itnsa"; };
      when: "'dns_servers' in group_names"

    # 3. FTP SERVER - Permintaan Tambahan
    - name: Install ProFTPD
      apt: name=proftpd-core state=present
      when: "'ftp_servers' in group_names"

    - name: Configure FTP Chroot
      lineinfile:
        path: /etc/proftpd/proftpd.conf
        regexp: '^#?DefaultRoot'
        line: 'DefaultRoot ~'
      when: "'ftp_servers' in group_names"

--------------------------------------------------------------------------------
🔧 BAGIAN 10: TROUBLESHOOTING & MONITORING (JOMBANG)
10.1. Skenario Perbaikan (Mesin .50)
1. Web Error 500/403:
    ◦ Cek permission: chown -R www-data:www-data /var/www/html.
    ◦ Cek config Vhost: nginx -t atau apache2ctl configtest.
    ◦ Goal: Muncul tulisan "Hi... LKS 2025".
2. DNS Query Failed:
    ◦ Cek file zone: Apakah serial number sudah di-increment?
    ◦ Cek syntax: named-checkconf.
    ◦ Cek firewall: Port 53 open?
3. FTP Anonymous Fail:
    ◦ Edit /etc/proftpd/proftpd.conf.
    ◦ Pastikan blok <Anonymous ~ftp> tidak dikomentari dan UserAlias anonymous ftp aktif.
10.2. Monitoring (Cacti)
1. SNMP: Install snmpd di target. Edit /etc/snmp/snmpd.conf, ubah rocommunity public jadi rocommunity lks-itnsa. Restart service.
2. Cacti: Add Device -> Generic SNMP Device -> Masukkan IP & Community String. Create Graphs.