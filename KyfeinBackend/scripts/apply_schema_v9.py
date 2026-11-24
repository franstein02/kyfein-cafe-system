"""
Kyfein Cafe System - Incremental Migration Script v9
Memisahkan area bahan baku (bar / kitchen / semua) dan membersihkan stok_titik lintas area:
- Menambahkan kolom bahan.area VARCHAR(20) NOT NULL DEFAULT 'semua' jika belum ada.
- Menandai 14 bahan minuman sebagai area = 'bar'.
- Menghapus baris stok_titik bernilai 0 yang menyantol di titik yang tidak sesuai area bahan.
"""

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import create_engine, text
from app.core.config import settings


BAR_BAHAN_NAMES = (
    "aren",
    "bean",
    "espresso",
    "butterscotch",
    "chocolate",
    "coconut",
    "creamer",
    "cup",
    "matcha",
    "pandan",
    "salted caramel",
    "skm",
    "strawberry",
    "uht",
    "vanila",
)


def apply_migration() -> None:
    print(f"[Migration v9] Connecting to {settings.DB_NAME} at {settings.DB_HOST}:{settings.DB_PORT}...")
    engine = create_engine(settings.SYNC_DATABASE_URL, echo=False)

    with engine.begin() as conn:
        col = conn.execute(
            text(
                """
                SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = :db AND TABLE_NAME = 'bahan' AND COLUMN_NAME = 'area'
                """
            ),
            {"db": settings.DB_NAME},
        ).scalar()

        if not col:
            conn.execute(
                text(
                    "ALTER TABLE bahan ADD COLUMN area VARCHAR(20) NOT NULL DEFAULT 'semua' AFTER satuan"
                )
            )
            print("[Migration v9] Added column bahan.area VARCHAR(20) NOT NULL DEFAULT 'semua'")
        else:
            print("[Migration v9] bahan.area already exists")

        placeholders = ", ".join(f":b{i}" for i in range(len(BAR_BAHAN_NAMES)))
        params = {f"b{i}": name for i, name in enumerate(BAR_BAHAN_NAMES)}
        res_upd = conn.execute(
            text(f"UPDATE bahan SET area = 'bar' WHERE LOWER(nama) IN ({placeholders})"),
            params,
        )
        print(f"[Migration v9] Marked bar ingredients: rowcount={res_upd.rowcount}")

        res_del = conn.execute(
            text(
                """
                DELETE st FROM stok_titik st
                JOIN bahan b ON b.id = st.bahan_id
                WHERE st.jumlah = 0
                  AND (
                    (b.area = 'bar' AND st.titik = 'kitchen')
                    OR (b.area = 'kitchen' AND st.titik = 'bar')
                  )
                """
            )
        )
        print(f"[Migration v9] Cleaned mismatched zero-stock stok_titik rows: rowcount={res_del.rowcount}")


if __name__ == "__main__":
    apply_migration()

