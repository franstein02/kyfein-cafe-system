-- =====================================================================
-- KYFEIN CAFE SYSTEM — SKEMA MySQL / MariaDB (bawaan Laragon)
-- Scope: 6 fitur utama (POS+Takaran, Stok Gudang & Titik, Absensi,
--        Jadwal Shift, Layar Pesanan/KDS, Reporting & Pengeluaran)
--        + Master Data + Role & Hak Akses
-- Tanpa: QR ordering pelanggan, payroll/gaji, kas bon, manajemen supplier/PO,
--        multi-cabang/rombong (di luar scope rencana pengembangan). Catatan:
--        barang_masuk (v4) SENGAJA cuma catat harga+jumlah restock, BUKAN
--        modul supplier/purchase-order penuh — masih di luar scope.
--
-- REVISI v4 dari schema_kyfein_mysql.sql — 5 fix hasil review:
--   [FIX-1] Semua FK ditulis eksplisit "FOREIGN KEY (col) REFERENCES tbl(id)"
--           dengan ON DELETE yang jelas. Versi sebelumnya pakai inline
--           column-level "REFERENCES" yang DIABAIKAN oleh MySQL/MariaDB
--           (bukan bug minor — integritas referensial sebelumnya TIDAK aktif
--           untuk ~90% relasi di skema). Aturan ON DELETE yang dipakai:
--             - RESTRICT untuk data operasional/transaksional (karyawan,
--               bahan, menu, kategori, jadwal_shift, dst) — cafe ini
--               memang selalu soft-delete (status_aktif), jadi hard-delete
--               parent yang masih direferensikan memang harus ditolak.
--             - SET NULL untuk kolom opsional/jejak (mis. diproses_oleh,
--               dibuat_oleh, diubah_oleh, izin_telat_id, shift_template_id).
--             - CASCADE hanya dipakai header -> detail dalam 1 entitas yang
--               sama (transaksi -> transaksi_detail, dst) — bukan lintas
--               entitas independen.
--   [FIX-2] jadwal_shift ditambah kolom area_kerja ('kasir'/'bar'/'kitchen')
--           supaya 1 shift = 1 area kerja spesifik. Konsekuensi: stok_opname
--           & barang_keluar untuk karyawan tsb harus konsisten dengan
--           area_kerja shift aktifnya (divalidasi di app layer, MySQL tidak
--           bisa CHECK lintas tabel).
--   [FIX-3] Tabel yang sebelumnya cuma "implementation detail" (shift_template,
--           tukar_shift, request_off, audit_log_konfigurasi) sekarang resmi
--           didokumentasikan juga di rencana-pengembangan-kyfein.md.
--   [FIX-4] Optimasi skema (bagian 5 dokumen): collation utf8mb4_unicode_ci
--           dikunci di level database (lihat catatan sebelum SET NAMES di
--           bawah), composite index untuk pola query reporting/opname/
--           absensi/pengeluaran yang sering dipakai. Strategi backup
--           (mysqldump terjadwal) didokumentasikan di markdown, di luar
--           file SQL ini karena bukan bagian dari skema.
--   [FIX-5] Tabel baru barang_masuk/barang_masuk_detail (pencatatan barang
--           masuk ke gudang: jumlah + harga) + kolom bahan.harga_rata_rata
--           (moving weighted average, di-update tiap barang_masuk disubmit).
--           Ini sumber harga bahan yang sebelumnya HILANG dari skema —
--           dipakai reporting.py buat hitung HPP aktual (3.6), gantikan
--           angka hardcode/asumsi yang sempat dipakai coding agent karena
--           skema lama tidak punya sumber harga bahan sama sekali.
--
-- Catatan UUID: PK pakai CHAR(36) + DEFAULT (UUID()).
--   - MySQL 8.0.13+ dan MariaDB 10.7+ mendukung DEFAULT (UUID()) langsung.
--   - Kalau versi MySQL/MariaDB di Laragon kamu lebih lama dan migration
--     ini gagal karena error di DEFAULT (UUID()), solusinya: hapus bagian
--     "DEFAULT (UUID())" dari tiap kolom id, lalu generate UUID di layer
--     aplikasi (FastAPI, pakai uuid.uuid4()) sebelum INSERT.
--   - Storage engine wajib InnoDB (default MySQL 8/MariaDB modern) supaya
--     FOREIGN KEY & CHECK constraint jalan.
-- =====================================================================

-- [5.1] Jalankan sekali sebelum migration ini, supaya semua tabel yang belum
-- punya COLLATE eksplisit ikut collation database (bukan default bawaan
-- server yang beda-beda antara MySQL 8 / MariaDB):
--   ALTER DATABASE db_kyfein CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;


-- =====================================================================
-- PART 4 — AKUN & KARYAWAN (dibuat duluan — direferensikan hampir semua tabel)
-- Role & Hak Akses: karyawan / admin / owner (lihat dokumen rencana bagian 4)
-- =====================================================================

CREATE TABLE karyawan (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    role            ENUM('karyawan', 'admin', 'owner') NOT NULL,
    nama            VARCHAR(150) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    nomor_hp        VARCHAR(20) NOT NULL UNIQUE,
    password        VARCHAR(255) NOT NULL,
    foto_profile    TEXT,
    status_aktif    BOOLEAN NOT NULL DEFAULT true, -- soft-delete saat resign, bukan hard delete (referential integrity + histori)
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan implementasi: hanya boleh ada 1 row role='owner', di-seed manual
-- langsung lewat SQL/migration seed, BUKAN lewat endpoint aplikasi apa pun
-- (lihat dokumen rencana 4.3). Enforce di app layer, bukan constraint SQL.


-- =====================================================================
-- 3.3 KONFIGURASI LOKASI ABSENSI (basecamp cafe, 1 titik GPS saja)
-- =====================================================================

CREATE TABLE konfigurasi_lokasi (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    latitude        DECIMAL(11,8) NOT NULL,
    longitude       DECIMAL(11,8) NOT NULL,
    radius_meter    INT NOT NULL DEFAULT 50,
    updated_by      CHAR(36),
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_konfig_lokasi_updated_by FOREIGN KEY (updated_by) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan: tabel ini didesain sebagai singleton (1 row saja mewakili lokasi
-- cafe). Tidak ada constraint SQL yang bisa memaksa "max 1 row" secara bersih
-- di MySQL tanpa trigger tambahan — di-enforce di app layer: endpoint admin
-- selalu UPDATE row yang sudah ada, tidak pernah INSERT baru setelah seed awal.


-- =====================================================================
-- 3.0 MASTER DATA: KATEGORI MENU, MENU, BAHAN, RESEP
-- =====================================================================

CREATE TABLE kategori_menu (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    nama            VARCHAR(50) NOT NULL UNIQUE, -- "Makanan", "Minuman"
    area_produksi   ENUM('bar', 'kitchen') NOT NULL, -- routing ke Layar Pesanan (3.5)
    status_aktif    BOOLEAN NOT NULL DEFAULT true,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE menu (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    nama            VARCHAR(100) NOT NULL,
    kode_menu       VARCHAR(20) NOT NULL UNIQUE, -- ditampilkan di layar KDS, bukan nama lengkap
    harga           DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (harga >= 0),
    kategori_id     CHAR(36) NOT NULL,
    foto            TEXT,
    status_aktif    BOOLEAN NOT NULL DEFAULT true, -- toggle stok habis/tersedia
    dibuat_oleh     CHAR(36),
    diubah_oleh     CHAR(36),
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_menu_kategori FOREIGN KEY (kategori_id) REFERENCES kategori_menu(id) ON DELETE RESTRICT,
    CONSTRAINT fk_menu_dibuat_oleh FOREIGN KEY (dibuat_oleh) REFERENCES karyawan(id) ON DELETE SET NULL,
    CONSTRAINT fk_menu_diubah_oleh FOREIGN KEY (diubah_oleh) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE bahan (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    nama            VARCHAR(100) NOT NULL,
    satuan          VARCHAR(20) NOT NULL, -- ml/gram/pcs, dll
    isi_per_kemasan DECIMAL(10,3), -- konversi kemasan besar -> satuan kecil, khusus internal gudang (3.2)
    stok_minimum    DECIMAL(10,3) NOT NULL DEFAULT 0, -- reminder stok menipis di Reporting (3.6)
    harga_rata_rata DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (harga_rata_rata >= 0), -- moving weighted-average cost per satuan kecil, di-update tiap barang_masuk (3.2 & 3.6)
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan (harga_rata_rata): HPP di Reporting (3.6) pakai kolom ini, BUKAN
-- harga dari transaksi pembelian mentah. Dihitung app layer pakai moving
-- weighted average setiap kali barang_masuk disubmit:
--   total_satuan_kecil_lama = stok_gudang.jumlah_kemasan_besar * bahan.isi_per_kemasan
--                              + stok_gudang.jumlah_satuan_kecil  (SEBELUM ditambah barang masuk baru)
--   harga_rata_rata_baru = (total_satuan_kecil_lama * harga_rata_rata_lama
--                            + jumlah_satuan_kecil_masuk * harga_satuan_masuk)
--                           / (total_satuan_kecil_lama + jumlah_satuan_kecil_masuk)
-- Kalau bahan belum pernah ada stok (baris pertama), harga_rata_rata_baru = harga_satuan_masuk.

CREATE TABLE menu_resep (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    menu_id         CHAR(36) NOT NULL,
    bahan_id        CHAR(36) NOT NULL,
    jumlah_terpakai DECIMAL(10,3) NOT NULL CHECK (jumlah_terpakai > 0), -- takaran per 1 unit menu terjual
    CONSTRAINT uq_menu_resep UNIQUE (menu_id, bahan_id),
    CONSTRAINT fk_menu_resep_menu FOREIGN KEY (menu_id) REFERENCES menu(id) ON DELETE CASCADE,
    CONSTRAINT fk_menu_resep_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =====================================================================
-- 3.4 JADWAL SHIFT (Poin 4) — Shift 1/2, tanpa cabang/rombong
-- =====================================================================

CREATE TABLE shift_template (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    shift           ENUM('shift_1', 'shift_2') NOT NULL UNIQUE,
    jam_mulai       TIME NOT NULL,
    jam_selesai     TIME NOT NULL,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE jadwal_shift (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id         CHAR(36) NOT NULL,
    tanggal             DATE NOT NULL,
    shift               ENUM('shift_1', 'shift_2') NOT NULL,
    area_kerja          ENUM('kasir', 'bar', 'kitchen') NOT NULL, -- [FIX-2] 1 shift = 1 area kerja spesifik
    shift_template_id   CHAR(36), -- jejak referensi saja
    jam_mulai           TIME NOT NULL, -- snapshot dari template atau manual
    jam_selesai         TIME NOT NULL,
    dibuat_oleh         CHAR(36),
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_karyawan_tanggal UNIQUE (karyawan_id, tanggal), -- 1 karyawan tidak boleh 2 shift/tanggal
    CONSTRAINT fk_jadwal_shift_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_jadwal_shift_template FOREIGN KEY (shift_template_id) REFERENCES shift_template(id) ON DELETE SET NULL,
    CONSTRAINT fk_jadwal_shift_dibuat_oleh FOREIGN KEY (dibuat_oleh) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan area_kerja (FIX-2): karyawan dengan area_kerja='kasir' pada shift itu
-- yang boleh jadi transaksi.kasir_id untuk shift tsb. karyawan dengan
-- area_kerja='bar'/'kitchen' yang boleh submit stok_opname/barang_keluar untuk
-- titik yang sama (titik HARUS sama dengan area_kerja shift aktifnya) —
-- divalidasi di app layer (endpoint), karena MySQL tidak bisa CHECK lintas
-- tabel (jadwal_shift <-> stok_opname/barang_keluar).

CREATE TABLE tukar_shift (
    id                      CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    shift_a_id              CHAR(36) NOT NULL,
    shift_b_id              CHAR(36) NOT NULL,
    karyawan_pengaju_id     CHAR(36) NOT NULL,
    karyawan_target_id      CHAR(36) NOT NULL,
    status                  ENUM('pending', 'disetujui', 'ditolak') NOT NULL DEFAULT 'pending', -- approval oleh Admin
    alasan                  TEXT,
    diajukan_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    diproses_oleh           CHAR(36),
    diproses_at             DATETIME,
    CONSTRAINT chk_tukar_shift_beda_row CHECK (shift_a_id <> shift_b_id),
    CONSTRAINT fk_tukar_shift_a FOREIGN KEY (shift_a_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_tukar_shift_b FOREIGN KEY (shift_b_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_tukar_shift_pengaju FOREIGN KEY (karyawan_pengaju_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_tukar_shift_target FOREIGN KEY (karyawan_target_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_tukar_shift_diproses_oleh FOREIGN KEY (diproses_oleh) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan: validasi "hanya untuk tanggal yang sama" (jadwal_shift.tanggal
-- shift_a = shift_b) dilakukan di app layer saat submit request (lihat 3.4).

CREATE TABLE request_off (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id     CHAR(36) NOT NULL,
    tanggal         DATE NOT NULL,
    alasan          TEXT,
    diajukan_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- tanpa approval workflow (lihat 3.4) — visible ke semua karyawan lewat query biasa
    CONSTRAINT fk_request_off_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =====================================================================
-- 3.3 ABSENSI (Poin 3)
-- =====================================================================

CREATE TABLE izin_telat (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id         CHAR(36) NOT NULL,
    jadwal_shift_id     CHAR(36) NOT NULL,
    alasan              TEXT NOT NULL,
    foto_url            TEXT, -- opsional/bebas
    status              ENUM('pending', 'disetujui', 'ditolak') NOT NULL DEFAULT 'pending',
    diajukan_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    diproses_oleh       CHAR(36),
    diproses_at         DATETIME,
    CONSTRAINT fk_izin_telat_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_izin_telat_jadwal_shift FOREIGN KEY (jadwal_shift_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_izin_telat_diproses_oleh FOREIGN KEY (diproses_oleh) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE izin_tidak_masuk (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id         CHAR(36) NOT NULL,
    jadwal_shift_id     CHAR(36) NOT NULL,
    alasan              TEXT NOT NULL,
    foto_url            TEXT NOT NULL, -- wajib: surat dokter/bukti musibah, dll
    status              ENUM('pending', 'disetujui', 'ditolak') NOT NULL DEFAULT 'pending',
    diajukan_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    diproses_oleh       CHAR(36),
    diproses_at         DATETIME,
    CONSTRAINT fk_izin_tm_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_izin_tm_jadwal_shift FOREIGN KEY (jadwal_shift_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_izin_tm_diproses_oleh FOREIGN KEY (diproses_oleh) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE absensi (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id     CHAR(36) NOT NULL,
    jadwal_shift_id CHAR(36) NOT NULL,
    jam_masuk       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    jam_pulang      DATETIME,
    lat_masuk       DECIMAL(11,8) NOT NULL,
    lng_masuk       DECIMAL(11,8) NOT NULL,
    lat_pulang      DECIMAL(11,8),
    lng_pulang      DECIMAL(11,8),
    foto_masuk      TEXT NOT NULL,
    foto_pulang     TEXT,
    menit_telat     INT NOT NULL DEFAULT 0, -- selisih jam_masuk vs jadwal_shift.jam_mulai
    izin_telat_id   CHAR(36), -- di-set kalau telat ini di-cover izin yang disetujui
    status_pulang   ENUM('tepat_waktu', 'telat', 'lupa_absen'), -- NULL selama belum absen pulang
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_absensi_shift UNIQUE (jadwal_shift_id), -- 1 shift cuma 1 absensi
    CONSTRAINT fk_absensi_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_absensi_jadwal_shift FOREIGN KEY (jadwal_shift_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_absensi_izin_telat FOREIGN KEY (izin_telat_id) REFERENCES izin_telat(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =====================================================================
-- 3.2 STOK GUDANG & STOK BAR/KITCHEN (Poin 2)
-- =====================================================================

CREATE TABLE stok_gudang (
    id                      CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    bahan_id                CHAR(36) NOT NULL UNIQUE,
    jumlah_kemasan_besar    INT NOT NULL DEFAULT 0 CHECK (jumlah_kemasan_besar >= 0),
    jumlah_satuan_kecil     DECIMAL(10,3) NOT NULL DEFAULT 0 CHECK (jumlah_satuan_kecil >= 0),
    updated_at              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_stok_gudang_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stok_titik (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    bahan_id        CHAR(36) NOT NULL,
    titik           ENUM('bar', 'kitchen') NOT NULL,
    jumlah          DECIMAL(10,3) NOT NULL DEFAULT 0 CHECK (jumlah >= 0), -- hasil opname terakhir, bukan hitungan otomatis
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_stok_titik UNIQUE (bahan_id, titik),
    CONSTRAINT fk_stok_titik_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE barang_masuk (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id     CHAR(36) NOT NULL, -- wajib, siapa yang input/terima barang
    keterangan      TEXT, -- catatan bebas (nama toko/supplier, no. nota, dll) — BUKAN relasi ke tabel supplier (di luar scope)
    waktu           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_barang_masuk_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE barang_masuk_detail (
    id                      CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    barang_masuk_id         CHAR(36) NOT NULL,
    bahan_id                CHAR(36) NOT NULL,
    jumlah_kemasan_besar    INT NOT NULL DEFAULT 0 CHECK (jumlah_kemasan_besar >= 0), -- dus/box yang masuk
    jumlah_satuan_kecil     DECIMAL(10,3) NOT NULL DEFAULT 0 CHECK (jumlah_satuan_kecil >= 0), -- satuan eceran tambahan di luar kemasan besar
    harga_total             DECIMAL(14,2) NOT NULL CHECK (harga_total > 0), -- total dibayar utk baris ini (kemasan + eceran digabung)
    CONSTRAINT chk_bmd_jumlah_masuk CHECK (jumlah_kemasan_besar > 0 OR jumlah_satuan_kecil > 0),
    CONSTRAINT fk_bmd_barang_masuk FOREIGN KEY (barang_masuk_id) REFERENCES barang_masuk(id) ON DELETE CASCADE,
    CONSTRAINT fk_bmd_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan (barang_masuk): submit barang_masuk_detail melakukan 2 hal di app layer:
--   1. Menambah stok_gudang.jumlah_kemasan_besar & jumlah_satuan_kecil (INCREASE,
--      kebalikan dari barang_keluar yang selalu DECREASE stok_gudang)
--   2. Update bahan.harga_rata_rata pakai moving weighted average (lihat catatan
--      di definisi tabel bahan) — harga_satuan_masuk = harga_total / total
--      satuan kecil masuk (jumlah_kemasan_besar * bahan.isi_per_kemasan + jumlah_satuan_kecil)
-- Bukan fitur supplier/purchasing penuh — cuma pencatatan restock + harga
-- untuk kebutuhan HPP (3.6). Tanpa relasi supplier/PO, sesuai scope awal.

CREATE TABLE barang_keluar (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    titik_tujuan    ENUM('bar', 'kitchen') NOT NULL,
    karyawan_id     CHAR(36) NOT NULL, -- wajib, siapa yang ambil
    waktu           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_barang_keluar_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan (FIX-2): titik_tujuan idealnya = area_kerja shift aktif karyawan_id
-- saat itu — divalidasi di app layer, bukan constraint SQL.

CREATE TABLE barang_keluar_detail (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    barang_keluar_id    CHAR(36) NOT NULL,
    bahan_id            CHAR(36) NOT NULL,
    jumlah              DECIMAL(10,3) NOT NULL CHECK (jumlah > 0), -- satuan kecil
    CONSTRAINT fk_bkd_barang_keluar FOREIGN KEY (barang_keluar_id) REFERENCES barang_keluar(id) ON DELETE CASCADE,
    CONSTRAINT fk_bkd_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stok_opname (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    jadwal_shift_id CHAR(36) NOT NULL,
    titik           ENUM('bar', 'kitchen') NOT NULL,
    tipe            ENUM('awal_shift', 'akhir_shift') NOT NULL, -- keduanya blocking
    metode          ENUM('hitung_manual', 'carry_forward') NOT NULL, -- hitung_manual (cross-day) / carry_forward (same-day)
    karyawan_id     CHAR(36) NOT NULL, -- wajib = karyawan assigned di shift itu
    waktu_opname    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    catatan         TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_stok_opname UNIQUE (jadwal_shift_id, titik, tipe),
    CONSTRAINT fk_stok_opname_jadwal_shift FOREIGN KEY (jadwal_shift_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_stok_opname_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan (FIX-2): titik WAJIB sama dengan jadwal_shift.area_kerja milik
-- jadwal_shift_id tsb (mis. shift dengan area_kerja='bar' hanya boleh
-- punya stok_opname titik='bar') — divalidasi di app layer.

CREATE TABLE stok_opname_detail (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    stok_opname_id  CHAR(36) NOT NULL,
    bahan_id        CHAR(36) NOT NULL,
    jumlah          DECIMAL(10,3) NOT NULL DEFAULT 0, -- hasil hitung fisik, raw, tidak dikonversi
    CONSTRAINT fk_sod_stok_opname FOREIGN KEY (stok_opname_id) REFERENCES stok_opname(id) ON DELETE CASCADE,
    CONSTRAINT fk_sod_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Audit trail selisih handover (3.2) — dicatat otomatis oleh app layer saat opname awal_shift disubmit
CREATE TABLE mutasi_stok (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    bahan_id            CHAR(36) NOT NULL,
    titik               ENUM('bar', 'kitchen'),
    jadwal_shift_id     CHAR(36),
    tipe                VARCHAR(50) NOT NULL DEFAULT 'selisih_handover',
    jumlah_selisih      DECIMAL(10,3) NOT NULL,
    keterangan          TEXT,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_mutasi_stok_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_mutasi_stok_jadwal_shift FOREIGN KEY (jadwal_shift_id) REFERENCES jadwal_shift(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =====================================================================
-- 3.1 POS & TRANSAKSI (Poin 1) — Takaran & Selisih Stok
-- =====================================================================

CREATE TABLE transaksi (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    jadwal_shift_id     CHAR(36) NOT NULL,
    kasir_id            CHAR(36) NOT NULL, -- denormalisasi dari jadwal_shift
    nomor_transaksi     VARCHAR(30) NOT NULL UNIQUE, -- human-readable, tampil di struk
    metode_bayar        ENUM('cash', 'qris') NOT NULL,
    total_harga         DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (total_harga >= 0),
    uang_diterima       DECIMAL(14,2), -- khusus cash
    kembalian           DECIMAL(14,2), -- khusus cash
    foto_bukti_qris     TEXT, -- khusus qris
    status              ENUM('selesai', 'dibatalkan') NOT NULL DEFAULT 'selesai',
    waktu_transaksi     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_bukti_bayar CHECK (
        (metode_bayar = 'cash' AND uang_diterima IS NOT NULL) OR
        (metode_bayar = 'qris' AND foto_bukti_qris IS NOT NULL)
    ),
    CONSTRAINT fk_transaksi_jadwal_shift FOREIGN KEY (jadwal_shift_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_transaksi_kasir FOREIGN KEY (kasir_id) REFERENCES karyawan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan (FIX-2): kasir_id idealnya = karyawan dengan area_kerja='kasir'
-- pada jadwal_shift_id tsb — divalidasi di app layer.

CREATE TABLE transaksi_detail (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    transaksi_id    CHAR(36) NOT NULL,
    menu_id         CHAR(36) NOT NULL,
    qty             INT NOT NULL CHECK (qty > 0),
    harga_satuan    DECIMAL(14,2) NOT NULL, -- snapshot harga saat transaksi, bukan live-lookup
    catatan         TEXT, -- mis. "less sugar", request customer
    subtotal        DECIMAL(14,2) NOT NULL,
    status_item     ENUM('menunggu', 'diproses', 'selesai') NOT NULL DEFAULT 'menunggu', -- dipakai Layar Pesanan/KDS (3.5)
    CONSTRAINT fk_transaksi_detail_transaksi FOREIGN KEY (transaksi_id) REFERENCES transaksi(id) ON DELETE CASCADE,
    CONSTRAINT fk_transaksi_detail_menu FOREIGN KEY (menu_id) REFERENCES menu(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan 3.5 (Layar Pesanan/KDS): tidak ada tabel tambahan — KDS query
-- transaksi_detail JOIN menu JOIN kategori_menu WHERE area_produksi='kitchen'
-- (atau 'bar'), lalu update status_item lewat endpoint yang sama.
-- Push realtime dilakukan via FastAPI WebSocket, di luar skema SQL.


-- =====================================================================
-- 3.6 REPORTING & PENGELUARAN (Poin 6)
-- =====================================================================

CREATE TABLE kategori_pengeluaran (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    nama            VARCHAR(50) NOT NULL UNIQUE, -- "Listrik", "Air", "Parfum Ruangan", "Sewa", dll — admin bisa tambah bebas
    status_aktif    BOOLEAN NOT NULL DEFAULT true,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pengeluaran (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    kategori_id     CHAR(36) NOT NULL,
    tipe            ENUM('bulanan', 'mendadak') NOT NULL,
    nominal         DECIMAL(14,2) NOT NULL CHECK (nominal > 0),
    bulan           DATE, -- wajib kalau tipe='bulanan', dipecah / jumlah hari di bulan itu
    tanggal         DATE, -- wajib kalau tipe='mendadak', dicatat penuh di hari itu
    keterangan      TEXT,
    dicatat_oleh    CHAR(36),
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_pengeluaran_periode CHECK (
        (tipe = 'bulanan' AND bulan IS NOT NULL AND tanggal IS NULL) OR
        (tipe = 'mendadak' AND tanggal IS NOT NULL AND bulan IS NULL)
    ),
    CONSTRAINT fk_pengeluaran_kategori FOREIGN KEY (kategori_id) REFERENCES kategori_pengeluaran(id) ON DELETE RESTRICT,
    CONSTRAINT fk_pengeluaran_dicatat_oleh FOREIGN KEY (dicatat_oleh) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan: HPP harian dihitung on-demand dari menu_resep x transaksi_detail
-- terjual (status transaksi='selesai') per tanggal — tidak ada tabel snapshot.


-- =====================================================================
-- PART 5 — INDEXING
-- =====================================================================
-- Catatan (FIX-1): FK yang sekarang eksplisit otomatis dapat index dari
-- InnoDB, jadi index manual untuk kolom FK TIDAK perlu dibuat ulang di sini
-- (sebelumnya ada di versi lama, sekarang dihapus supaya tidak redundant).
-- Index di bawah ini murni untuk kolom non-FK yang sering jadi filter query
-- (tanggal/waktu, status, dan kolom baru area_kerja).
--
-- Catatan lain: MySQL/MariaDB tidak mendukung partial/filtered index (WHERE
-- clause di CREATE INDEX) seperti PostgreSQL, jadi semua index di bawah
-- full-table. Kalau nanti data besar & butuh optimasi query kondisi
-- spesifik (mis. hanya transaksi status='selesai'), pertimbangkan
-- generated column + index, atau upgrade ke PostgreSQL di fase produksi.

-- Index tanggal/waktu
CREATE INDEX idx_transaksi_waktu ON transaksi(waktu_transaksi);
CREATE INDEX idx_jadwal_shift_tanggal ON jadwal_shift(tanggal);
CREATE INDEX idx_absensi_jam_masuk ON absensi(jam_masuk);
CREATE INDEX idx_pengeluaran_bulan ON pengeluaran(bulan);
CREATE INDEX idx_pengeluaran_tanggal ON pengeluaran(tanggal);
CREATE INDEX idx_barang_masuk_waktu ON barang_masuk(waktu);

-- Index status & area_kerja (kolom yang sering difilter bareng)
CREATE INDEX idx_transaksi_status ON transaksi(status);
CREATE INDEX idx_transaksi_detail_status_item ON transaksi_detail(status_item); -- query KDS realtime
CREATE INDEX idx_izin_telat_status ON izin_telat(status);
CREATE INDEX idx_izin_tidak_masuk_status ON izin_tidak_masuk(status);
CREATE INDEX idx_tukar_shift_status ON tukar_shift(status);
CREATE INDEX idx_karyawan_status_aktif ON karyawan(status_aktif);
CREATE INDEX idx_menu_status_aktif ON menu(status_aktif);
CREATE INDEX idx_jadwal_shift_area_kerja ON jadwal_shift(area_kerja); -- [FIX-2]

-- Composite index [5.2] — untuk pola query yang sering dipakai lintas fitur
CREATE INDEX idx_transaksi_status_waktu ON transaksi(status, waktu_transaksi); -- reporting/profit harian (3.6)
CREATE INDEX idx_stok_opname_titik_tipe ON stok_opname(titik, tipe); -- cari opname terakhir per titik (3.2)
CREATE INDEX idx_absensi_karyawan_jam ON absensi(karyawan_id, jam_masuk); -- riwayat absensi per karyawan (3.3)
CREATE INDEX idx_pengeluaran_kategori_tipe ON pengeluaran(kategori_id, tipe); -- breakdown pengeluaran (3.6)


-- =====================================================================
-- PART 6 — AUDIT TRAIL TRIGGER (scope: tabel konfigurasi_* saja)
-- =====================================================================

CREATE TABLE audit_log_konfigurasi (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    tabel           VARCHAR(50) NOT NULL,
    row_id          CHAR(36) NOT NULL,
    data_lama       JSON,
    data_baru       JSON,
    diubah_oleh     CHAR(36),
    diubah_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_log_diubah_oleh FOREIGN KEY (diubah_oleh) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- MySQL/MariaDB tidak punya fungsi setara to_jsonb(row) generik seperti
-- PostgreSQL, jadi JSON_OBJECT harus sebut kolom manual per tabel yang
-- diaudit. Berikut trigger untuk konfigurasi_lokasi:
DELIMITER $$
CREATE TRIGGER trg_audit_konfigurasi_lokasi
AFTER UPDATE ON konfigurasi_lokasi
FOR EACH ROW
BEGIN
    INSERT INTO audit_log_konfigurasi (tabel, row_id, data_lama, data_baru, diubah_oleh)
    VALUES (
        'konfigurasi_lokasi',
        NEW.id,
        JSON_OBJECT('latitude', OLD.latitude, 'longitude', OLD.longitude, 'radius_meter', OLD.radius_meter, 'updated_by', OLD.updated_by),
        JSON_OBJECT('latitude', NEW.latitude, 'longitude', NEW.longitude, 'radius_meter', NEW.radius_meter, 'updated_by', NEW.updated_by),
        NEW.updated_by
    );
END$$
DELIMITER ;


-- =====================================================================
-- SEED DASAR (opsional, sesuaikan sebelum dijalankan di lingkungan nyata)
-- =====================================================================

-- Shift template default — sesuaikan jam ke jam operasional cafe sebenarnya
INSERT INTO shift_template (shift, jam_mulai, jam_selesai) VALUES
    ('shift_1', '08:00:00', '16:00:00'),
    ('shift_2', '16:00:00', '23:00:00');

-- Kategori menu dasar
INSERT INTO kategori_menu (nama, area_produksi) VALUES
    ('Makanan', 'kitchen'),
    ('Minuman', 'bar');

-- TODO tim: seed 1 akun owner manual (role='owner') sebelum tahap pengembangan
-- fitur berjalan — JANGAN buat lewat endpoint register aplikasi.

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- SELESAI
-- =====================================================================
