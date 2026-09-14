# Rencana Pengembangan Sistem — Kyfein (Cafe POS System)

> Dokumen ini dicatat progresif seiring diskusi berjalan. Setiap keputusan dicatat setelah disepakati (bukan draft/usulan). **Pemesanan hanya dilakukan di kasir** (tanpa QR code/web ordering pelanggan). Scope hanya 6 fitur utama di bawah, untuk 1 cafe (1 lokasi, 1 owner).

---

## 1. Tech Stack

### 1.1 Infrastruktur & Jaringan
* **Perangkat:** PC Lokal (On-Premise) sebagai server — bukan cloud/VPS
* **Jaringan:** IP Lokal Statis. Semua perangkat klien (HP/tablet kasir, tablet bar, layar KDS kitchen) wajib berada di jaringan WiFi cafe yang sama
* **Remote Akses (opsional):** Cloudflare Tunnel atau Tailscale — gratis, aman, bisa pakai domain custom (mis. `kasir.cafe`) kalau owner/mitra perlu pantau dari luar jaringan cafe

### 1.2 Lingkungan Server (di PC)
* **Software utama:** Laragon (Windows)
* **Web server:** Nginx — serve frontend (Flutter Web build) sekaligus reverse proxy ke backend FastAPI
* **Database:** MySQL / MariaDB (bawaan Laragon)

### 1.3 Backend & API
* **Bahasa/Framework:** Python + **FastAPI**
* **Server:** Uvicorn (async, tahan beban tinggi), auto-generate dokumentasi API (Swagger)
* **Realtime:** FastAPI WebSocket native — dipakai untuk push realtime transaksi ke Layar Pesanan/KDS

### 1.4 Frontend (Klien Android, iOS, PC)
* **Bahasa/Framework:** Flutter — 1 codebase untuk semua interface (Kasir, KDS, Admin)
* **Klien Android:** build jadi APK, diinstal di HP/tablet staff (kasir, KDS bar/kitchen)
* **Klien iOS / PC:** build jadi **Flutter Web**, di-hosting di folder Laragon (`www`/`htdocs`), dilayani via Nginx di jaringan lokal — 100% gratis tanpa sewa hosting

## 2. Infrastruktur & Deployment
* Server jalan di PC lokal cafe, aktif selama jam operasional
* Semua device klien connect ke WiFi cafe yang sama dengan PC server
* Remote akses (opsional) pakai Cloudflare Tunnel/Tailscale — detail domain & setup masih **pending**, dibahas di sesi terpisah
* Backup database & strategi kalau PC server mati/rusak — **pending**, belum dibahas

## 3. Rencana Fitur

### 3.0 Master Data
**`kategori_menu`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| nama | VARCHAR | mis. "Makanan", "Minuman" |
| area_produksi | ENUM | `bar` / `kitchen` — dipakai routing ke Layar Pesanan (3.5) |
| status_aktif | BOOL | |

**`menu`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| nama | VARCHAR | |
| kode_menu | VARCHAR | ditampilkan di layar KDS (bukan nama lengkap) |
| harga | DECIMAL | |
| kategori_id | UUID | FK ke `kategori_menu` |
| foto | TEXT nullable | |
| status_aktif | BOOL | toggle stok habis/tersedia |

**`bahan`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| nama | VARCHAR | |
| satuan | VARCHAR | ml/gram/pcs, dll |
| isi_per_kemasan | INT | konversi kemasan besar → satuan kecil, khusus internal gudang |
| stok_minimum | DECIMAL | untuk reminder stok menipis di Reporting |

**`menu_resep`** — BOM/takaran per menu (dasar Poin 1: POS + selisih stok)

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| menu_id | UUID | FK |
| bahan_id | UUID | FK |
| jumlah_terpakai | DECIMAL | takaran per 1 unit menu terjual |

### 3.1 POS & Transaksi — Takaran & Selisih Stok (Poin 1)
* **Pemesanan hanya dilakukan di kasir** — kasir input langsung menu yang dipesan customer (tanpa QR/web ordering pelanggan)
* **Pemilihan item:** klik menu = qty 1, klik lagi = qty +1
* **Metode bayar:** Cash (kasir input nominal diterima, kembalian auto-hitung) atau QRIS statis (kasir cek mutasi manual, cocokkan nominal, tandai lunas) — tanpa payment gateway
* Transaksi langsung berstatus lunas begitu kasir simpan (karena pembayaran terjadi bersamaan dengan input pesanan di kasir)
* **Stok tidak dikurangi real-time saat transaksi** — dihitung "stok terpakai teoritis" dari `menu_resep` × qty terjual, **dibandingkan** ke hasil stok opname aktual di Bar/Kitchen (3.2) untuk mendeteksi selisih (porsi kelebihan takar, tumpah, dll)
* Begitu transaksi disimpan → **push realtime** (FastAPI WebSocket) ke Layar Pesanan/KDS (3.5)
* **Cancel/Void Transaksi:** kasir bisa cancel transaksi miliknya sendiri (kasus umum: salah pilih metode bayar cash vs QRIS), **tanpa alasan wajib**, tapi dibatasi hanya boleh **sebelum `stok_opname` akhir_shift shift terkait disubmit** — begitu opname akhir_shift sudah masuk, transaksi shift itu terkunci, tidak bisa dicancel lagi. Transaksi yang dibatalkan **tidak di-hard-delete** — `status` diubah jadi `dibatalkan`, tetap tersimpan untuk audit trail. Validasi batas waktu ini **di-enforce di level API**, bukan cuma disembunyikan di UI

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
| foto_bukti_qris | TEXT nullable | khusus qris |
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
| catatan | TEXT nullable | mis. "less sugar", request customer |
| subtotal | DECIMAL | qty × harga_satuan |
| status_item | ENUM | `menunggu` / `diproses` / `selesai` — dipakai Layar Pesanan (3.5) |

### 3.2 Stok Gudang & Stok Bar/Kitchen (Poin 2)

**Konteks masalah:** Bar & Kitchen adalah titik operasional yang dipakai staff sehari-hari untuk meracik pesanan. Kalau stoknya langsung "dihitung otomatis" dari transaksi (dikurangi tiap kali ada penjualan), selisih akibat takaran berlebih, tumpah, atau kesalahan racik jadi tidak ketahuan — datanya cuma ikut asumsi sistem, bukan kondisi fisik asli. Makanya stok di titik operasional harus dihitung fisik langsung secara berkala, bukan hasil kalkulasi otomatis.

**Prinsip utama: Stok Gudang & Stok Titik (Bar/Kitchen) sepenuhnya terpisah, TIDAK ada konversi silang**
* **Stok Gudang** — dikelola dalam satuan besar (dus/box) + sisa satuan kecil (pcs/slop) yang sudah dibuka, pakai `bahan.isi_per_kemasan` sebagai faktor konversi 1 tingkat (khusus internal gudang saja)
* **Stok Titik (Bar/Kitchen)** — angka independen hasil timbang/hitung fisik langsung di lapangan (ml/gram/pcs campur sesuai kondisi nyata), **tidak dihitung/dikonversi dari data gudang** — karyawan ambil barang dari gudang, bawa ke Bar/Kitchen, lalu langsung ditimbang ulang jadi angka baru yang berdiri sendiri
* `barang_keluar` (transfer gudang → titik) **hanya** mengurangi `stok_gudang` + jadi bukti audit (siapa yang ambil, kapan); **tidak pernah** langsung menambah `stok_titik` — karena stok titik akan langsung diperbarui lewat opname fisik berikutnya yang sudah otomatis include barang baru itu

**Mekanisme: Twin Checkpoint via `stok_opname`**
* Setiap shift **wajib** ada 2 kejadian opname (hitung fisik), keduanya **blocking**:
  * **`awal_shift`** — sebelum karyawan bisa mulai transaksi POS shift itu
  * **`akhir_shift`** — sebelum shift dianggap selesai/ditutup di sistem
* Checkpoint pembanding = **shift sebelumnya di titik yang sama secara urut waktu**
* **Metode opname dibedakan otomatis** berdasarkan apakah shift sebelumnya & shift ini di tanggal kalender yang sama atau beda:
  * **`carry_forward`** (same-day handover, mis. shift 1 → shift 2 di hari yang sama) — **tidak perlu hitung fisik satu-satu** (supaya tidak antri pas jam sibuk). Stok awal shift 2 = auto-carry dari `akhir_shift` shift 1 + transfer masuk yang dibawa shift 2. Karyawan shift 2 tinggal **konfirmasi terima** (1 tap)
  * **`hitung_manual`** (cross-day/overnight, ada gap unattended semalaman) — **wajib hitung fisik penuh**, karena ini titik paling rawan selisih
* Selisih antara opname awal_shift vs ekspektasi (opname akhir_shift sebelumnya + transfer masuk tercatat) → **otomatis** tercatat sebagai `mutasi_stok` tipe `selisih_handover` untuk review admin — **tidak blocking** kerja
* Shift pertama di titik tsb (belum ada shift sebelumnya) → opname awal jadi baseline pertama, tanpa pembanding

**`stok_gudang`** — running balance pusat (1 gudang saja)

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| bahan_id | UUID | FK, UNIQUE |
| jumlah_kemasan_besar | INT | dus/box utuh, belum dibuka |
| jumlah_satuan_kecil | DECIMAL | sisa satuan lepas (pcs/slop) dari kemasan besar yang sudah dibuka |

**`stok_titik`** — running balance per titik, hasil opname terakhir

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| bahan_id | UUID | FK |
| titik | ENUM | `bar` / `kitchen` |
| jumlah | DECIMAL | saldo hasil opname terakhir, satuan campur sesuai kondisi fisik |

`UNIQUE(bahan_id, titik)`. **Hanya pernah di-update lewat `stok_opname`** (awal_shift maupun akhir_shift) — tidak pernah lewat `barang_keluar` langsung.

**`barang_keluar`** — transfer gudang → titik

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| titik_tujuan | ENUM | `bar` / `kitchen` |
| karyawan_id | UUID | FK — wajib, siapa yang ambil |
| waktu | TIMESTAMP | |

**`barang_keluar_detail`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| barang_keluar_id | UUID | FK |
| bahan_id | UUID | FK |
| jumlah | DECIMAL | nominal yang diambil (satuan kecil) |

**`stok_opname`** — header, 1 row = 1 kejadian hitung/konfirmasi per shift

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| jadwal_shift_id | UUID | FK — shift terkait |
| titik | ENUM | `bar` / `kitchen` |
| tipe | ENUM | `awal_shift` / `akhir_shift` |
| metode | ENUM | `hitung_manual` (cross-day, wajib hitung fisik) / `carry_forward` (same-day, tinggal konfirmasi) |
| karyawan_id | UUID | wajib = karyawan yang assigned di shift itu |
| waktu_opname | TIMESTAMP | |
| catatan | TEXT nullable | |

**`stok_opname_detail`** — per bahan, raw hasil hitung fisik (tidak dikonversi, biar audit trail sesuai kondisi asli)

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| stok_opname_id | UUID | FK |
| bahan_id | UUID | FK |
| jumlah | DECIMAL | hasil hitung fisik, satuan dasar (ml/gram/pcs) |

Saat opname disubmit → sistem hitung total per bahan, lalu **overwrite** `stok_titik.jumlah` untuk kombinasi bahan+titik itu.

### 3.3 Absensi (Poin 3)
* Absen **di lokasi cafe** (1 titik GPS saja, karena cafe tidak berpindah) — **radius GPS blocking**, bukan sekadar warning: di luar radius, sistem menolak absen dan menampilkan notifikasi "di luar radius"
* Titik koordinat & radius cafe **editable oleh admin**, bukan hardcode
* Wajib **match `jadwal_shift`** — karyawan hanya bisa absen kalau ada jadwal di tanggal itu. Jam absen bebas (boleh datang lebih awal dari jam mulai shift)
* Foto wajib saat absen masuk
* **Absen pulang juga ada** — admin bisa evaluasi karyawan yang sering pulang telat/lupa absen pulang, jadi bahan evaluasi kedisiplinan
* Keterlambatan dihitung **per menit**, dari selisih jam absen − jam mulai shift
* Potongan gaji/SP untuk keterlambatan — **pending**, menunggu hasil wawancara

**Izin Telat**
* Diajukan **sebelum** absen, lewat menu terpisah (bukan form absen) — karyawan submit alasan (macet, ban bocor, motor mogok, dll) + foto opsional/bebas
* Admin approve/tolak
* Begitu izin **disetujui**, karyawan tetap absen normal saat hadir — tidak dihitung telat berapa pun jam absennya

**Izin Tidak Masuk (alpa terjadwal)**
* Untuk kasus sakit, musibah keluarga, dll — karyawan tidak hadir sama sekali (tidak ada row `absensi`)
* Bisa diajukan **kapan saja**, termasuk mendadak di hari-H
* Bukti: alasan teks + foto (surat dokter, bukti musibah, dll)
* Admin approve/tolak

**`absensi`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| karyawan_id | UUID | FK |
| jadwal_shift_id | UUID | FK — wajib match |
| jam_masuk | TIMESTAMP | |
| jam_pulang | TIMESTAMP nullable | |
| lat_masuk, lng_masuk | DECIMAL | |
| lat_pulang, lng_pulang | DECIMAL nullable | |
| foto_masuk | TEXT | wajib |
| foto_pulang | TEXT nullable | pending — apakah wajib juga |
| menit_telat | INT | dari selisih jam_masuk − jadwal_shift.jam_mulai |
| izin_telat_id | UUID nullable | FK ke `izin_telat` kalau telat ini di-cover izin yang sudah disetujui |
| status_pulang | ENUM | `tepat_waktu` / `telat` / `lupa_absen` — dasar evaluasi admin |

**`izin_telat`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| karyawan_id, jadwal_shift_id | UUID | FK |
| alasan | TEXT | |
| foto | TEXT nullable | opsional/bebas |
| status | ENUM | `pending` / `disetujui` / `ditolak` |
| diajukan_at, diproses_oleh, diproses_at | | |

**`izin_tidak_masuk`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| karyawan_id, jadwal_shift_id | UUID | FK |
| alasan | TEXT | sakit, musibah, dll |
| foto | TEXT | surat dokter/bukti lain |
| status | ENUM | `pending` / `disetujui` / `ditolak` |
| diajukan_at, diproses_oleh, diproses_at | | |

**Validasi radius GPS:** di-enforce di level client (cek jarak sebelum submit, untuk UX cepat) **dan** divalidasi ulang di server-side (tidak percaya koordinat dari client mentah-mentah).

### 3.4 Jadwal Shift (Poin 4)
* Karyawan langsung di-assign ke **Shift 1** atau **Shift 2** — tanpa konsep cabang/rombong (karena cafe cuma 1 lokasi)
* Admin/owner assign manual per karyawan per tanggal
* Validasi bentrok: 1 karyawan tidak boleh 2 shift di tanggal sama

**`jadwal_shift`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| karyawan_id | UUID | FK |
| tanggal | DATE | |
| shift | ENUM | `shift_1` / `shift_2` |
| jam_mulai, jam_selesai | TIME | bisa dari Shift Template atau manual |
| dibuat_oleh | UUID | FK admin |

Constraint: `UNIQUE(karyawan_id, tanggal)`.

**Swap Shift**
* Karyawan bisa mengajukan tukar shift dengan karyawan lain, **hanya untuk tanggal yang sama** — kalau target beda tanggal, request ditolak sistem langsung saat submit
* Admin approve/tolak. Begitu disetujui, `karyawan_id` di kedua row `jadwal_shift` ditukar posisinya — jam otomatis ikut tertukar

**Request Off**
* Sifatnya **cuma pengajuan**, tanpa approval workflow — admin melihat lalu membuat jadwal libur sendiri (dengan tidak membuatkan row `jadwal_shift` di tanggal tsb)
* **Semua karyawan bisa lihat semua pengajuan** (termasuk yang belum diproses admin) — supaya karyawan lain bisa menghindari mengajukan libur di tanggal yang sudah banyak yang request, biar tidak bentrok kekurangan orang

### 3.5 Layar Pesanan / KDS (Poin 5)
* Begitu `transaksi` disimpan → sistem cek tiap `transaksi_detail`, kelompokkan berdasarkan `kategori_menu.area_produksi`
* Item dengan area_produksi = `kitchen` → **push realtime ke layar TV di lantai 2 (kitchen)**, tampilkan **kode_menu + qty + catatan/notes**
* Item dengan area_produksi = `bar` (minuman) → **belum ada layar TV** — mekanismenya masih **pending observasi** (kemungkinan pakai app HP/tablet, dibahas di sesi terpisah)
* Staff kitchen bisa update `status_item` (menunggu → diproses → selesai) langsung dari layar/perangkat KDS

### 3.6 Reporting & Pengeluaran (Poin 6)
Mitra/owner bisa lihat penghasilan per hari/range/bulan/tahun. Formula profit harian disepakati final:

```
Profit Harian = Penjualan Hari Itu
                − HPP (bahan baku dari menu yang terjual hari itu, dari menu_resep × qty)
                − Σ(pengeluaran tipe `bulanan` yang berlaku bulan itu ÷ jumlah hari di bulan itu)
                − Σ(pengeluaran tipe `mendadak` yang tanggalnya = hari itu)
```

**Prinsip kunci (supaya tidak double-count):** pembelian bahan baku ke gudang **tidak** dihitung sebagai pengeluaran terpisah di laporan profit — cukup dicatat sebagai histori di Stok Gudang (3.2). HPP yang dipakai di laporan profit murni teoritis dari resep × penjualan, bukan dari transaksi pembelian aktual.

**Input Pengeluaran — kategori fleksibel, 2 tipe:**
* Kategori pengeluaran **bukan ENUM fixed** — admin bisa tambah kategori sendiri ke depan (listrik, air, parfum ruangan, sewa, gaji, dll — apapun yang relevan buat cafe ini), tersimpan di tabel `kategori_pengeluaran`
* Tiap entry pengeluaran punya `tipe`: **`bulanan`** (recurring, dicatat 1x per bulan, otomatis dipecah rata ÷ jumlah hari di bulan itu buat perhitungan profit harian) atau **`mendadak`** (one-time/dadakan, langsung dicatat di tanggal kejadian, tidak dipecah — mis. beli es batu tambahan, servis alat rusak)

**`kategori_pengeluaran`**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| nama | VARCHAR | "Listrik", "Air", "Parfum Ruangan", "Sewa", dll — admin bisa tambah bebas |
| status_aktif | BOOL | |

**`pengeluaran`** — 1 row = 1 pencatatan pengeluaran, manual oleh admin/owner

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UUID | PK |
| kategori_id | UUID | FK |
| tipe | ENUM | `bulanan` / `mendadak` |
| nominal | DECIMAL | |
| bulan | DATE nullable | wajib diisi kalau tipe `bulanan` — bulan berlakunya, dipecah ÷ jumlah hari di bulan itu |
| tanggal | DATE nullable | wajib diisi kalau tipe `mendadak` — tanggal kejadian, dicatat penuh di hari itu |
| keterangan | TEXT | |
| dicatat_oleh | UUID | FK admin/owner |
| created_at | TIMESTAMP | |

HPP dihitung **on-demand** (bukan snapshot): `Σ(menu_resep.jumlah_terpakai × harga_per_unit_bahan)` untuk semua `transaksi_detail` yang terjual (status transaksi `selesai`) di tanggal terkait.

Laporan lain yang tersedia: breakdown pengeluaran per kategori (`pengeluaran` group by `kategori_id`), filter Harian / Range Tanggal / Bulanan / Tahunan.

## 4. Role & Hak Akses

**Struktur role:** 3 macam — **Karyawan** / **Admin** / **Owner**.

**Prinsip dasar akses foto** (berlaku lintas fitur — `barang_keluar` kalau nanti ditambah foto bukti, `transaksi.foto_bukti_qris`, `absensi.foto_masuk`/`foto_pulang`): Admin & Owner bisa lihat semua foto. Karyawan **hanya bisa lihat foto yang dia sendiri upload**, tidak bisa lihat foto milik karyawan lain.

### 4.1 Karyawan (Akses Operasional Harian & Self-Service)

**Operasional harian (shift aktif miliknya):**
* Absensi di radius lokasi cafe, ajukan izin telat/izin tidak masuk
* POS: buat transaksi + cancel transaksi — cancel dibatasi ketat ke **shift aktif yang sedang login** (bukan riwayat transaksi shift lama miliknya)
* Stok opname awal_shift & akhir_shift
* `barang_keluar` — ambil barang gudang→titik (bar/kitchen)
* KDS: update `status_item` (menunggu → diproses → selesai) di layar/perangkat yang jadi tanggung jawabnya (kitchen, atau bar kalau nanti ada app)

**Swap Shift & Request Off — exception visibility (bukan cuma data sendiri):**
* Ajukan swap shift — butuh akses lihat jadwal karyawan **lain** di tanggal yang sama, untuk memilih target tukar
* Request off — bisa lihat **semua** pengajuan request off milik karyawan lain juga (bukan cuma punya sendiri), supaya bisa saling menghindari bentrok tanggal

**Laporan Shift Aktif** *(read-only, on-demand query dari `transaksi`/`transaksi_detail` WHERE `jadwal_shift_id` = shift aktif yang sedang login, tanpa tabel/kolom baru):*
* Total pendapatan, jumlah transaksi, rincian nominal per metode bayar (cash/QRIS) selama shift berjalan
* Tujuan: sanity check mandiri sebelum submit langkah blocking akhir shift (`stok_opname` akhir_shift, 3.2)
* Scope ketat: hanya shift yang **sedang berjalan**, bukan riwayat shift lama

**Profil:**
* Edit profil sendiri (foto profil, nomor HP, dll) — langsung tanpa perlu lewat Admin

### 4.2 Admin (Back-Office & Operasional Penuh)

**Akses modul penuh:** 100% dari 6 fitur, termasuk laporan Profit Harian & Pengeluaran (3.6), CRUD master data (menu, kategori_menu, bahan, menu_resep, kategori_pengeluaran)

**Konfigurasi operasional — tetap Admin-accessible** (bukan Owner-only): titik koordinat & radius GPS absen (3.3) — alasan: praktik lapangan Owner sering cukup **menginstruksikan** Admin untuk eksekusi perubahan ini, tanpa perlu Owner sendiri yang eksekusi

**Manajemen Karyawan — terbatas ke role `Karyawan` saja:** create akun baru role Karyawan, soft-disable akun Karyawan yang resign

**Approval operasional — default dipegang Admin** (Owner otomatis ikut karena superuser, tapi praktiknya Owner lebih sering hanya memantau laporan): swap shift (3.4), izin telat & izin tidak masuk (3.3)

**Batasan Sistem (blocking via validasi API):** Admin **tidak bisa** membuat akun berstatus `admin`, mengubah role seorang `Karyawan` menjadi `admin`, atau mengubah kredensial/menonaktifkan akun `admin` lain (termasuk akun Admin miliknya sendiri dari sisi role-elevation — hanya Owner yang punya otoritas itu)

### 4.3 Owner (Superuser)
* **Akses absolut** — seluruh fungsionalitas yang dimiliki Admin, tanpa batasan tambahan
* **Hak eksklusif manajemen role:** satu-satunya entitas yang bisa membuat akun dengan role `admin`, mengangkat (promote) `Karyawan` menjadi `admin`, serta menonaktifkan akun `admin`
* **Asumsi implementasi — akun Owner:** kemungkinan besar hanya **1 akun Owner** untuk sistem ini. Akun Owner **di-seed manual langsung di database** (bukan dibuat lewat UI/endpoint aplikasi) — tidak perlu ada endpoint "create owner" di sistem sama sekali, menghindari celah role-elevation yang tidak sengaja terbuka

## 5. Skema Database — Optimasi
*Belum dibahas — indexing, constraint, backup, dll menyusul di sesi terpisah.*

---

> **Status: Siap untuk tahap koding (database + konfigurasi dasar).** Item pending di bawah **sengaja ditunda**, bukan terlewat — dibahas menyusul di sesi terpisah tanpa menghambat mulainya development 6 fitur utama.

## Log Keputusan
- [FIX] Pemesanan **hanya di kasir** — fitur QR code/web ordering pelanggan dihapus total dari scope
- [FIX] Scope dikunci ke **6 fitur utama saja**: POS+Takaran (3.1), Stok Gudang (3.2), Absensi (3.3), Jadwal Shift (3.4), Layar Pesanan/KDS (3.5), Reporting (3.6)
- [FIX] Stack: FastAPI (backend) + Flutter (semua klien: APK Android, Flutter Web untuk iOS/PC) + on-premise PC server (Laragon, Nginx, MySQL/MariaDB)
- [FIX] Realtime pakai FastAPI WebSocket native
- [FIX] Payment: Cash & QRIS statis, konfirmasi manual oleh kasir, tanpa payment gateway
- [FIX] Stok Gudang vs Stok Titik (Bar/Kitchen): terpisah total, twin-checkpoint opname per shift (awal/akhir shift, carry_forward vs hitung_manual)
- [FIX] Absensi: 1 titik GPS (lokasi cafe), ada absen pulang, izin telat & izin tidak masuk dengan approval admin
- [FIX] Jadwal: shift 1/2 langsung, tanpa cabang/rombong, ada swap shift (approval admin) & request off (tanpa approval, visible semua karyawan)
- [FIX] Layar Pesanan kitchen: kode_menu + notes, realtime via WebSocket
- [FIX] Formula Reporting: Profit Harian = Penjualan − HPP harian − Pengeluaran bulanan (dipecah harian) − pengeluaran mendadak
- [FIX] Input Pengeluaran: kategori fleksibel (`kategori_pengeluaran`, admin bisa tambah sendiri, bukan ENUM fixed) + 2 tipe pengeluaran (`bulanan` dipecah harian, `mendadak` one-time di tanggal kejadian)
- [FIX] Role & Hak Akses: 3 role (Karyawan/Admin/Owner). Karyawan akses operasional harian (POS shift aktif, stok opname, absensi, swap shift/request off dengan exception visibility) + Laporan Shift Aktif read-only. Admin akses penuh 6 fitur + approval swap shift/izin + kelola akun Karyawan, tapi diblok dari kelola akun Admin lain. Owner superuser, satu-satunya yang bisa buat/promote akun Admin, akun di-seed manual di database
- [PENDING] Potongan telat/SP — menunggu hasil wawancara
- [PENDING] Layar/app antrian minuman di Bar — menunggu observasi
- [PENDING] Detail remote access (Cloudflare Tunnel/Tailscale), domain, backup server
- [FIX] Cancel/Void transaksi: kasir cancel transaksi sendiri tanpa alasan wajib, dibatasi hanya sebelum stok_opname akhir_shift shift terkait disubmit, status jadi `dibatalkan` (bukan hard delete), divalidasi di level API
