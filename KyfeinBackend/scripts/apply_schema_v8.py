"""
Kyfein Cafe System - Incremental Migration Script v8
Supports dynamic shift templates:
- Converts shift_template.shift from ENUM('shift_1','shift_2') to VARCHAR(50).
- Adds shift_template.nama VARCHAR(100) NOT NULL with backfill ('Shift 1', 'Shift 2', etc.).
- Converts jadwal_shift.shift from ENUM('shift_1','shift_2') to VARCHAR(50).
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import create_engine, text
from app.core.config import settings


def apply_migration() -> None:
    print(f"[Migration v8] Connecting to {settings.DB_NAME} at {settings.DB_HOST}:{settings.DB_PORT}...")
    engine = create_engine(settings.SYNC_DATABASE_URL, echo=False)

    with engine.begin() as conn:
        # 1. shift_template.shift ENUM -> VARCHAR(50)
        tpl_shift_type = conn.execute(
            text(
                """
                SELECT COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = :db AND TABLE_NAME = 'shift_template' AND COLUMN_NAME = 'shift'
                """
            ),
            {"db": settings.DB_NAME},
        ).scalar()

        if tpl_shift_type and tpl_shift_type.lower().startswith("enum("):
            conn.execute(text("ALTER TABLE shift_template MODIFY COLUMN shift VARCHAR(50) NOT NULL"))
            print("[Migration v8] Updated shift_template.shift to VARCHAR(50)")
        else:
            print("[Migration v8] shift_template.shift already VARCHAR")

        # 2. shift_template.nama column
        nama_col = conn.execute(
            text(
                """
                SELECT COLUMN_NAME, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = :db AND TABLE_NAME = 'shift_template' AND COLUMN_NAME = 'nama'
                """
            ),
            {"db": settings.DB_NAME},
        ).fetchone()

        if not nama_col:
            conn.execute(text("ALTER TABLE shift_template ADD COLUMN nama VARCHAR(100) NULL AFTER shift"))
            print("[Migration v8] Added column shift_template.nama")

        conn.execute(
            text(
                """
                UPDATE shift_template
                SET nama = CASE shift
                    WHEN 'shift_1' THEN 'Shift 1'
                    WHEN 'shift_2' THEN 'Shift 2'
                    ELSE CONCAT(UPPER(LEFT(REPLACE(shift, '_', ' '), 1)), SUBSTRING(REPLACE(shift, '_', ' '), 2))
                END
                WHERE nama IS NULL OR TRIM(nama) = ''
                """
            )
        )

        nama_nullable = conn.execute(
            text(
                """
                SELECT IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = :db AND TABLE_NAME = 'shift_template' AND COLUMN_NAME = 'nama'
                """
            ),
            {"db": settings.DB_NAME},
        ).scalar()
        if nama_nullable == "YES":
            conn.execute(text("ALTER TABLE shift_template MODIFY COLUMN nama VARCHAR(100) NOT NULL"))
            print("[Migration v8] Set shift_template.nama to NOT NULL")

        # 3. jadwal_shift.shift ENUM -> VARCHAR(50)
        js_shift_type = conn.execute(
            text(
                """
                SELECT COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = :db AND TABLE_NAME = 'jadwal_shift' AND COLUMN_NAME = 'shift'
                """
            ),
            {"db": settings.DB_NAME},
        ).scalar()

        if js_shift_type and js_shift_type.lower().startswith("enum("):
            conn.execute(text("ALTER TABLE jadwal_shift MODIFY COLUMN shift VARCHAR(50) NOT NULL"))
            print("[Migration v8] Updated jadwal_shift.shift to VARCHAR(50)")
        else:
            print("[Migration v8] jadwal_shift.shift already VARCHAR")

        rows = conn.execute(
            text("SELECT id, shift, nama, jam_mulai, jam_selesai FROM shift_template ORDER BY jam_mulai, shift")
        ).fetchall()
        print("[Migration v8] Current shift_template rows:")
        for row in rows:
            print(" ", tuple(row))

    print("[Migration v8] Completed successfully!")


if __name__ == "__main__":
    apply_migration()

