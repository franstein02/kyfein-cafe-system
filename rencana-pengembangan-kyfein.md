# Rencana Pengembangan Sistem — Kyfein (Cafe POS System)

> Dokumen ini dicatat progresif seiring diskusi berjalan. Setiap keputusan dicatat setelah disepakati (bukan draft/usulan). **Pemesanan hanya dilakukan di kasir** (tanpa QR code/web ordering pelanggan). Scope hanya 6 fitur utama di bawah, untuk 1 cafe (1 lokasi). **Sistem hanya punya 2 role: Karyawan dan Admin** (role Owner dihapus).
>
> **Versi 2 — 8 Oktober 2026.** Menggabungkan semua keputusan setelah review endpoint: penguncian transaksi, foto & HTTPS, snapshot HPP, shift berjalan, opname susulan, stok minimum terpisah, dan penghapusan role Owner. Bagian bertanda **[PENDING]** sengaja belum diputuskan.

---

## 1. Tech Stack

### 1.1 Infrastruktur & Jaringan
* **Perangkat:** PC Lokal (On-Premise) sebagai server — bukan cloud/VPS
* **Jaringan:** IP Lokal Statis. Semua perangkat klien (HP/tablet kasir, tablet bar, layar KDS kitchen) wajib berada di jaringan WiFi cafe yang sama
* **Remote Akses (opsional):** Cloudflare Tunnel atau Tailscale — gratis, aman, bisa pakai domain custom kalau admin/mitra perlu pantau dari luar jaringan cafe
* **HTTPS wajib di jaringan lokal:** geolocation & kamera di browser (Flutter Web untuk iOS/PC) hanya jalan di HTTPS. Pakai **domain asli** (mis. `kasir.namadomain`) dengan A record ke IP lokal statis PC server. Sertifikat **Let's Encrypt via DNS-01 challenge** (tool: win-acme di Windows), dipasang di Nginx. Perangkat klien tidak perlu install sertifikat apa pun
  * Konsekuensi: butuh domain (~Rp150 ribu/tahun), dan resolusi DNS butuh internet. Router yang punya DNS rebinding protection harus mengizinkan domain ini
  * mkcert ditolak: CA harus dipasang manual di tiap perangkat, rumit di iOS

### 1.2 Lingkungan Server (di PC)
* **Software utama:** Laragon (Windows)
* **Web server:** Nginx — serve frontend (Flutter Web build) sekaligus reverse proxy ke backend FastAPI (termasuk upgrade WebSocket `wss://`, `client_max_body_size` ≥ 6M)
* **Database:** MySQL / MariaDB (bawaan Laragon)

### 1.3 Backend & API
* **Bahasa/Framework:** Python + **FastAPI**
* **Server:** Uvicorn (async), auto-generate dokumentasi API (Swagger)
* **Realtime:** FastAPI WebSocket native — dipakai untuk push realtime transaksi ke Layar Pesanan/KDS
* **Prefix rute:** semua endpoint di bawah `/api/v1/` (mis. `/api/v1/foto`, `/api/v1/transaksi`, WebSocket KDS `/api/v1/kds/ws/`). Pembatalan transaksi di `/api/v1/transaksi/{id}/cancel` dengan alias `/void`
* **Waktu:** satu helper `now_local()` (waktu lokal server, selaras dengan kolom DATETIME naive) dipakai di semua modul. Tidak ada `datetime.now()` / `utcnow()` / `date.today()` langsung di luar helper itu
* **Validasi:** bentuk data divalidasi di Pydantic (`gt=0`, `min_length=1`, validator kombinasi field); validasi lintas tabel di endpoint. Error database (`IntegrityError`) dipetakan ke 409 (duplikat) / 400 (FK tidak valid), bukan 500

### 1.4 Frontend (Klien Android, iOS, PC)
* **Bahasa/Framework:** Flutter — 1 codebase untuk semua interface (Kasir, KDS, Admin)
* **Klien Android:** build jadi APK, diinstal di HP/tablet staff
* **Klien iOS / PC:** build jadi **Flutter Web**, di-hosting di folder Laragon, dilayani via Nginx di jaringan lokal — 100% gratis tanpa sewa hosting
* Role pada UI dibaca dari respons API, tanpa pengecekan role yang hardcode

## 2. Infrastruktur & Deployment
* Server jalan di PC lokal cafe, aktif selama jam operasional
* Semua device klien connect ke WiFi cafe yang sama dengan PC server
* Remote akses (opsional) pakai Cloudflare Tunnel/Tailscale — detail domain & setup masih **[PENDING]**
* **Penyimpanan foto:** folder di disk server, **di luar webroot Nginx**, tidak dilayani sebagai file statis. Disajikan hanya lewat endpoint API dengan autentikasi (lihat 3.0 "Foto")
* **Job terjadwal (Windows Task Scheduler):** backup database (5.4) dan hapus foto yatim (`dipakai = false`, lebih dari 24 jam). Folder foto ikut jadwal backup
* Redundansi PC server (kalau PC mati/rusak) — **[PENDING]**, di luar level database (level database sudah di 5.4)

## 3. Rencana Fitur

### 3.0 Master Data
**`kategori_menu`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| nama | VARCHAR | mis. "Makanan", "Minuman" |
| area_produksi | ENUM | `bar` / `kitchen` — routing ke Layar Pesanan (3.5) |
| status_aktif | BOOL | |

**`menu`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| nama | VARCHAR | |
| kode_menu | VARCHAR | UNIQUE, ditampilkan di layar KDS (bukan nama lengkap) |
| harga | DECIMAL | |
| kategori_id | UUID | FK ke `kategori_menu` |
| foto_id | UUID nullable | FK `foto` (jenis `menu`) |
| status_aktif | BOOL | toggle stok habis/tersedia |

Daftar menu/kategori untuk semua user hanya menampilkan yang aktif. Admin bisa melihat yang nonaktif lewat parameter `include_nonaktif` (supaya bisa diaktifkan lagi).

**`bahan`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| nama | VARCHAR | |
| satuan | VARCHAR | ml/gram/pcs, dll |
| isi_per_kemasan | DECIMAL | konversi kemasan besar → satuan kecil, khusus internal gudang |
| harga_rata_rata | DECIMAL | moving weighted average per satuan kecil, diperbarui saat barang masuk. **Hanya terlihat oleh Admin** (desain barang masuk masih **[PENDING]**, lihat 3.2) |
| stok_minimum_gudang | DECIMAL | ambang stok gudang (satuan kecil), dibandingkan dengan total gudang `jumlah_kemasan_besar × isi_per_kemasan + jumlah_satuan_kecil`. Peringatan: **belanja ulang** |
| stok_minimum_titik | DECIMAL | ambang stok titik (satuan dasar), dibandingkan dengan `stok_titik.jumlah` per titik dari opname terakhir. Peringatan: **ambil barang dari gudang**. Nilai 0 = peringatan titik nonaktif untuk bahan itu |

**`menu_resep`** — BOM/takaran per menu

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| menu_id | UUID | FK |
| bahan_id | UUID | FK |
| jumlah_terpakai | DECIMAL | takaran per 1 unit menu terjual |

### Foto (lintas fitur)
Semua foto (absen, izin, bukti QRIS, menu, profil) lewat **upload 2 langkah**: upload dulu ke `POST /foto` dapat `foto_id`, lalu `foto_id` dikirim di endpoint induk. Alasan: pada saat upload row induk belum ada, jadi pemilik harus tercatat di tabel `foto`.

**`foto`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| jenis | ENUM | `absensi` / `izin` / `qris` / `menu` / `profil` |
| path | VARCHAR | **path relatif** (`{uuid}.jpg`), path absolut dibentuk dari `UPLOAD_DIR` |
| uploader_id | UUID | FK `karyawan`, pemilik foto |
| dipakai | BOOL | sudah ditempel ke row induk atau belum |
| created_at | TIMESTAMP | |

**Endpoint:**
* `POST /foto` (multipart: `file`, `jenis`): semua user login, mengembalikan `{id}`. Server membatasi **maks 5 MB** (dibaca bertahap), tipe jpeg/png/webp, batas piksel (anti decompression bomb → 400), lalu foto **diputar sesuai EXIF**, di-**re-encode** ke JPEG maks sisi 1280px (Pillow), sehingga EXIF (termasuk GPS) terbuang dan file palsu ditolak. Pemrosesan gambar berjalan di thread terpisah supaya WebSocket KDS tidak tersendat. Nama file di disk = UUID. Parameter `jenis` di luar daftar → 422
* Batas **50 foto belum terpakai per user** (lebih → 429)
* `GET /foto/{id}`: stream file, wajib `Authorization`. Aturan akses:
  * `absensi`, `izin`, `qris`: Admin semua, Karyawan hanya yang `uploader_id`-nya dia. Header `Cache-Control: no-cache, no-store, must-revalidate`
  * `menu`, `profil`: semua user login (pengecualian, karena kasir harus bisa melihat foto menu). Header `private, max-age=86400`
* **Endpoint induk** menerima `foto_id`, bukan string bebas. Server memvalidasi: foto ada, `uploader_id` = user yang submit, `jenis` sesuai konteks (foto `qris` tidak bisa jadi foto absen), `dipakai` masih false lalu di-set true dalam transaksi DB yang sama dengan penyimpanan row induk (1 foto tidak bisa dipakai 2 kali)
* **Tidak ada endpoint hapus** untuk foto bukti (audit trail). Foto `menu` & `profil` diganti dengan upload baru, file lama dihapus
* Skrip pembersih menghapus row `dipakai = false` > 24 jam beserta filenya, dan file di folder upload yang tidak punya row

### 3.1 POS & Transaksi — Takaran & Selisih Stok (Poin 1)
* **Pemesanan hanya dilakukan di kasir** — kasir input langsung menu yang dipesan customer
* **Pemilihan item:** klik menu = qty 1, klik lagi = qty +1
* **Metode bayar:** Cash (kasir input nominal diterima, kembalian auto-hitung) atau QRIS statis (kasir cek mutasi manual, cocokkan nominal, tandai lunas, lampirkan foto bukti) — tanpa payment gateway
* Transaksi langsung berstatus lunas begitu kasir simpan
* **Syarat mulai POS:** kasir (karyawan dengan `area_kerja = kasir`) sedang dalam **shift berjalan** (3.4) miliknya dan sudah **absen masuk**. Opname `awal_shift` bar/kitchen **tidak** memblokir kasir, karena transaksi adalah pendapatan dan harus tetap jalan di jam sibuk
* **Stok tidak dikurangi real-time saat transaksi** — dihitung "stok terpakai teoritis" dari `menu_resep` × qty terjual, **dibandingkan** ke hasil opname aktual di Bar/Kitchen (3.2) untuk mendeteksi selisih. *(Endpoint/laporan selisih takaran ini belum didesain — **[PENDING]**; yang sudah ada baru `selisih_handover`.)*
* Begitu transaksi disimpan → **push realtime** (WebSocket) ke Layar Pesanan/KDS (3.5)
* **Snapshot HPP:** saat transaksi disimpan, sistem menghitung `hpp_satuan` per item = `Σ(menu_resep.jumlah_terpakai × bahan.harga_rata_rata)` saat itu. Menu tanpa resep = 0. Nilai tidak diubah setelahnya (termasuk saat transaksi dibatalkan)
* **Cancel/Void Transaksi:** hanya **kasir pemilik transaksi**, hanya selama shift berjalannya, dan **tanpa alasan wajib** (kasus umum: salah pilih cash vs QRIS). Admin **tidak** bisa cancel setelah transaksi terkunci
  * **Aturan kunci:** transaksi shift X terkunci setelah **semua** `stok_opname` `akhir_shift` untuk shift itu masuk. Yang dihitung: semua row `jadwal_shift` pada `tanggal` + `shift` yang sama dengan `area_kerja` `bar` atau `kitchen` (opname susulan dihitung sama). *(Penyesuaian jika satu titik boleh punya banyak staff: lihat **[PENDING]** B4.)*
  * **Fallback:** kalau tidak ada staff bar maupun kitchen yang dijadwalkan di tanggal+shift itu, transaksi terkunci saat kasir **absen pulang**
  * Status kunci **dihitung dari data opname di setiap request** (bukan flag tersimpan, tanpa kolom baru), **di-enforce di level API**
  * Transaksi yang dibatalkan **tidak di-hard-delete**: `status` jadi `dibatalkan`, tetap tersimpan untuk audit trail
  * Koreksi transaksi pasca-kunci: **[PENDING]**

**`transaksi`** — header

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| nomor_transaksi | VARCHAR | human-readable, tampil di struk |
| jadwal_shift_id | UUID | FK — konteks shift & karyawan kasir |
| kasir_id | UUID | FK karyawan yang input |
| metode_bayar | ENUM | `cash` / `qris` |
| total_harga | DECIMAL | akumulasi dari `transaksi_detail` |
| uang_diterima | DECIMAL nullable | khusus cash |
| kembalian | DECIMAL nullable | khusus cash |
| foto_bukti_qris_id | UUID nullable | FK `foto` (jenis `qris`), khusus qris |
| status | ENUM | `selesai` / `dibatalkan` |
| waktu_transaksi | TIMESTAMP | |

**`transaksi_detail`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| transaksi_id | UUID | FK |
| menu_id | UUID | FK |
| qty | INT | |
| harga_satuan | DECIMAL | snapshot harga saat transaksi |
| hpp_satuan | DECIMAL | snapshot HPP per unit saat transaksi (lihat di atas) |
| catatan | TEXT nullable | mis. "less sugar" |
| subtotal | DECIMAL | qty × harga_satuan |
| status_item | ENUM | `menunggu` / `diproses` / `selesai` — dipakai Layar Pesanan (3.5) |

### 3.2 Stok Gudang & Stok Bar/Kitchen (Poin 2)

**Konteks masalah:** Bar & Kitchen adalah titik operasional tempat staff meracik pesanan. Kalau stoknya langsung dihitung otomatis dari transaksi, selisih akibat takaran berlebih, tumpah, atau kesalahan racik tidak ketahuan. Makanya stok di titik operasional dihitung fisik langsung secara berkala.

**Prinsip utama: Stok Gudang & Stok Titik (Bar/Kitchen) sepenuhnya terpisah, TIDAK ada konversi silang**
* **Stok Gudang** — dalam satuan besar (dus/box) + sisa satuan kecil (pcs/slop) yang sudah dibuka, pakai `bahan.isi_per_kemasan` sebagai faktor konversi 1 tingkat (khusus internal gudang)
* **Stok Titik (Bar/Kitchen)** — angka independen hasil timbang/hitung fisik langsung (ml/gram/pcs sesuai kondisi nyata), **tidak dihitung/dikonversi dari data gudang**
* `barang_keluar` (transfer gudang → titik) **hanya** mengurangi `stok_gudang` + jadi bukti audit (siapa, kapan); **tidak pernah** langsung menambah `stok_titik`, karena stok titik diperbarui lewat opname fisik berikutnya
* **Peringatan stok menipis juga terpisah, tanpa penjumlahan gudang + titik.** Gudang punya `stok_minimum_gudang` dan titik punya `stok_minimum_titik`, karena beda satuan dan beda tindakan
  * Peringatan titik hanya dievaluasi untuk baris `stok_titik` yang ada (bahan yang belum pernah diopname di titik itu tidak muncul)
  * Bahan tanpa baris `stok_gudang` dianggap stok gudang 0
  * Bahan dengan `isi_per_kemasan` kosong tidak boleh punya `jumlah_kemasan_besar > 0` (divalidasi di API barang masuk)
  * *Status: disepakati, belum diimplementasi (akan satu paket migration dengan B4).*

**Mekanisme: Twin Checkpoint via `stok_opname`**
* Setiap shift **dengan `area_kerja` `bar` atau `kitchen`** wajib ada 2 kejadian opname (hitung fisik) di titiknya. Shift `kasir` **tidak punya opname**. Keduanya blocking **untuk staff bar/kitchen itu sendiri**:
  * **`awal_shift`** — sebelum karyawan bisa barang keluar atau update status KDS di shift itu. **Tidak memblokir kasir** memulai POS
  * **`akhir_shift`** — sebelum shift dianggap selesai/ditutup. Opname akhir_shift semua titik yang bertugas juga menjadi pengunci cancel transaksi (3.1)
* `akhir_shift` hanya bisa disubmit setelah `awal_shift` shift itu ada
* Opname hanya bisa disubmit karyawan yang di-assign **selama shift berjalan** (3.4). `stok_opname.karyawan_id` = karyawan yang di-assign di shift itu
* Checkpoint pembanding = **shift sebelumnya di titik yang sama secara urut waktu** ("shift sebelumnya" = shift bar/kitchen di titik itu dengan urutan `tanggal` + `jam_mulai` tepat sebelumnya, bukan sekadar opname akhir terakhir yang ada)
* **`metode` ditentukan server** (field dari client diabaikan):
  * `akhir_shift` selalu `hitung_manual`
  * `awal_shift` = **`carry_forward`** hanya jika shift sebelumnya di titik yang sama jatuh di **tanggal kalender yang sama** *dan* `akhir_shift`-nya sudah ada. Stok awal = `akhir_shift` sebelumnya + `barang_keluar` sejak itu; karyawan tinggal konfirmasi (supaya tidak antri jam sibuk)
  * selain itu **`hitung_manual`** (cross-day/overnight, atau baseline sebelumnya tidak ada): wajib hitung fisik penuh
* Selisih antara opname awal_shift (hitung_manual) vs ekspektasi (opname akhir sebelumnya + `barang_keluar`) → **otomatis** dicatat sebagai `mutasi_stok` tipe `selisih_handover` untuk review admin — **tidak blocking**. Dilewati jika baseline tidak ada
* Shift pertama di titik tsb (belum ada shift sebelumnya) → opname awal jadi baseline pertama
* Item opname dengan `bahan_id` sama dalam satu submit **dijumlahkan** sebelum disimpan dan dibandingkan

**Opname susulan (shift yang jendelanya sudah habis)**
* Kalau karyawan lupa opname dan jendela shift habis, **admin** boleh submit opname susulan untuk shift itu. Karyawan biasa mendapat 403 ("Jendela shift sudah habis, hanya admin yang dapat menyusulkan opname")
* Syarat: jendela shift sudah habis, opname di titik+tipe itu belum ada, `catatan` **wajib**, `metode` selalu `hitung_manual`. Berlaku untuk `awal_shift` maupun `akhir_shift` (shift bar/kitchen saja)
* `stok_opname.karyawan_id` tetap karyawan yang di-assign. Penginput dicatat di `diinput_oleh`, dan opname ditandai `susulan = true`
* **Tidak menimpa `stok_titik` kalau sudah ada opname shift yang lebih baru** di titik itu (urutan berdasarkan `tanggal` + `jam_mulai` shift, bukan `waktu_opname`). Detail tetap disimpan sebagai audit; respons menyertakan `stok_titik_diperbarui`. Aturan ini berlaku juga untuk alur biasa
* Opname susulan dihitung sama dengan opname biasa untuk **penguncian transaksi** (3.1)
* `GET /stok/opname-tertunda` (admin): daftar shift bar/kitchen yang jendelanya sudah habis dan belum punya opname `awal_shift` atau `akhir_shift` di titiknya
* Tidak ada kunci otomatis berbasis waktu (kunci tetap dihitung dari data opname)

**`stok_gudang`** — running balance pusat (1 gudang saja)

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| bahan_id | UUID | FK, UNIQUE |
| jumlah_kemasan_besar | INT | dus/box utuh, belum dibuka |
| jumlah_satuan_kecil | DECIMAL | sisa satuan lepas dari kemasan yang sudah dibuka |

**`stok_titik`** — running balance per titik, hasil opname terakhir

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| bahan_id | UUID | FK |
| titik | ENUM | `bar` / `kitchen` |
| jumlah | DECIMAL | saldo hasil opname terakhir, satuan sesuai kondisi fisik |

`UNIQUE(bahan_id, titik)`. **Hanya diperbarui lewat `stok_opname`**, tidak pernah lewat `barang_keluar`.

**`barang_keluar`** — transfer gudang → titik

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| titik_tujuan | ENUM | `bar` / `kitchen` |
| karyawan_id | UUID | FK — wajib, siapa yang ambil |
| waktu | TIMESTAMP | |

`barang_keluar_detail`: `id`, `barang_keluar_id` (FK), `bahan_id` (FK), `jumlah` (satuan kecil, > 0). Titik tujuan harus sama dengan `area_kerja` shift berjalan karyawan. *(Perilaku saat karyawan tanpa shift berjalan, serta pembukaan dus saat satuan kecil habis: **[PENDING]**.)*

**`barang_masuk`** — penerimaan barang di gudang *(sudah ada di implementasi; desain **[PENDING]**)*

`barang_masuk`: `id`, `karyawan_id`, `waktu`, `catatan`. `barang_masuk_detail`: `id`, `barang_masuk_id`, `bahan_id`, `jumlah_kemasan_besar`, `jumlah_satuan_kecil`, `harga_total`. Menambah `stok_gudang` dan memperbarui `bahan.harga_rata_rata` (moving weighted average dari stok sebelum penambahan).

**`stok_opname`** — header, 1 row = 1 kejadian hitung/konfirmasi

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| jadwal_shift_id | UUID | FK — shift terkait |
| titik | ENUM | `bar` / `kitchen` (harus = `area_kerja` shift) |
| tipe | ENUM | `awal_shift` / `akhir_shift` |
| metode | ENUM | `hitung_manual` / `carry_forward` (ditentukan server) |
| karyawan_id | UUID | karyawan yang di-assign di shift itu |
| diinput_oleh | UUID nullable | FK `karyawan`, siapa yang menginput (beda dari `karyawan_id` kalau susulan) |
| susulan | BOOL | default false, true kalau disubmit admin setelah jendela shift habis |
| waktu_opname | TIMESTAMP | |
| catatan | TEXT nullable | wajib untuk susulan |

`UNIQUE(jadwal_shift_id, titik, tipe)`.

**`stok_opname_detail`** — per bahan, raw hasil hitung fisik: `id`, `stok_opname_id`, `bahan_id`, `jumlah`.

Saat opname disubmit (dan belum ada opname shift lebih baru) → sistem **overwrite** `stok_titik.jumlah` untuk kombinasi bahan+titik itu.

**`mutasi_stok`** — audit selisih handover: `id`, `bahan_id`, `titik`, `jadwal_shift_id`, `tipe` (`selisih_handover`), `jumlah_selisih`, `keterangan`, `created_at`.

### 3.3 Absensi (Poin 3)
* Absen **di lokasi cafe** (1 titik GPS) — **radius GPS blocking** untuk absen masuk **dan absen pulang**: di luar radius, sistem menolak dan menampilkan "di luar radius"
* Titik koordinat & radius **editable oleh admin** lewat `GET/PUT /master/konfigurasi-lokasi` (admin saja, selalu UPDATE satu row, `updated_by` terisi, latitude -90..90, longitude -180..180, radius > 0). Tabel `konfigurasi_lokasi` didesain singleton (diisi lewat seed)
* Perubahan `konfigurasi_lokasi` dicatat ke `audit_log_konfigurasi` **hanya oleh trigger MySQL** `trg_audit_konfigurasi_lokasi` (bukan kode aplikasi, supaya tidak ganda)
* Absen masuk wajib **match `jadwal_shift`** milik karyawan yang sedang **berjalan** (3.4). Jam absen boleh lebih awal dari jam mulai shift. Ditolak jika ada izin tidak masuk yang sudah disetujui untuk shift itu
* Foto wajib saat absen masuk, lewat `foto_id` (jenis `absensi`). **Client hanya membuka kamera** (tanpa galeri) — aturan client, bukan jaminan server. EXIF dibuang server sehingga timestamp foto tidak bisa dijadikan bukti
* **Absen pulang juga ada** — bahan evaluasi kedisiplinan admin. `status_pulang = telat` jika lewat `jam_selesai` + toleransi 15 menit (konstanta), selain itu `tepat_waktu`. Absen pulang tidak dibatasi jendela shift. `lupa_absen` belum punya mekanisme otomatis — **[PENDING]**
* Keterlambatan dihitung **per menit**, dari selisih jam absen − jam mulai shift
* Potongan gaji/SP untuk keterlambatan — **[PENDING]**, menunggu hasil wawancara
* Approval izin telat, izin tidak masuk (dan tukar shift) hanya valid dari status `pending`, selain itu 409

**Izin Telat**
* Diajukan **sebelum** absen, lewat menu terpisah — karyawan submit alasan + foto opsional. Satu pengajuan `pending` per shift
* Admin approve/tolak. Begitu **disetujui** sebelum absen, karyawan absen normal — tidak dihitung telat
* Izin yang disetujui **setelah** karyawan sudah absen: **[PENDING]**

**Izin Tidak Masuk (alpa terjadwal)**
* Untuk sakit, musibah, dll — tidak ada row `absensi`. Bisa diajukan kapan saja, termasuk mendadak di hari-H
* Bukti: alasan teks + foto wajib (surat dokter, dll). Ditolak jika karyawan sudah absen masuk di shift itu. Satu pengajuan `pending` per shift
* Admin approve/tolak

**`absensi`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| karyawan_id | UUID | FK |
| jadwal_shift_id | UUID | FK, UNIQUE (1 shift = 1 absensi) |
| jam_masuk | TIMESTAMP | |
| jam_pulang | TIMESTAMP nullable | |
| lat_masuk, lng_masuk | DECIMAL | |
| lat_pulang, lng_pulang | DECIMAL nullable | |
| foto_masuk_id | UUID | FK `foto` (jenis `absensi`), wajib |
| foto_pulang_id | UUID nullable | FK `foto`; **[PENDING]** apakah wajib juga |
| menit_telat | INT | selisih jam_masuk − jadwal_shift.jam_mulai |
| izin_telat_id | UUID nullable | FK `izin_telat` kalau telat di-cover izin yang disetujui |
| status_pulang | ENUM nullable | `tepat_waktu` / `telat` / `lupa_absen` |

**`izin_telat`**: `id`, `karyawan_id`, `jadwal_shift_id`, `alasan`, `foto_id` (nullable, FK `foto` jenis `izin`), `status` (`pending`/`disetujui`/`ditolak`), `diajukan_at`, `diproses_oleh`, `diproses_at`.

**`izin_tidak_masuk`**: sama seperti `izin_telat`, tetapi `foto_id` **wajib** (NOT NULL, RESTRICT).

**Validasi radius GPS:** di-enforce di client (UX cepat) **dan** divalidasi ulang di server (koordinat client tidak dipercaya mentah-mentah).

### 3.4 Jadwal Shift (Poin 4)
* Karyawan di-assign ke **Shift 1** atau **Shift 2** — tanpa cabang/rombong
* Admin assign manual per karyawan per tanggal. Karyawan nonaktif tidak bisa dijadwalkan
* Validasi bentrok: 1 karyawan tidak boleh 2 shift di tanggal sama
* `jam_selesai` harus lebih besar dari `jam_mulai` (shift yang melewati tengah malam belum didukung; cafe tutup sekitar 23:00)
* **Setiap shift wajib punya `area_kerja`: `kasir` / `bar` / `kitchen`** — 1 shift = 1 area kerja untuk karyawan itu. Konsekuensi lintas fitur:
  * Kasir POS (3.1): `transaksi.kasir_id` harus karyawan dengan `area_kerja = kasir` pada shift berjalannya
  * Stok Opname (3.2): `stok_opname.titik` harus sama dengan `area_kerja`. Shift `kasir` tidak punya opname
  * Barang Keluar (3.2): `titik_tujuan` harus sama dengan `area_kerja` karyawan
  * Validasi dilakukan di **level API** (bukan constraint database, karena lintas tabel)
* **Shift berjalan** (dipakai semua fitur untuk menentukan "shift aktif"; satu service `get_shift_berjalan`): `now` berada di antara `tanggal` 00:00 dan `tanggal + jam_selesai + toleransi` (default **3 jam**, konstanta config). Bukan perbandingan `tanggal = hari ini`, karena shift 2 bisa selesai setelah 00:00. Kandidat: shift karyawan hari ini atau kemarin. Jika dua kandidat valid sekaligus (mis. 01:00), dipilih shift kemarin hanya jika belum ada `absensi.jam_pulang`, selain itu shift hari ini. Dipakai oleh absen masuk, POS, cancel, opname, dan barang keluar
* Jadwal hanya terlihat milik sendiri untuk Karyawan (Admin melihat semua). Jadwal karyawan **lain** hanya terlihat lewat endpoint khusus tukar shift pada tanggal yang dipilih

**`shift_template`** — preset jam per shift (default saat assign, bisa override): `id`, `shift` (`shift_1`/`shift_2`, UNIQUE), `jam_mulai`, `jam_selesai`.

**`jadwal_shift`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| karyawan_id | UUID | FK |
| tanggal | DATE | |
| shift | ENUM | `shift_1` / `shift_2` |
| area_kerja | ENUM | `kasir` / `bar` / `kitchen` |
| shift_template_id | UUID nullable | FK, jejak referensi |
| jam_mulai, jam_selesai | TIME | snapshot dari template atau manual |
| dibuat_oleh | UUID | FK admin |

Constraint: `UNIQUE(karyawan_id, tanggal)`. *(Jumlah karyawan yang boleh berbagi satu tanggal+shift+area: **[PENDING]** B4.)*

**Swap Shift**
* Karyawan mengajukan tukar shift dengan karyawan lain, **hanya untuk tanggal yang sama** dan belum lewat
* Validasi saat **pengajuan:** pengaju pemilik shift A, target pemilik shift B, bukan diri sendiri, dan tidak ada pengajuan `pending` lain yang memakai shift A atau B (409)
* Admin approve/tolak. Validasi ulang saat **approval** (409 jika gagal): kepemilikan masih sama, tanggal belum lewat, kedua shift belum punya `absensi`, dan tidak ada izin telat/tidak masuk `pending`/`disetujui` di kedua shift. Row dikunci (`with_for_update`), swap dan update status dalam satu transaksi
* Begitu disetujui, `karyawan_id` di kedua row `jadwal_shift` ditukar — jam & `area_kerja` ikut karena menempel ke row shift
* Persetujuan karyawan target (selain admin): **[PENDING]**

**`tukar_shift`**: `id`, `shift_a_id`, `shift_b_id` (wajib beda row), `karyawan_pengaju_id`, `karyawan_target_id`, `status`, `alasan`, `diajukan_at`, `diproses_oleh`, `diproses_at`.

**Request Off**
* **Cuma pengajuan**, tanpa approval — admin melihat lalu membuat jadwal libur sendiri (tidak membuatkan row `jadwal_shift` di tanggal itu)
* **Semua karyawan bisa melihat semua pengajuan** supaya bisa menghindari bentrok
* `UNIQUE(karyawan_id, tanggal)`, tanggal masa lalu ditolak

**`request_off`**: `id`, `karyawan_id`, `tanggal`, `alasan`, `diajukan_at`.

### 3.5 Layar Pesanan / KDS (Poin 5)
* Begitu `transaksi` disimpan → sistem kelompokkan tiap `transaksi_detail` berdasarkan `kategori_menu.area_produksi`
* `kitchen` → **push realtime ke layar TV di lantai 2 (kitchen)**, tampilkan **kode_menu + qty + catatan**
* `bar` (minuman) → **belum ada layar TV**, mekanisme **[PENDING observasi]** (kemungkinan app HP/tablet)
* Staff kitchen update `status_item` (menunggu → diproses → selesai) dari layar/perangkat KDS

### 3.6 Reporting & Pengeluaran (Poin 6)
Admin bisa melihat penghasilan per hari/range/bulan/tahun. Formula profit harian:

```
Profit Harian = Penjualan Hari Itu
                − HPP (Σ hpp_satuan × qty dari transaksi `selesai` hari itu)
                − Σ(pengeluaran tipe `bulanan` yang berlaku bulan itu ÷ jumlah hari di bulan itu)
                − Σ(pengeluaran tipe `mendadak` yang tanggalnya = hari itu)
```

**Prinsip kunci (anti double-count):** pembelian bahan baku ke gudang **tidak** dihitung sebagai pengeluaran terpisah — cukup dicatat sebagai histori di Stok Gudang (3.2). HPP murni dari snapshot resep × penjualan.

**HPP dari snapshot** `transaksi_detail.hpp_satuan` (bukan on-demand): laporan tanggal lama tidak berubah saat `harga_rata_rata` atau resep berubah. Transaksi lama sebelum fitur ini di-backfill sekali dengan harga rata-rata saat itu (perkiraan). `menu_tanpa_resep` tetap dihitung dari resep saat laporan dibuat. Tanggal default laporan dievaluasi per request (bukan saat server start).

**Input Pengeluaran — kategori fleksibel, 2 tipe:**
* Kategori **bukan ENUM fixed** — admin menambah sendiri (`kategori_pengeluaran`)
* Tiap entry punya `tipe`: **`bulanan`** (dicatat 1x per bulan, dipecah rata ÷ jumlah hari bulan itu) atau **`mendadak`** (one-time, dicatat penuh di tanggal kejadian)

**`kategori_pengeluaran`**: `id`, `nama` (UNIQUE), `status_aktif`.

**`pengeluaran`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| kategori_id | UUID | FK |
| tipe | ENUM | `bulanan` / `mendadak` |
| nominal | DECIMAL | > 0 |
| bulan | DATE nullable | wajib jika `bulanan` (dan `tanggal` kosong) |
| tanggal | DATE nullable | wajib jika `mendadak` (dan `bulan` kosong) |
| keterangan | TEXT | |
| dicatat_oleh | UUID | FK admin |
| created_at | TIMESTAMP | |

**Laporan lain:**
* Breakdown pengeluaran per kategori, filter Harian / Range / Bulanan / Tahunan
* **Reminder stok menipis** (admin): `GET /bahan/stok-menipis` mengembalikan dua daftar terpisah
  * `gudang` (jenis `belanja_ulang`): bahan dengan total gudang < `stok_minimum_gudang`. Field: bahan, total gudang (satuan kecil), ambang
  * `titik` (jenis `ambil_dari_gudang`): baris bahan+titik dengan `jumlah` < `stok_minimum_titik`. Field: bahan, titik, jumlah, ambang, `diperbarui_at` (waktu opname terakhir)
  * Bahan bisa muncul di kedua daftar sekaligus
* Profit range/bulan/tahun: **[PENDING]** (baru profit harian yang ada)

## 4. Role & Hak Akses

**Struktur role:** 2 macam — **Karyawan** dan **Admin**. Tidak ada role Owner dan tidak ada role read-only (satu cafe, mitra yang ingin memantau memakai akun admin atau layar bersama). Role selalu dibaca dari database pada setiap request, **bukan dari isi token**.

**Prinsip akses foto:** foto bukti (`absensi`, `izin`, `qris`) → Admin lihat semua, Karyawan **hanya yang dia sendiri upload** (`foto.uploader_id`). **Pengecualian:** foto `menu` dan `profil` bisa dilihat semua user login. Semua foto hanya lewat `GET /foto/{id}` dengan autentikasi, tidak ada URL statis.

### 4.1 Karyawan (Operasional Harian & Self-Service)

**Operasional harian (shift berjalan miliknya):**
* Absensi di radius cafe, ajukan izin telat/izin tidak masuk, lihat status pengajuan sendiri *(endpoint riwayat milik sendiri belum ada — **[PENDING]**)*
* POS: buat transaksi + cancel transaksi. Cancel hanya untuk transaksi miliknya sendiri, selama shift berjalan, dan belum terkunci (aturan kunci di 3.1)
* Stok opname awal_shift & akhir_shift — **khusus karyawan dengan `area_kerja` bar/kitchen**
* `barang_keluar` — ambil barang gudang → titik (bar/kitchen)
* KDS: update `status_item` di perangkat yang jadi tanggung jawabnya
* Melihat stok gudang & stok titik (tanpa `harga_rata_rata`)

**Swap Shift & Request Off — exception visibility:**
* Ajukan swap shift — boleh lihat jadwal karyawan **lain** di tanggal yang sama untuk memilih target
* Request off — boleh lihat **semua** pengajuan request off

**Laporan Shift Aktif** *(read-only, on-demand query dari `transaksi`/`transaksi_detail` WHERE `jadwal_shift_id` = shift berjalan, tanpa tabel/kolom baru; **belum diimplementasi**)*:
* Total pendapatan, jumlah transaksi, rincian per metode bayar (cash/QRIS) selama shift berjalan
* Tujuan: sanity check mandiri sebelum transaksi shift terkunci (3.1) dan sebelum absen pulang
* Scope ketat: hanya shift yang sedang berjalan

**Profil:** edit profil sendiri (foto profil via `foto_id`, nomor HP, dll) — langsung tanpa lewat Admin

### 4.2 Admin (Back-Office & Operasional Penuh)

**Akses modul penuh:** 100% dari 6 fitur, termasuk laporan Profit Harian & Pengeluaran (3.6), CRUD master data (menu, kategori_menu, bahan, menu_resep, kategori_pengeluaran), `harga_rata_rata`, barang masuk, mutasi stok

**Konfigurasi operasional:** titik koordinat & radius GPS absen (3.3), jam `shift_template`

**Opname susulan:** submit opname untuk shift yang jendelanya sudah habis (catatan wajib) dan melihat daftar opname tertunda (3.2)

**Manajemen Karyawan — terbatas ke role `Karyawan`:** buat akun Karyawan, ubah data, soft-disable akun Karyawan yang resign

**Approval operasional:** swap shift (3.4), izin telat & izin tidak masuk (3.3)

**Batasan Sistem (blocking via validasi API):** Admin **tidak bisa** membuat akun `admin`, mengubah role seorang `Karyawan` menjadi `admin` (payload `role` ditolak/diabaikan), atau mengubah kredensial/menonaktifkan akun `admin` lain (termasuk akun miliknya sendiri) → 403

### 4.3 Akun Admin (tanpa Owner)
* Akun Admin **di-seed manual lewat script** `seed_admin.py` (idempoten, password dari env/prompt, tanpa hardcode). **Tidak ada endpoint** pembuatan admin. Admin tambahan juga dibuat lewat script
* Pemulihan akses (lupa password) lewat `reset_password.py <email>` yang dijalankan di PC server (pemilik server punya akses fisik)
* `seed_dummy.py` hanya untuk development, tidak dijalankan di produksi
* Role `owner` sudah dihapus: baris `owner` lama dimigrasi jadi `admin`, ENUM `karyawan.role` = (`karyawan`, `admin`), token lama berisi role `owner` tidak berlaku karena role dibaca dari database

## 5. Skema Database — Optimasi

### 5.1 Karakter Set & Collation
* `utf8mb4` di semua tabel
* **Collation eksplisit `utf8mb4_unicode_ci`** di level **database**, dijalankan sekali sebelum migration: `ALTER DATABASE db_kyfein CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`. Alasan: default collation beda antara MySQL 8 dan MariaDB

### 5.2 Indexing — 2 lapis
* **Lapis 1 (otomatis):** semua FK eksplisit → InnoDB membuat index untuk tiap kolom FK
* **Lapis 2 (composite index):**
  * `transaksi(status, waktu_transaksi)` — reporting/profit harian
  * `stok_opname(titik, tipe)` — opname terakhir per titik
  * `absensi(karyawan_id, jam_masuk)` — riwayat absensi per karyawan
  * `pengeluaran(kategori_id, tipe)` — breakdown per kategori
  * `foto(dipakai, created_at)` — pembersihan foto yatim
* Index single-column yang sudah ada (status, tanggal, area_kerja, dst) tetap dipertahankan

### 5.3 Constraint (CHECK)
Semua nilai numerik yang tidak boleh negatif dikunci `CHECK (... >= 0)` atau `> 0`: `menu.harga`, `stok_gudang.*`, `stok_titik.jumlah`, `menu_resep.jumlah_terpakai`, `barang_keluar_detail.jumlah`, `transaksi.total_harga`, `transaksi_detail.qty`, `transaksi_detail.hpp_satuan`, `pengeluaran.nominal`, `bahan.stok_minimum_titik`. Plus 2 CHECK kondisional: `transaksi.chk_bukti_bayar` (cash → `uang_diterima` terisi, qris → `foto_bukti_qris_id` terisi) dan `pengeluaran.chk_pengeluaran_periode`.

### 5.4 Strategi Backup (level database)
* **Metode:** `mysqldump` terjadwal — cocok untuk 1 cafe/1 database
* **Jadwal:** dump harian di luar jam sibuk (mis. 03:00) via **Windows Task Scheduler** yang menjalankan `.bat` berisi `mysqldump`
* **Retensi:** 30 hari dump harian + 1 dump mingguan disimpan 3 bulan; dump lama dihapus otomatis oleh script yang sama
* **Lokasi:** tidak boleh hanya di PC server — minimal disalin ke folder yang di-sync ke cloud (Google Drive Desktop/OneDrive) atau eksternal drive terpisah
* **Folder foto** ikut dibackup ke lokasi yang sama, karena kolom di DB hanya menyimpan referensi `foto_id`
* **Verifikasi:** restore-test ke database sementara berkala (mis. 1x/bulan)

### 5.5 Yang sengaja TIDAK dipakai
* **Partitioning** — skala 1 cafe belum butuh; revisit kalau data tahunan jutaan baris
* **Read replica / clustering** — di luar scope infrastruktur 1 PC

### 5.6 Perubahan skema setelah versi awal
* Tabel baru `foto` (3.0). Kolom lama diganti jadi FK ke `foto(id)`, `ON DELETE SET NULL` kecuali yang wajib (`RESTRICT`):
  * `absensi.foto_masuk` → `foto_masuk_id` (NOT NULL), `foto_pulang` → `foto_pulang_id`
  * `izin_telat.foto_url` → `foto_id`, `izin_tidak_masuk.foto_url` → `foto_id` (NOT NULL)
  * `transaksi.foto_bukti_qris` → `foto_bukti_qris_id`
  * `menu.foto` → `foto_id`, `karyawan.foto_profile` → `foto_profile_id`
* `foto.path` menyimpan path relatif
* `transaksi_detail.hpp_satuan DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (>= 0)`
* `bahan.harga_rata_rata`; tabel `barang_masuk` dan `barang_masuk_detail`
* `request_off`: `UNIQUE(karyawan_id, tanggal)`
* `stok_opname.susulan` (BOOL, default false) dan `stok_opname.diinput_oleh` (FK `karyawan`, `ON DELETE SET NULL`)
* `karyawan.role` ENUM('karyawan','admin')
* **Disepakati, belum diimplementasi:** `bahan.stok_minimum` diganti nama menjadi `stok_minimum_gudang` (nilai lama dipertahankan) + kolom baru `stok_minimum_titik DECIMAL(10,3) NOT NULL DEFAULT 0 CHECK (>= 0)`. Migration idempoten
* Migration berurutan: v6 (`hpp_satuan`, backfill hanya saat kolom baru ditambahkan, aman diulang), v7 (path foto relatif), `request_off` (cek duplikat dulu, berhenti jika ada), `opname_susulan`, `hapus_owner`. Verifikasi bahwa instalasi baru dari `schema_kyfein_mysql.sql` identik dengan hasil migration berurutan **belum dilakukan** (tidak mendesak selama ada backup DB)

---

> **Status:** Siap untuk pengembangan lanjutan endpoint. Item **[PENDING]** sengaja ditunda, bukan terlewat.

## Log Keputusan
- [FIX] Pemesanan **hanya di kasir** — QR code/web ordering pelanggan dihapus dari scope
- [FIX] Scope dikunci ke **6 fitur utama**: POS+Takaran (3.1), Stok Gudang (3.2), Absensi (3.3), Jadwal Shift (3.4), Layar Pesanan/KDS (3.5), Reporting (3.6)
- [FIX] Stack: FastAPI + Flutter (APK Android, Flutter Web untuk iOS/PC) + on-premise PC server (Laragon, Nginx, MySQL/MariaDB)
- [FIX] Realtime pakai FastAPI WebSocket native
- [FIX] Payment: Cash & QRIS statis, konfirmasi manual kasir, tanpa payment gateway
- [FIX] Stok Gudang vs Stok Titik terpisah total, twin-checkpoint opname per shift (awal/akhir, carry_forward vs hitung_manual)
- [FIX] Absensi: 1 titik GPS, ada absen pulang, izin telat & izin tidak masuk dengan approval admin
- [FIX] Jadwal: shift 1/2 langsung, tanpa cabang/rombong, swap shift (approval admin), request off (tanpa approval, visible semua karyawan)
- [FIX] Layar Pesanan kitchen: kode_menu + notes, realtime via WebSocket
- [FIX] Formula Reporting: Profit Harian = Penjualan − HPP − Pengeluaran bulanan (dipecah harian) − pengeluaran mendadak
- [FIX] Input Pengeluaran: kategori fleksibel + 2 tipe (`bulanan` dipecah harian, `mendadak` di tanggal kejadian)
- [FIX] Implementasi database: semua FK eksplisit dengan `ON DELETE` jelas; `jadwal_shift.area_kerja`; tabel pendukung (`shift_template`, `tukar_shift`, `request_off`, `konfigurasi_lokasi`, `audit_log_konfigurasi`) didokumentasikan
- [FIX] Optimasi skema (bagian 5): collation `utf8mb4_unicode_ci`, composite index, CHECK constraint, backup `mysqldump` harian terjadwal, partitioning & replica tidak dipakai
- [FIX] Penguncian cancel transaksi & peran kasir: kasir tidak punya opname. Transaksi terkunci setelah semua opname akhir_shift bar/kitchen di tanggal+shift yang sama masuk (fallback: absen pulang kasir). Opname awal_shift tidak memblokir POS; syarat mulai POS = absen masuk di shift berjalan. Admin juga tidak bisa cancel setelah terkunci. Dihitung dari data opname per request, di-enforce di API, tanpa kolom baru
- [FIX] HTTPS & foto: HTTPS via domain asli + Let's Encrypt DNS-01 (win-acme) menunjuk ke IP lokal. Foto di disk luar webroot, upload 2 langkah (`POST /foto` → `foto_id`), tabel `foto` dengan `uploader_id` sebagai pemilik, re-encode JPEG 1280px (buang EXIF, putar sesuai EXIF), akses via `GET /foto/{id}` per jenis, tanpa endpoint hapus foto bukti, pembersihan foto yatim 24 jam, batas 50 foto belum terpakai per user. Foto absen: client hanya kamera. Folder foto ikut backup
- [FIX] Snapshot HPP per item (`hpp_satuan`) menggantikan HPP on-demand
- [FIX] Rute di bawah `/api/v1`; konfigurasi lokasi lewat endpoint admin dengan audit oleh trigger saja
- [FIX] Aturan swap shift diperketat (validasi pengajuan dan approval, row dikunci); approval izin/tukar shift hanya dari status `pending`; `request_off` unik per karyawan+tanggal
- [FIX] **Shift berjalan** (toleransi 3 jam) menggantikan perbandingan `tanggal = hari ini`, karena cafe tutup sekitar 23:00 dan kadang lebih. Satu service dipakai absen masuk, POS, cancel, opname, barang keluar
- [FIX] Opname susulan: admin boleh submit opname untuk shift yang jendelanya habis (catatan wajib, `susulan` + `diinput_oleh`, selalu `hitung_manual`). Tidak menimpa `stok_titik` kalau sudah ada opname shift lebih baru. `carry_forward` ditolak kalau `akhir_shift` shift sebelumnya belum ada. Tanpa kunci otomatis berbasis waktu. Ada `GET /stok/opname-tertunda`
- [FIX] `metode` opname ditentukan server; `akhir_shift` selalu `hitung_manual`; `awal_shift` harus ada sebelum `akhir_shift`; item bahan duplikat dijumlahkan
- [FIX] Stok minimum dipisah: `stok_minimum_gudang` (belanja ulang) dan `stok_minimum_titik` (ambil dari gudang). `stok-menipis` mengembalikan dua daftar. Tanpa penjumlahan gudang + titik *(belum diimplementasi)*
- [FIX] **Role Owner dihapus**: hanya Karyawan dan Admin, tanpa role read-only. Admin di-seed lewat script, tidak ada endpoint pembuat admin, admin tidak bisa membuat/mengubah/menonaktifkan admin lain, role dibaca dari database per request, reset password lewat script di server
- [FIX] Pengujian: 47 test lulus (`pytest`), test memakai fixture jam (`mock_time_at`) agar mengikuti aturan shift berjalan
- [PENDING] **B4:** boleh tidak lebih dari satu orang pada (tanggal, shift, area_kerja) yang sama? Opsi: (a) maksimal 1 orang, (b) banyak orang tapi opname satu kali per (tanggal, shift, titik). Menentukan aturan kunci, fallback kasir, dan unik opname
- [PENDING] Barang masuk (`harga_rata_rata`, validasi), barang keluar (buka dus saat satuan kecil habis, perilaku tanpa shift berjalan)
- [PENDING] `lupa_absen`, izin telat yang disetujui setelah absen, `foto_pulang` wajib atau tidak
- [PENDING] Persetujuan karyawan target pada swap shift
- [PENDING] Mekanisme koreksi transaksi pasca-kunci
- [PENDING] Laporan selisih takaran (stok teoritis vs hasil opname) dan laporan shift aktif
- [PENDING] Profit range/bulan/tahun, riwayat absensi & izin milik sendiri, edit/hapus jadwal, edit bahan/resep/pengeluaran
- [PENDING] Potongan telat/SP — menunggu hasil wawancara
- [PENDING] Layar/app antrian minuman di Bar — menunggu observasi
- [PENDING] Remote access (Cloudflare Tunnel/Tailscale), domain, redundansi PC server
- [PENDING] Test untuk opname susulan, `opname-tertunda`, skenario waktu 00:30/01:59/02:01, konfigurasi lokasi; verifikasi skema SQL vs migration berurutan
