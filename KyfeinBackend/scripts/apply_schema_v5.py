"""
Kyfein Cafe System — Incremental Migration Script v5
Applies Issue 1:
- Table `foto`
- FK `absensi.foto_masuk_id`, `absensi.foto_pulang_id`
- FK `izin_telat.foto_id`
- FK `izin_tidak_masuk.foto_id`
- FK `transaksi.foto_bukti_qris_id`
- FK `menu.foto_id`
- FK `karyawan.foto_profile_id`
"""

import sys
import os

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from app.core.config import settings

def apply_migration():
    print(f"[Migration v5] Connecting to {settings.DB_NAME} at {settings.DB_HOST}:{settings.DB_PORT}...")
    engine = create_engine(settings.SYNC_DATABASE_URL)

    with engine.connect() as conn:
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 0;"))

        # 1. Create table foto
        print("[Migration v5] Creating table foto if not exists...")
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS foto (
                id              CHAR(36) NOT NULL PRIMARY KEY,
                jenis           ENUM('absensi', 'izin', 'qris', 'menu', 'profil') NOT NULL,
                path            VARCHAR(500) NOT NULL,
                uploader_id     CHAR(36) NOT NULL,
                dipakai         TINYINT(1) NOT NULL DEFAULT 0,
                created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_foto_dipakai_created (dipakai, created_at),
                CONSTRAINT fk_foto_uploader FOREIGN KEY (uploader_id) REFERENCES karyawan(id) ON DELETE RESTRICT
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """))

        def add_column_if_not_exists(table, column, col_def):
            col_check = conn.execute(text("""
                SELECT COUNT(*) FROM information_schema.columns 
                WHERE table_schema = :db_name 
                  AND table_name = :table 
                  AND column_name = :column
            """), {"db_name": settings.DB_NAME, "table": table, "column": column}).scalar()
            if col_check == 0:
                print(f"[Migration v5] Adding column {column} to {table}...")
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {col_def};"))

        add_column_if_not_exists("absensi", "foto_masuk_id", "CHAR(36) NULL")
        add_column_if_not_exists("absensi", "foto_pulang_id", "CHAR(36) NULL")
        add_column_if_not_exists("izin_telat", "foto_id", "CHAR(36) NULL")
        add_column_if_not_exists("izin_tidak_masuk", "foto_id", "CHAR(36) NULL")
        add_column_if_not_exists("transaksi", "foto_bukti_qris_id", "CHAR(36) NULL")
        add_column_if_not_exists("menu", "foto_id", "CHAR(36) NULL")
        add_column_if_not_exists("karyawan", "foto_profile_id", "CHAR(36) NULL")

        conn.execute(text("SET FOREIGN_KEY_CHECKS = 1;"))
        conn.commit()

    print("[Migration v5] Migration v5 applied successfully!")

if __name__ == "__main__":
    apply_migration()
