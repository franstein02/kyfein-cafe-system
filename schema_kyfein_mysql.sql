-- =====================================================================
-- KYFEIN CAFE SYSTEM — SKEMA MySQL / MariaDB (v7 Synchronized)
-- Scope: 6 fitur utama (POS+Takaran, Stok Gudang & Titik, Absensi,
--        Jadwal Shift, Layar Pesanan/KDS, Reporting & Pengeluaran)
--        + Master Data + Role & Hak Akses + Tabel Foto & Upload 2 Langkah
--
-- Versi: v7 Synchronized (2026-10-07)
-- Migration & Fitur yang Tercakup:
--   - Issue 1: Tabel foto + FK foto (absensi, izin, qris, menu, karyawan)
--   - Issue 2: Konfigurasi HTTPS & WebSocket Secure (WSS) Nginx
--   - Issue 3: Snapshot HPP per item (transaksi_detail.hpp_satuan)
--   - Issue 4: Penguncian transaksi & syarat mulai POS
--   - Issue 5: Validasi & keamanan (harga_rata_rata proteksi, weighted average)
--   - Issue 6: Foto FK & constraint absensi/izin (foto_masuk_id, foto_pulang_id, foto_id)
--   - Issue 7: UNIQUE(karyawan_id, tanggal) di request_off
--   - Issue 8: Sinkronisasi skema MySQL komprehensif
--   - Issue 10: Service shift_berjalan, perbaikan sisa issue 6-9
--
-- Catatan UUID: PK memakai CHAR(36) + DEFAULT (UUID()).
-- Storage engine: InnoDB (wajib untuk mendukung Foreign Keys & Check Constraints).
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================================
-- PART 1 — AKUN & KARYAWAN + FOTO (Upload 2 Langkah)
-- =====================================================================

CREATE TABLE foto (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    jenis           ENUM('absensi', 'izin', 'qris', 'menu', 'profil') NOT NULL,
    path            VARCHAR(500) NOT NULL,
    uploader_id     CHAR(36) NOT NULL,
    dipakai         TINYINT(1) NOT NULL DEFAULT 0,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_foto_dipakai_created (dipakai, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE karyawan (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    role            ENUM('karyawan', 'admin') NOT NULL,
    nama            VARCHAR(150) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    nomor_hp        VARCHAR(20) NOT NULL UNIQUE,
    password        VARCHAR(255) NOT NULL,
    foto_profile_id CHAR(36),
    status_aktif    BOOLEAN NOT NULL DEFAULT true,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_karyawan_foto_profile FOREIGN KEY (foto_profile_id) REFERENCES foto(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tambahkan FK uploader ke foto setelah tabel karyawan dibuat
ALTER TABLE foto ADD CONSTRAINT fk_foto_uploader FOREIGN KEY (uploader_id) REFERENCES karyawan(id) ON DELETE RESTRICT;

-- =====================================================================
-- PART 2 — KONFIGURASI LOKASI ABSENSI
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

-- =====================================================================
-- PART 3 — MASTER DATA: KATEGORI MENU, MENU, BAHAN, RESEP
-- =====================================================================

CREATE TABLE kategori_menu (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    nama            VARCHAR(50) NOT NULL UNIQUE,
    area_produksi   ENUM('bar', 'kitchen') NOT NULL,
    status_aktif    BOOLEAN NOT NULL DEFAULT true,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE menu (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    nama            VARCHAR(100) NOT NULL,
    kode_menu       VARCHAR(20) NOT NULL UNIQUE,
    harga           DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (harga >= 0),
    kategori_id     CHAR(36) NOT NULL,
    foto_id         CHAR(36),
    status_aktif    BOOLEAN NOT NULL DEFAULT true,
    dibuat_oleh     CHAR(36),
    diubah_oleh     CHAR(36),
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_menu_kategori FOREIGN KEY (kategori_id) REFERENCES kategori_menu(id) ON DELETE RESTRICT,
    CONSTRAINT fk_menu_foto FOREIGN KEY (foto_id) REFERENCES foto(id) ON DELETE SET NULL,
    CONSTRAINT fk_menu_dibuat_oleh FOREIGN KEY (dibuat_oleh) REFERENCES karyawan(id) ON DELETE SET NULL,
    CONSTRAINT fk_menu_diubah_oleh FOREIGN KEY (diubah_oleh) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE bahan (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    nama            VARCHAR(100) NOT NULL,
    satuan          VARCHAR(20) NOT NULL,
    isi_per_kemasan DECIMAL(10,3),
    stok_minimum    DECIMAL(10,3) NOT NULL DEFAULT 0,
    harga_rata_rata DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (harga_rata_rata >= 0),
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE menu_resep (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    menu_id         CHAR(36) NOT NULL,
    bahan_id        CHAR(36) NOT NULL,
    jumlah_terpakai DECIMAL(10,3) NOT NULL CHECK (jumlah_terpakai > 0),
    CONSTRAINT uq_menu_resep UNIQUE (menu_id, bahan_id),
    CONSTRAINT fk_menu_resep_menu FOREIGN KEY (menu_id) REFERENCES menu(id) ON DELETE CASCADE,
    CONSTRAINT fk_menu_resep_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- PART 4 — JADWAL SHIFT, TUKAR SHIFT & REQUEST OFF
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
    area_kerja          ENUM('kasir', 'bar', 'kitchen') NOT NULL,
    shift_template_id   CHAR(36),
    jam_mulai           TIME NOT NULL,
    jam_selesai         TIME NOT NULL,
    dibuat_oleh         CHAR(36),
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_karyawan_tanggal UNIQUE (karyawan_id, tanggal),
    CONSTRAINT fk_jadwal_shift_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_jadwal_shift_template FOREIGN KEY (shift_template_id) REFERENCES shift_template(id) ON DELETE SET NULL,
    CONSTRAINT fk_jadwal_shift_dibuat_oleh FOREIGN KEY (dibuat_oleh) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE tukar_shift (
    id                      CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    shift_a_id              CHAR(36) NOT NULL,
    shift_b_id              CHAR(36) NOT NULL,
    karyawan_pengaju_id     CHAR(36) NOT NULL,
    karyawan_target_id      CHAR(36) NOT NULL,
    status                  ENUM('pending', 'disetujui', 'ditolak') NOT NULL DEFAULT 'pending',
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

CREATE TABLE request_off (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id     CHAR(36) NOT NULL,
    tanggal         DATE NOT NULL,
    alasan          TEXT,
    diajukan_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_request_off_karyawan_tanggal UNIQUE (karyawan_id, tanggal),
    CONSTRAINT fk_request_off_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- PART 5 — ABSENSI & IZIN (Dukungan Foto FK)
-- =====================================================================

CREATE TABLE izin_telat (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id         CHAR(36) NOT NULL,
    jadwal_shift_id     CHAR(36) NOT NULL,
    alasan              TEXT NOT NULL,
    foto_id             CHAR(36),
    status              ENUM('pending', 'disetujui', 'ditolak') NOT NULL DEFAULT 'pending',
    diajukan_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    diproses_oleh       CHAR(36),
    diproses_at         DATETIME,
    CONSTRAINT fk_izin_telat_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_izin_telat_jadwal_shift FOREIGN KEY (jadwal_shift_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_izin_telat_foto FOREIGN KEY (foto_id) REFERENCES foto(id) ON DELETE SET NULL,
    CONSTRAINT fk_izin_telat_diproses_oleh FOREIGN KEY (diproses_oleh) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE izin_tidak_masuk (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id         CHAR(36) NOT NULL,
    jadwal_shift_id     CHAR(36) NOT NULL,
    alasan              TEXT NOT NULL,
    foto_id             CHAR(36) NOT NULL,
    status              ENUM('pending', 'disetujui', 'ditolak') NOT NULL DEFAULT 'pending',
    diajukan_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    diproses_oleh       CHAR(36),
    diproses_at         DATETIME,
    CONSTRAINT fk_izin_tm_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_izin_tm_jadwal_shift FOREIGN KEY (jadwal_shift_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_izin_tm_foto FOREIGN KEY (foto_id) REFERENCES foto(id) ON DELETE RESTRICT,
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
    foto_masuk_id   CHAR(36) NOT NULL,
    foto_pulang_id  CHAR(36),
    menit_telat     INT NOT NULL DEFAULT 0,
    izin_telat_id   CHAR(36),
    status_pulang   ENUM('tepat_waktu', 'telat', 'lupa_absen'),
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_absensi_shift UNIQUE (jadwal_shift_id),
    CONSTRAINT fk_absensi_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_absensi_jadwal_shift FOREIGN KEY (jadwal_shift_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_absensi_foto_masuk FOREIGN KEY (foto_masuk_id) REFERENCES foto(id) ON DELETE RESTRICT,
    CONSTRAINT fk_absensi_foto_pulang FOREIGN KEY (foto_pulang_id) REFERENCES foto(id) ON DELETE SET NULL,
    CONSTRAINT fk_absensi_izin_telat FOREIGN KEY (izin_telat_id) REFERENCES izin_telat(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- PART 6 — STOK GUDANG, BARANG MASUK/KELUAR, OPNAME & MUTASI
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
    jumlah          DECIMAL(10,3) NOT NULL DEFAULT 0 CHECK (jumlah >= 0),
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_stok_titik UNIQUE (bahan_id, titik),
    CONSTRAINT fk_stok_titik_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE barang_masuk (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id     CHAR(36) NOT NULL,
    keterangan      TEXT,
    waktu           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_barang_masuk_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE barang_masuk_detail (
    id                      CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    barang_masuk_id         CHAR(36) NOT NULL,
    bahan_id                CHAR(36) NOT NULL,
    jumlah_kemasan_besar    INT NOT NULL DEFAULT 0 CHECK (jumlah_kemasan_besar >= 0),
    jumlah_satuan_kecil     DECIMAL(10,3) NOT NULL DEFAULT 0 CHECK (jumlah_satuan_kecil >= 0),
    harga_total             DECIMAL(14,2) NOT NULL CHECK (harga_total > 0),
    CONSTRAINT chk_bmd_jumlah_masuk CHECK (jumlah_kemasan_besar > 0 OR jumlah_satuan_kecil > 0),
    CONSTRAINT fk_bmd_barang_masuk FOREIGN KEY (barang_masuk_id) REFERENCES barang_masuk(id) ON DELETE CASCADE,
    CONSTRAINT fk_bmd_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE barang_keluar (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    titik_tujuan    ENUM('bar', 'kitchen') NOT NULL,
    karyawan_id     CHAR(36) NOT NULL,
    waktu           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_barang_keluar_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE barang_keluar_detail (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    barang_keluar_id    CHAR(36) NOT NULL,
    bahan_id            CHAR(36) NOT NULL,
    jumlah              DECIMAL(10,3) NOT NULL CHECK (jumlah > 0),
    CONSTRAINT fk_bkd_barang_keluar FOREIGN KEY (barang_keluar_id) REFERENCES barang_keluar(id) ON DELETE CASCADE,
    CONSTRAINT fk_bkd_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stok_opname (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    jadwal_shift_id CHAR(36) NOT NULL,
    titik           ENUM('bar', 'kitchen') NOT NULL,
    tipe            ENUM('awal_shift', 'akhir_shift') NOT NULL,
    metode          ENUM('hitung_manual', 'carry_forward') NOT NULL,
    karyawan_id     CHAR(36) NOT NULL,
    susulan         BOOLEAN NOT NULL DEFAULT FALSE,
    diinput_oleh    CHAR(36) NULL,
    waktu_opname    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    catatan         TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_stok_opname UNIQUE (jadwal_shift_id, titik, tipe),
    CONSTRAINT fk_stok_opname_jadwal_shift FOREIGN KEY (jadwal_shift_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_stok_opname_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_stok_opname_diinput_oleh FOREIGN KEY (diinput_oleh) REFERENCES karyawan(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stok_opname_detail (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    stok_opname_id  CHAR(36) NOT NULL,
    bahan_id        CHAR(36) NOT NULL,
    jumlah          DECIMAL(10,3) NOT NULL DEFAULT 0,
    CONSTRAINT fk_sod_stok_opname FOREIGN KEY (stok_opname_id) REFERENCES stok_opname(id) ON DELETE CASCADE,
    CONSTRAINT fk_sod_bahan FOREIGN KEY (bahan_id) REFERENCES bahan(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
-- PART 7 — POS & TRANSAKSI (Dengan hpp_satuan & foto_bukti_qris_id)
-- =====================================================================

CREATE TABLE transaksi (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    jadwal_shift_id     CHAR(36) NOT NULL,
    kasir_id            CHAR(36) NOT NULL,
    nomor_transaksi     VARCHAR(30) NOT NULL UNIQUE,
    metode_bayar        ENUM('cash', 'qris') NOT NULL,
    total_harga         DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (total_harga >= 0),
    uang_diterima       DECIMAL(14,2),
    kembalian           DECIMAL(14,2),
    foto_bukti_qris_id  CHAR(36),
    status              ENUM('selesai', 'dibatalkan') NOT NULL DEFAULT 'selesai',
    waktu_transaksi     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_bukti_bayar CHECK (
        (metode_bayar = 'cash' AND uang_diterima IS NOT NULL) OR
        (metode_bayar = 'qris' AND foto_bukti_qris_id IS NOT NULL)
    ),
    CONSTRAINT fk_transaksi_jadwal_shift FOREIGN KEY (jadwal_shift_id) REFERENCES jadwal_shift(id) ON DELETE RESTRICT,
    CONSTRAINT fk_transaksi_kasir FOREIGN KEY (kasir_id) REFERENCES karyawan(id) ON DELETE RESTRICT,
    CONSTRAINT fk_transaksi_foto_qris FOREIGN KEY (foto_bukti_qris_id) REFERENCES foto(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE transaksi_detail (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    transaksi_id    CHAR(36) NOT NULL,
    menu_id         CHAR(36) NOT NULL,
    qty             INT NOT NULL CHECK (qty > 0),
    harga_satuan    DECIMAL(14,2) NOT NULL,
    hpp_satuan      DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (hpp_satuan >= 0),
    catatan         TEXT,
    subtotal        DECIMAL(14,2) NOT NULL,
    status_item     ENUM('menunggu', 'diproses', 'selesai') NOT NULL DEFAULT 'menunggu',
    CONSTRAINT fk_transaksi_detail_transaksi FOREIGN KEY (transaksi_id) REFERENCES transaksi(id) ON DELETE CASCADE,
    CONSTRAINT fk_transaksi_detail_menu FOREIGN KEY (menu_id) REFERENCES menu(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- PART 8 — REPORTING & PENGELUARAN
-- =====================================================================

CREATE TABLE kategori_pengeluaran (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    nama            VARCHAR(50) NOT NULL UNIQUE,
    status_aktif    BOOLEAN NOT NULL DEFAULT true,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pengeluaran (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    kategori_id     CHAR(36) NOT NULL,
    tipe            ENUM('bulanan', 'mendadak') NOT NULL,
    nominal         DECIMAL(14,2) NOT NULL CHECK (nominal > 0),
    bulan           DATE,
    tanggal         DATE,
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

-- =====================================================================
-- PART 9 — INDEXING
-- =====================================================================

CREATE INDEX idx_transaksi_waktu ON transaksi(waktu_transaksi);
CREATE INDEX idx_jadwal_shift_tanggal ON jadwal_shift(tanggal);
CREATE INDEX idx_absensi_jam_masuk ON absensi(jam_masuk);
CREATE INDEX idx_pengeluaran_bulan ON pengeluaran(bulan);
CREATE INDEX idx_pengeluaran_tanggal ON pengeluaran(tanggal);
CREATE INDEX idx_barang_masuk_waktu ON barang_masuk(waktu);

CREATE INDEX idx_transaksi_status ON transaksi(status);
CREATE INDEX idx_transaksi_detail_status_item ON transaksi_detail(status_item);
CREATE INDEX idx_izin_telat_status ON izin_telat(status);
CREATE INDEX idx_izin_tidak_masuk_status ON izin_tidak_masuk(status);
CREATE INDEX idx_tukar_shift_status ON tukar_shift(status);
CREATE INDEX idx_karyawan_status_aktif ON karyawan(status_aktif);
CREATE INDEX idx_menu_status_aktif ON menu(status_aktif);
CREATE INDEX idx_jadwal_shift_area_kerja ON jadwal_shift(area_kerja);

CREATE INDEX idx_transaksi_status_waktu ON transaksi(status, waktu_transaksi);
CREATE INDEX idx_stok_opname_titik_tipe ON stok_opname(titik, tipe);
CREATE INDEX idx_absensi_karyawan_jam ON absensi(karyawan_id, jam_masuk);
CREATE INDEX idx_pengeluaran_kategori_tipe ON pengeluaran(kategori_id, tipe);

-- =====================================================================
-- PART 10 — AUDIT TRAIL TRIGGER
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
-- PART 11 — SEED DASAR
-- =====================================================================

INSERT INTO shift_template (shift, jam_mulai, jam_selesai) VALUES
    ('shift_1', '08:00:00', '16:00:00'),
    ('shift_2', '16:00:00', '23:00:00');

INSERT INTO kategori_menu (nama, area_produksi) VALUES
    ('Makanan', 'kitchen'),
    ('Minuman', 'bar');

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- SELESAI
-- =====================================================================
