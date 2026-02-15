# Merged Requirements - LKS 2025

> **Status:** 🔄 In Progress  
> **Last Updated:** 2026-02-15  
> **Sources Analyzed:** 0/8

## Overview

Dokumen ini berisi **gabungan requirement dari 8 source soal LKS** yang telah di-merge dan deduplikasi.

### Source List

1. ⏳ LKS Provinsi 2025 Tipe A
2. ⏳ LKSN 2024 ITNSA TP MB
3. ⏳ LKSN 2025 TP MA Linux Environment
4. ⏳ LKS Jakarta 2025 ITNSA MC
5. ⏳ LKS Jateng 2024 ITNSA MC
6. ⏳ LKS Banjarnegara Modul A 2024
7. ⏳ LKS Banjarnegara Modul A 2025
8. ⏳ LKS Jombang 2025 Kompilasi

**Legend:**
- ⏳ Pending analysis
- 🔄 In progress
- ✅ Completed
- ❌ Skipped (duplicate)

---

## Merge Strategy

### Rules
1. ✅ **Include unique requirements** - Jika requirement hanya ada di 1 source, include
2. ❌ **Skip duplicates** - Jika requirement sama persis dengan yang sudah ada, skip
3. 🔀 **Merge similar** - Jika requirement mirip tapi ada perbedaan, merge jadi 1 comprehensive requirement
4. 📝 **Track source** - Setiap requirement di-tag dengan source-nya

### Example

**Source A:** Mail server dengan SMTP auth  
**Source B:** Mail server dengan SMTP auth ← **SKIP (duplicate)**  
**Source C:** Mail server dengan SMTP auth + DKIM ← **MERGE (add DKIM to existing)**

**Result:** Mail server dengan SMTP auth + DKIM `[Source: A, C]`

---

## 1. Firewall & Routing (fw-srv)

### Network Configuration
*Akan diisi setelah analisis PDF*

### Firewall Rules
*Akan diisi setelah analisis PDF*

### NAT Configuration
*Akan diisi setelah analisis PDF*

---

## 2. DNS Server (int-srv - Bind9)

### Basic Configuration
*Akan diisi setelah analisis PDF*

### Zones & Records
*Akan diisi setelah analisis PDF*

---

## 3. Certificate Authority (int-srv - OpenSSL)

### CA Configuration
*Akan diisi setelah analisis PDF*

---

## 4. LDAP Directory (int-srv - slapd)

### Directory Structure
*Akan diisi setelah analisis PDF*

---

## 5. Mail Server (mail-srv)

### Postfix Configuration
*Akan diisi setelah analisis PDF*

### Dovecot Configuration
*Akan diisi setelah analisis PDF*

### Webmail
*Akan diisi setelah analisis PDF*

---

## 6. Web Cluster (web-01 & web-02)

### High Availability
*Akan diisi setelah analisis PDF*

### Load Balancing
*Akan diisi setelah analisis PDF*

### Web Server
*Akan diisi setelah analisis PDF*

---

## 7. VPN Server (fw-srv - OpenVPN)

### VPN Configuration
*Akan diisi setelah analisis PDF*

---

## 8. Additional Services

*Akan diisi setelah analisis PDF*

---

## Unique Features by Source

### Source 1: LKS Provinsi 2025 Tipe A
*Akan diisi setelah analisis*

### Source 2: LKSN 2024 ITNSA TP MB
*Akan diisi setelah analisis*

### Source 3: LKSN 2025 TP MA Linux Environment
*Akan diisi setelah analisis*

### Source 4: LKS Jakarta 2025 ITNSA MC
*Akan diisi setelah analisis*

### Source 5: LKS Jateng 2024 ITNSA MC
*Akan diisi setelah analisis*

### Source 6: LKS Banjarnegara Modul A 2024
*Akan diisi setelah analisis*

### Source 7: LKS Banjarnegara Modul A 2025
*Akan diisi setelah analisis*

### Source 8: LKS Jombang 2025 Kompilasi
*Akan diisi setelah analisis*

---

## Next Steps

1. Extract requirement dari setiap PDF menggunakan template
2. Merge requirement dengan eliminasi duplikasi
3. Create per-service breakdown
4. Generate automation scripts berdasarkan merged requirements

---

**Note:** Dokumen ini akan di-update setelah semua PDF di-analisis.
