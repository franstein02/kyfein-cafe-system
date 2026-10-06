"""
Kyfein Cafe System — Incremental Migration & Backfill Script v6
Applies Issue 3 & Issue 8:
- Adds column `transaksi_detail.hpp_satuan DECIMAL(14,2) NOT NULL DEFAULT 0`
- Performs once-off backfill calculation ONLY when hpp_satuan is first created, using current `bahan.harga_rata_rata`.
- Re-running script safely skips column addition & backfill to protect historic snapshot HPP values.
"""

import sys
import os

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from app.core.config import settings

def apply_migration():
    print(f"[Migration v6] Connecting to {settings.DB_NAME} at {settings.DB_HOST}:{settings.DB_PORT}...")
    engine = create_engine(settings.SYNC_DATABASE_URL)

    with engine.connect() as conn:
        # 1. Check if bahan.harga_rata_rata exists before backfill
        bahan_col_check = conn.execute(text("""
            SELECT COUNT(*) FROM information_schema.columns 
            WHERE table_schema = :db_name 
              AND table_name = 'bahan' 
              AND column_name = 'harga_rata_rata'
        """), {"db_name": settings.DB_NAME}).scalar()

        if bahan_col_check == 0:
            print("[Migration v6 Error] Kolom 'harga_rata_rata' pada tabel 'bahan' tidak ditemukan. Mohon jalankan migrasi v4/v5 terlebih dahulu.")
            sys.exit(1)

        # 2. Check if hpp_satuan already exists in transaksi_detail
        col_check = conn.execute(text("""
            SELECT COUNT(*) FROM information_schema.columns 
            WHERE table_schema = :db_name 
              AND table_name = 'transaksi_detail' 
              AND column_name = 'hpp_satuan'
        """), {"db_name": settings.DB_NAME}).scalar()

        if col_check == 0:
            print("[Migration v6] Adding column hpp_satuan to transaksi_detail...")
            conn.execute(text("ALTER TABLE transaksi_detail ADD COLUMN hpp_satuan DECIMAL(14,2) NOT NULL DEFAULT 0;"))

            # Perform backfill ONCE-OFF inside col_check == 0
            print("[Migration v6] Backfilling hpp_satuan for existing transaksi_detail records...")
            conn.execute(text("""
                UPDATE transaksi_detail td
                SET hpp_satuan = COALESCE(
                    (
                        SELECT SUM(mr.jumlah_terpakai * b.harga_rata_rata)
                        FROM menu_resep mr
                        JOIN bahan b ON mr.bahan_id = b.id
                        WHERE mr.menu_id = td.menu_id
                    ), 0
                );
            """))
            conn.commit()
            print("[Migration v6] Migration & Backfill v6 completed successfully! (Note: Backfilled HPP values use current average ingredient prices as estimate).")
        else:
            print("[Migration v6] Kolom hpp_satuan sudah ada. Migrasi dan backfill dilewati untuk melindungi snapshot HPP yang ada.")

if __name__ == "__main__":
    apply_migration()
