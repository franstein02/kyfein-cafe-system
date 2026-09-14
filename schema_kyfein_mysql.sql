-- =====================================================================
-- KYFEIN CAFE SYSTEM — SKEMA MySQL / MariaDB (bawaan Laragon)
-- Scope: 6 fitur utama (POS+Takaran, Stok Gudang & Titik, Absensi,
--        Jadwal Shift, Layar Pesanan/KDS, Reporting & Pengeluaran)
--        + Master Data + Role & Hak Akses
-- Tanpa: QR ordering pelanggan, payroll/gaji, kas bon, supplier,
--        multi-cabang/rombong (di luar scope rencana pengembangan)
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
    updated_by      CHAR(36) REFERENCES karyawan(id),
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


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
    kategori_id     CHAR(36) NOT NULL REFERENCES kategori_menu(id),
    foto            TEXT,
    status_aktif    BOOLEAN NOT NULL DEFAULT true, -- toggle stok habis/tersedia
    dibuat_oleh     CHAR(36) REFERENCES karyawan(id),
    diubah_oleh     CHAR(36) REFERENCES karyawan(id),
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE bahan (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    nama            VARCHAR(100) NOT NULL,
    satuan          VARCHAR(20) NOT NULL, -- ml/gram/pcs, dll
    isi_per_kemasan DECIMAL(10,3), -- konversi kemasan besar -> satuan kecil, khusus internal gudang (3.2)
    stok_minimum    DECIMAL(10,3) NOT NULL DEFAULT 0, -- reminder stok menipis di Reporting (3.6)
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE menu_resep (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    menu_id         CHAR(36) NOT NULL REFERENCES menu(id),
    bahan_id        CHAR(36) NOT NULL REFERENCES bahan(id),
    jumlah_terpakai DECIMAL(10,3) NOT NULL CHECK (jumlah_terpakai > 0), -- takaran per 1 unit menu terjual
    CONSTRAINT uq_menu_resep UNIQUE (menu_id, bahan_id),
    FOREIGN KEY (menu_id) REFERENCES menu(id) ON DELETE CASCADE
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
    karyawan_id         CHAR(36) NOT NULL REFERENCES karyawan(id),
    tanggal             DATE NOT NULL,
    shift               ENUM('shift_1', 'shift_2') NOT NULL,
    shift_template_id   CHAR(36) REFERENCES shift_template(id), -- jejak referensi saja
    jam_mulai           TIME NOT NULL, -- snapshot dari template atau manual
    jam_selesai         TIME NOT NULL,
    dibuat_oleh         CHAR(36) REFERENCES karyawan(id),
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_karyawan_tanggal UNIQUE (karyawan_id, tanggal) -- 1 karyawan tidak boleh 2 shift/tanggal
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE tukar_shift (
    id                      CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    shift_a_id              CHAR(36) NOT NULL REFERENCES jadwal_shift(id),
    shift_b_id              CHAR(36) NOT NULL REFERENCES jadwal_shift(id),
    karyawan_pengaju_id     CHAR(36) NOT NULL REFERENCES karyawan(id),
    karyawan_target_id      CHAR(36) NOT NULL REFERENCES karyawan(id),
    status                  ENUM('pending', 'disetujui', 'ditolak') NOT NULL DEFAULT 'pending', -- approval oleh Admin
    alasan                  TEXT,
    diajukan_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    diproses_oleh           CHAR(36) REFERENCES karyawan(id),
    diproses_at             DATETIME,
    CONSTRAINT chk_tukar_shift_beda_row CHECK (shift_a_id <> shift_b_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE request_off (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id     CHAR(36) NOT NULL REFERENCES karyawan(id),
    tanggal         DATE NOT NULL,
    alasan          TEXT,
    diajukan_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    -- tanpa approval workflow (lihat 3.4) — visible ke semua karyawan lewat query biasa
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =====================================================================
-- 3.3 ABSENSI (Poin 3)
-- =====================================================================

CREATE TABLE izin_telat (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id         CHAR(36) NOT NULL REFERENCES karyawan(id),
    jadwal_shift_id     CHAR(36) NOT NULL REFERENCES jadwal_shift(id),
    alasan              TEXT NOT NULL,
    foto_url            TEXT, -- opsional/bebas
    status              ENUM('pending', 'disetujui', 'ditolak') NOT NULL DEFAULT 'pending',
    diajukan_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    diproses_oleh       CHAR(36) REFERENCES karyawan(id),
    diproses_at         DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE izin_tidak_masuk (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id         CHAR(36) NOT NULL REFERENCES karyawan(id),
    jadwal_shift_id     CHAR(36) NOT NULL REFERENCES jadwal_shift(id),
    alasan              TEXT NOT NULL,
    foto_url            TEXT NOT NULL, -- wajib: surat dokter/bukti musibah, dll
    status              ENUM('pending', 'disetujui', 'ditolak') NOT NULL DEFAULT 'pending',
    diajukan_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    diproses_oleh       CHAR(36) REFERENCES karyawan(id),
    diproses_at         DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE absensi (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    karyawan_id     CHAR(36) NOT NULL REFERENCES karyawan(id),
    jadwal_shift_id CHAR(36) NOT NULL REFERENCES jadwal_shift(id),
    jam_masuk       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    jam_pulang      DATETIME,
    lat_masuk       DECIMAL(11,8) NOT NULL,
    lng_masuk       DECIMAL(11,8) NOT NULL,
    lat_pulang      DECIMAL(11,8),
    lng_pulang      DECIMAL(11,8),
    foto_masuk      TEXT NOT NULL,
    foto_pulang     TEXT,
    menit_telat     INT NOT NULL DEFAULT 0, -- selisih jam_masuk vs jadwal_shift.jam_mulai
    izin_telat_id   CHAR(36) REFERENCES izin_telat(id), -- di-set kalau telat ini di-cover izin yang disetujui
    status_pulang   ENUM('tepat_waktu', 'telat', 'lupa_absen'), -- NULL selama belum absen pulang
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_absensi_shift UNIQUE (jadwal_shift_id) -- 1 shift cuma 1 absensi
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =====================================================================
-- 3.2 STOK GUDANG & STOK BAR/KITCHEN (Poin 2)
-- =====================================================================

CREATE TABLE stok_gudang (
    id                      CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    bahan_id                CHAR(36) NOT NULL UNIQUE REFERENCES bahan(id),
    jumlah_kemasan_besar    INT NOT NULL DEFAULT 0 CHECK (jumlah_kemasan_besar >= 0),
    jumlah_satuan_kecil     DECIMAL(10,3) NOT NULL DEFAULT 0 CHECK (jumlah_satuan_kecil >= 0),
    updated_at              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stok_titik (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    bahan_id        CHAR(36) NOT NULL REFERENCES bahan(id),
    titik           ENUM('bar', 'kitchen') NOT NULL,
    jumlah          DECIMAL(10,3) NOT NULL DEFAULT 0 CHECK (jumlah >= 0), -- hasil opname terakhir, bukan hitungan otomatis
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_stok_titik UNIQUE (bahan_id, titik)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE barang_keluar (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    titik_tujuan    ENUM('bar', 'kitchen') NOT NULL,
    karyawan_id     CHAR(36) NOT NULL REFERENCES karyawan(id), -- wajib, siapa yang ambil
    waktu           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE barang_keluar_detail (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    barang_keluar_id    CHAR(36) NOT NULL REFERENCES barang_keluar(id),
    bahan_id            CHAR(36) NOT NULL REFERENCES bahan(id),
    jumlah              DECIMAL(10,3) NOT NULL CHECK (jumlah > 0), -- satuan kecil
    FOREIGN KEY (barang_keluar_id) REFERENCES barang_keluar(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stok_opname (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    jadwal_shift_id CHAR(36) NOT NULL REFERENCES jadwal_shift(id),
    titik           ENUM('bar', 'kitchen') NOT NULL,
    tipe            ENUM('awal_shift', 'akhir_shift') NOT NULL, -- keduanya blocking
    metode          ENUM('hitung_manual', 'carry_forward') NOT NULL, -- hitung_manual (cross-day) / carry_forward (same-day)
    karyawan_id     CHAR(36) NOT NULL REFERENCES karyawan(id), -- wajib = karyawan assigned di shift itu
    waktu_opname    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    catatan         TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_stok_opname UNIQUE (jadwal_shift_id, titik, tipe)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stok_opname_detail (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    stok_opname_id  CHAR(36) NOT NULL REFERENCES stok_opname(id),
    bahan_id        CHAR(36) NOT NULL REFERENCES bahan(id),
    jumlah          DECIMAL(10,3) NOT NULL DEFAULT 0, -- hasil hitung fisik, raw, tidak dikonversi
    FOREIGN KEY (stok_opname_id) REFERENCES stok_opname(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Audit trail selisih handover (3.2) — dicatat otomatis oleh app layer saat opname awal_shift disubmit
CREATE TABLE mutasi_stok (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    bahan_id            CHAR(36) NOT NULL REFERENCES bahan(id),
    titik               ENUM('bar', 'kitchen'),
    jadwal_shift_id     CHAR(36) REFERENCES jadwal_shift(id),
    tipe                VARCHAR(50) NOT NULL DEFAULT 'selisih_handover',
    jumlah_selisih      DECIMAL(10,3) NOT NULL,
    keterangan          TEXT,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =====================================================================
-- 3.1 POS & TRANSAKSI (Poin 1) — Takaran & Selisih Stok
-- =====================================================================

CREATE TABLE transaksi (
    id                  CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    jadwal_shift_id     CHAR(36) NOT NULL REFERENCES jadwal_shift(id),
    kasir_id            CHAR(36) NOT NULL REFERENCES karyawan(id), -- denormalisasi dari jadwal_shift
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
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE transaksi_detail (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    transaksi_id    CHAR(36) NOT NULL REFERENCES transaksi(id),
    menu_id         CHAR(36) NOT NULL REFERENCES menu(id),
    qty             INT NOT NULL CHECK (qty > 0),
    harga_satuan    DECIMAL(14,2) NOT NULL, -- snapshot harga saat transaksi, bukan live-lookup
    catatan         TEXT, -- mis. "less sugar", request customer
    subtotal        DECIMAL(14,2) NOT NULL,
    status_item     ENUM('menunggu', 'diproses', 'selesai') NOT NULL DEFAULT 'menunggu', -- dipakai Layar Pesanan/KDS (3.5)
    FOREIGN KEY (transaksi_id) REFERENCES transaksi(id) ON DELETE CASCADE
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
    kategori_id     CHAR(36) NOT NULL REFERENCES kategori_pengeluaran(id),
    tipe            ENUM('bulanan', 'mendadak') NOT NULL,
    nominal         DECIMAL(14,2) NOT NULL CHECK (nominal > 0),
    bulan           DATE, -- wajib kalau tipe='bulanan', dipecah / jumlah hari di bulan itu
    tanggal         DATE, -- wajib kalau tipe='mendadak', dicatat penuh di hari itu
    keterangan      TEXT,
    dicatat_oleh    CHAR(36) REFERENCES karyawan(id),
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_pengeluaran_periode CHECK (
        (tipe = 'bulanan' AND bulan IS NOT NULL AND tanggal IS NULL) OR
        (tipe = 'mendadak' AND tanggal IS NOT NULL AND bulan IS NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan: HPP harian dihitung on-demand dari menu_resep x transaksi_detail
-- terjual (status transaksi='selesai') per tanggal — tidak ada tabel snapshot.


-- =====================================================================
-- PART 5 — INDEXING
-- =====================================================================
-- Catatan: MySQL/MariaDB tidak mendukung partial/filtered index (WHERE
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

-- FK index manual (praktik baik walau MySQL InnoDB auto-index kolom FK)
CREATE INDEX idx_menu_kategori ON menu(kategori_id);
CREATE INDEX idx_menu_resep_menu ON menu_resep(menu_id);
CREATE INDEX idx_menu_resep_bahan ON menu_resep(bahan_id);
CREATE INDEX idx_jadwal_shift_karyawan ON jadwal_shift(karyawan_id);
CREATE INDEX idx_tukar_shift_shift_a ON tukar_shift(shift_a_id);
CREATE INDEX idx_tukar_shift_shift_b ON tukar_shift(shift_b_id);
CREATE INDEX idx_request_off_karyawan ON request_off(karyawan_id);
CREATE INDEX idx_izin_telat_karyawan ON izin_telat(karyawan_id);
CREATE INDEX idx_izin_telat_jadwal_shift ON izin_telat(jadwal_shift_id);
CREATE INDEX idx_izin_tidak_masuk_karyawan ON izin_tidak_masuk(karyawan_id);
CREATE INDEX idx_izin_tidak_masuk_jadwal_shift ON izin_tidak_masuk(jadwal_shift_id);
CREATE INDEX idx_absensi_karyawan ON absensi(karyawan_id);
CREATE INDEX idx_stok_gudang_bahan ON stok_gudang(bahan_id);
CREATE INDEX idx_stok_titik_bahan ON stok_titik(bahan_id);
CREATE INDEX idx_barang_keluar_karyawan ON barang_keluar(karyawan_id);
CREATE INDEX idx_barang_keluar_detail_keluar ON barang_keluar_detail(barang_keluar_id);
CREATE INDEX idx_barang_keluar_detail_bahan ON barang_keluar_detail(bahan_id);
CREATE INDEX idx_stok_opname_jadwal_shift ON stok_opname(jadwal_shift_id);
CREATE INDEX idx_stok_opname_detail_opname ON stok_opname_detail(stok_opname_id);
CREATE INDEX idx_mutasi_stok_bahan ON mutasi_stok(bahan_id);
CREATE INDEX idx_transaksi_jadwal_shift ON transaksi(jadwal_shift_id);
CREATE INDEX idx_transaksi_kasir ON transaksi(kasir_id);
CREATE INDEX idx_transaksi_detail_transaksi ON transaksi_detail(transaksi_id);
CREATE INDEX idx_transaksi_detail_menu ON transaksi_detail(menu_id);
CREATE INDEX idx_pengeluaran_kategori ON pengeluaran(kategori_id);

-- Index status (pengganti partial index — dikombinasi dengan kolom lain yang sering difilter bareng)
CREATE INDEX idx_transaksi_status ON transaksi(status);
CREATE INDEX idx_transaksi_detail_status_item ON transaksi_detail(status_item); -- query KDS realtime
CREATE INDEX idx_izin_telat_status ON izin_telat(status);
CREATE INDEX idx_izin_tidak_masuk_status ON izin_tidak_masuk(status);
CREATE INDEX idx_tukar_shift_status ON tukar_shift(status);
CREATE INDEX idx_karyawan_status_aktif ON karyawan(status_aktif);
CREATE INDEX idx_menu_status_aktif ON menu(status_aktif);


-- =====================================================================
-- PART 5 — AUDIT TRAIL TRIGGER (scope: tabel konfigurasi_* saja)
-- =====================================================================

CREATE TABLE audit_log_konfigurasi (
    id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    tabel           VARCHAR(50) NOT NULL,
    row_id          CHAR(36) NOT NULL,
    data_lama       JSON,
    data_baru       JSON,
    diubah_oleh     CHAR(36),
    diubah_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
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
