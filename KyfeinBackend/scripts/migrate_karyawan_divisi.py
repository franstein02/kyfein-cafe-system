import sys
from pathlib import Path
from sqlalchemy import create_engine, text

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.core.config import settings


def migrate() -> None:
    engine = create_engine(settings.SYNC_DATABASE_URL, echo=False)
    with engine.begin() as conn:
        col_divisi = conn.execute(
            text(
                """
                SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = :db AND TABLE_NAME = 'karyawan' AND COLUMN_NAME = 'divisi'
                """
            ),
            {"db": settings.DB_NAME},
        ).fetchone()

        if not col_divisi:
            conn.execute(
                text(
                    "ALTER TABLE karyawan "
                    "ADD COLUMN divisi ENUM('kasir','bar','kitchen') NULL DEFAULT 'kasir' AFTER role"
                )
            )
            print("Added column karyawan.divisi")
        else:
            print("Column karyawan.divisi already exists")

        col_hp = conn.execute(
            text(
                """
                SELECT IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = :db AND TABLE_NAME = 'karyawan' AND COLUMN_NAME = 'nomor_hp'
                """
            ),
            {"db": settings.DB_NAME},
        ).fetchone()
        if col_hp and col_hp[0] == "NO":
            conn.execute(text("ALTER TABLE karyawan MODIFY COLUMN nomor_hp VARCHAR(20) NULL"))
            print("Updated karyawan.nomor_hp to NULLABLE")
        else:
            print("Column karyawan.nomor_hp already NULLABLE")

        # Backfill divisi for existing accounts safely and idempotently
        conn.execute(text("UPDATE karyawan SET divisi = NULL WHERE role = 'admin'"))
        conn.execute(
            text(
                "UPDATE karyawan SET divisi = 'bar' "
                "WHERE role = 'karyawan' AND (LOWER(nama) LIKE '%bar%' OR LOWER(email) LIKE '%bar%' OR LOWER(email) LIKE '%lianlian2772%')"
            )
        )
        conn.execute(
            text(
                "UPDATE karyawan SET divisi = 'kitchen' "
                "WHERE role = 'karyawan' AND (LOWER(nama) LIKE '%kitchen%' OR LOWER(email) LIKE '%kitchen%' OR LOWER(email) LIKE '%akunsuppdl%')"
            )
        )
        conn.execute(text("UPDATE karyawan SET divisi = 'kasir' WHERE role = 'karyawan' AND divisi IS NULL"))

        rows = conn.execute(
            text("SELECT id, role, divisi, nama, email, nomor_hp, status_aktif FROM karyawan ORDER BY role DESC, nama")
        ).fetchall()
        print("Current karyawan rows:")
        for row in rows:
            print(" ", tuple(row))


if __name__ == "__main__":
    migrate()

