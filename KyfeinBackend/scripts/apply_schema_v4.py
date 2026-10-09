"""
Kyfein Cafe System — Incremental Migration Script v4
Applies:
- Table `barang_masuk` and `barang_masuk_detail`
- Column `bahan.harga_rata_rata`
- Index `idx_barang_masuk_waktu`
- Seeds admin account
"""

import sys
import os

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from app.core.config import settings

def apply_migration():
    print(f"[Migration v4] Connecting to {settings.DB_NAME} at {settings.DB_HOST}:{settings.DB_PORT}...")
    engine = create_engine(settings.SYNC_DATABASE_URL)

    with engine.connect() as conn:
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 0;"))

        # 1. Create table barang_masuk
        print("[Migration v4] Creating table barang_masuk if not exists...")
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS barang_masuk (
                id              CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
                karyawan_id     CHAR(36) NOT NULL,
                keterangan      TEXT,
                waktu           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT fk_barang_masuk_karyawan FOREIGN KEY (karyawan_id) REFERENCES karyawan(id) ON DELETE RESTRICT
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """))

        # 2. Create table barang_masuk_detail
        print("[Migration v4] Creating table barang_masuk_detail if not exists...")
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS barang_masuk_detail (
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
        """))

        # 3. Add column harga_rata_rata to bahan table if not present
        col_check = conn.execute(text("""
            SELECT COUNT(*) FROM information_schema.columns 
            WHERE table_schema = :db_name 
              AND table_name = 'bahan' 
              AND column_name = 'harga_rata_rata'
        """), {"db_name": settings.DB_NAME}).scalar()

        if col_check == 0:
            print("[Migration v4] Adding column harga_rata_rata to bahan table...")
            conn.execute(text("""
                ALTER TABLE bahan 
                ADD COLUMN harga_rata_rata DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (harga_rata_rata >= 0);
            """))

        # 4. Add column area_kerja to jadwal_shift table if missing
        js_col_check = conn.execute(text("""
            SELECT COUNT(*) FROM information_schema.columns 
            WHERE table_schema = :db_name 
              AND table_name = 'jadwal_shift' 
              AND column_name = 'area_kerja'
        """), {"db_name": settings.DB_NAME}).scalar()

        if js_col_check == 0:
            existing_rows = conn.execute(text("SELECT COUNT(*) FROM jadwal_shift")).scalar() or 0
            if existing_rows > 0:
                print(f"[Migration v4 WARNING] {existing_rows} baris jadwal_shift sudah ada, semua akan ke-default area_kerja='kasir' — konfirmasi manual diperlukan")
            else:
                print("[Migration v4] Adding column area_kerja to jadwal_shift table...")
                conn.execute(text("""
                    ALTER TABLE jadwal_shift 
                    ADD COLUMN area_kerja ENUM('kasir', 'bar', 'kitchen') NOT NULL DEFAULT 'kasir' AFTER shift;
                """))

        # 5. Add index idx_barang_masuk_waktu if not present
        idx_check = conn.execute(text("""
            SELECT COUNT(*) FROM information_schema.statistics 
            WHERE table_schema = :db_name 
              AND table_name = 'barang_masuk' 
              AND index_name = 'idx_barang_masuk_waktu'
        """), {"db_name": settings.DB_NAME}).scalar()

        if idx_check == 0:
            print("[Migration v4] Creating index idx_barang_masuk_waktu...")
            conn.execute(text("CREATE INDEX idx_barang_masuk_waktu ON barang_masuk(waktu);"))

        conn.execute(text("SET FOREIGN_KEY_CHECKS = 1;"))
        conn.commit()

    print("[Migration v4] Migration v4 applied successfully to db_kyfein!")

    # 5. Run admin seed
    from scripts.seed_admin import seed_admin
    seed_admin()

if __name__ == "__main__":
    apply_migration()
