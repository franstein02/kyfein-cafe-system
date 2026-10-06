# Panduan Deploy HTTPS & WebSocket (WSS) untuk Kyfein Cafe System

Dokumen ini berisi panduan lengkap konfigurasi HTTPS (SSL/TLS), WebSocket Secure (`wss://`), DNS, win-acme, dan Nginx Reverse Proxy untuk server **Kyfein Cafe System** (Windows PC Server / Laragon).

---

## 🎯 Mengapa HTTPS Wajib Digunakan?

Pada perangkat **iOS (Safari)** dan browser modern (Chrome, Edge, Firefox), fitur-fitur sensitif perangkat seperti:
1. **Geolocation (GPS)** — Diperlukan untuk validasi radius absensi server-side (`haversine_distance`).
2. **Kamera (`getUserMedia`)** — Diperlukan untuk foto bukti absensi masuk/pulang, bukti izin, dan foto bukti QRIS.

HANYA dapat berjalan pada **Secure Context (`https://`)**. Jika diakses via HTTP (`http://`), browser iOS akan memblokir akses GPS dan Kamera secara otomatis.

---

## 📋 Ringkasan Alur Arsitektur Deployment

```
[ Perangkat Kasir / iOS / Android / KDS ]
                   │
                   ▼ (HTTPS / WSS di Port 443)
       ┌────────────────────────┐
       │     Nginx Web Server   │ (Terminasi SSL SSL & Serve Flutter Web SPA)
       └───────────┬────────────┘
                   │
                   ▼ (Reverse Proxy Local HTTP di Port 8000)
       ┌────────────────────────┐
       │     FastAPI Uvicorn    │ (Backend REST API & WebSocket KDS Manager)
       └────────────────────────┘
```

---

## 🌐 Langkah 1: Setup DNS (A Record Alamat Lokal)

1. Buat **A Record** pada DNS Management domain cafe Anda (misal Cloudflare, GoDaddy, Namecheap):
   - **Subdomain / Host**: `kasir` (Hasil akhir: `kasir.cafe-kyfein.com`)
   - **IPv4 Address**: `192.168.1.100` (Isi dengan **IP Lokal Statis** PC Server Cafe Anda).
   - **TTL**: Auto / 300 seconds.

2. **Pastikan IP PC Server Statis**:
   - Atur IP PC Server menjadi Statis melalui **DHCP Reservation** di router cafe agar IP `192.168.1.100` tidak pernah berubah.

---

## 🔐 Langkah 2: Penerbitan Sertifikat SSL via win-acme (DNS-01 Challenge)

Mengapa menggunakan **DNS-01 Challenge**?
Karena PC Server berada di jaringan lokal (IP privat `192.168.1.x`), server publik Let's Encrypt tidak dapat menghubungi server Anda via HTTP-01 (port 80) dari internet. DNS-01 Challenge membuktikan kepemilikan domain melalui TXT Record DNS tanpa memerlukan IP Publik.

### Langkah-langkah Penerbitan:
1. Unduh **win-acme** (ACME Client untuk Windows) dari [win-acme.com](https://www.win-acme.com/).
2. Ekstrak ke folder `C:\win-acme`.
3. Buka **PowerShell** / **Command Prompt** sebagai **Administrator**, lalu jalankan:
   ```powershell
   cd C:\win-acme
   .\wacs.exe
   ```
4. Pilih opsi menu:
   - **N**: Create new certificate (full options)
   - **2**: Manual input
   - Masukkan host name: `kasir.cafe-kyfein.com`
   - Pilih metode validasi: **[dns-01] Perform challenge with DNS plugin / script**
   - Pilih API Plugin DNS sesuai DNS Provider Anda (misalnya *Cloudflare DNS API*, *GoDaddy API*, atau *Script Manual TXT record*).
   - Pilih tipe kunci: **RSA key** atau **EC key**.
   - Pilih format export: **PEM encoded files** (Simpan di folder misal: `C:\ProgramData\win-acme\https-kasir\`).
5. **Auto-Renewing**:
   - win-acme secara otomatis akan membuat entri di **Windows Task Scheduler** yang berjalan setiap hari untuk memperpanjang sertifikat sebelum 90 hari habis.

---

## ⚙️ Langkah 3: Konfigurasi Nginx (Reverse Proxy + SSL + WSS)

Salin konfigurasi Nginx berikut ke `C:/laragon/etc/nginx/sites-enabled/kyfein.conf` (atau `deploy/nginx/kasir.conf`):

```nginx
# Nginx HTTPS & WebSocket Configuration for Kyfein Cafe System

# 1. HTTP Server - Redirect 80 -> 443 HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name kasir.cafe-kyfein.com;

    # Redirect seluruh lalu lintas HTTP ke HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

# 2. HTTPS Server - Main Application (Port 443)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name kasir.cafe-kyfein.com;

    # File Sertifikat SSL dari win-acme
    ssl_certificate     "C:/ProgramData/win-acme/https-kasir/kasir.cafe-kyfein.com-crt.pem";
    ssl_certificate_key "C:/ProgramData/win-acme/https-kasir/kasir.cafe-kyfein.com-key.pem";

    # SSL Security Standards
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # Batas ukuran maksimal upload body (Minimal 6M, diset 10M untuk foto absensi & bukti QRIS)
    client_max_body_size 10M;

    # Directory Build Output Flutter Web SPA
    root "C:/laragon/www/kyfein-web";
    index index.html;

    # Serve Flutter Web SPA (Single Page Application)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Reverse Proxy REST API ke FastAPI Uvicorn Backend
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Reverse Proxy WebSocket Secure (WSS) untuk KDS Realtime
    # Endpoint: wss://kasir.cafe-kyfein.com/api/v1/kds/ws/{area_produksi}
    location /api/v1/kds/ws/ {
        proxy_pass http://127.0.0.1:8000/api/v1/kds/ws/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Mencegah putusnya koneksi WebSocket (Keep-Alive 24 Jam)
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
```

Jalankan pengujian konfigurasi dan reload Nginx:
```powershell
nginx -t
nginx -s reload
```

---

## 🛠️ Langkah 4: Troubleshooting Router DNS Rebinding Protection

### Permasalahan:
Sebagian besar router modern (seperti **Mikrotik**, **OpenWrt**, **pfSense**, atau Router bawaan Indihome/Biznet) memiliki fitur keamanan bernama **DNS Rebinding Protection**. Fitur ini secara default **menolak/memblokir** hasil query DNS publik jika mengembalikan alamat IP Privat (seperti `192.168.1.100`).

Akibatnya, perangkat iOS atau Laptop kasir saat membuka `https://kasir.cafe-kyfein.com` akan mendapati pesan error:
> `DNS_PROBE_FINISHED_NXDOMAIN` atau `Server IP Address could not be found`.

### Solusi / Penanganan:

1. **Mikrotik Router**:
   - Buka Winbox -> **IP** -> **DNS** -> **Static**.
   - Tambahkan Static DNS Record:
     - **Name**: `kasir.cafe-kyfein.com`
     - **Address**: `192.168.1.100`
   - Ini memastikan perangkat di jaringan cafe langsung mendapatkan IP `192.168.1.100` tanpa terhalang rebind protection.

2. **OpenWrt / Dnsmasq**:
   - Edit `/etc/config/dhcp`:
     ```text
     list rebind_domain 'kasir.cafe-kyfein.com'
     ```
   - Atau tambahkan ke `rebind_local_ok`:
     ```text
     option rebind_protection '0'
     ```

3. **Pi-hole / AdGuard Home**:
   - Buka Dashboard -> **DNS Rewrites** -> Add Rewrite Rule:
     - `kasir.cafe-kyfein.com` ➔ `192.168.1.100`.

4. **Router ISP (Tanpa Pengaturan DNS Rebind)**:
   - Atur DNS Server di router lokal atau di perangkat kasir ke DNS resolver publik yang mendukung DNS over HTTPS/TLS (seperti Cloudflare `1.1.1.1` atau Google `8.8.8.8`).

---

## 📱 Langkah 5: Penyesuaian Base URL pada Client Flutter Web / App

Pastikan file konfigurasi environment / constants di Frontend Flutter Web (`KyfeinFrontend`) diarahkan ke domain HTTPS dan WSS:

```dart
class AppConfig {
  // REST API Base URL
  static const String apiBaseUrl = "https://kasir.cafe-kyfein.com/api/v1";

  // WebSocket KDS Base URL
  static const String wsKdsBaseUrl = "wss://kasir.cafe-kyfein.com/api/v1/kds/ws";
}
```

---

## ✅ Hasil yang Diharapkan

1. Flutter Web dibuka di **iOS (Safari)** dan **PC Browser** via `https://kasir.cafe-kyfein.com` tanpa peringatan sertifikat ("Untrusted / Not Private").
2. Fitur **Geolocation (GPS)** dan **Kamera (Absensi & Foto QRIS)** berfungsi 100% lancar di iOS.
3. Fitur **Kitchen Display System (KDS)** terhubung secara realtime melalui koneksi WebSocket Secure (`wss://`).
4. Sertifikat SSL ter-renew otomatis secara periodik oleh win-acme.
