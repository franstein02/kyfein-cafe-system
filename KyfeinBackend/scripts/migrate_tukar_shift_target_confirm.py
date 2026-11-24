"""
Migrasi idempoten MySQL:
Menambahkan kolom `status_target` dan `dikonfirmasi_target_at` pada tabel `tukar_shift`
untuk alur konfirmasi dua tahap (rekan target -> admin).
"""
import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text
from app.core.database import engine


async def migrate():
    async with engine.begin() as conn:
        cols_res = await conn.execute(
            text(
                """
                SELECT COLUMN_NAME
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = 'tukar_shift'
                """
            )
        )
        existing_cols = {row[0] for row in cols_res.fetchall()}

        if "status_target" not in existing_cols:
            await conn.execute(
                text(
                    """
                    ALTER TABLE tukar_shift
                    ADD COLUMN status_target ENUM('pending', 'disetujui', 'ditolak')
                    NOT NULL DEFAULT 'pending'
                    AFTER status
                    """
                )
            )
            print("Added column tukar_shift.status_target")
        else:
            print("Column tukar_shift.status_target already exists")

        if "dikonfirmasi_target_at" not in existing_cols:
            await conn.execute(
                text(
                    """
                    ALTER TABLE tukar_shift
                    ADD COLUMN dikonfirmasi_target_at DATETIME NULL
                    AFTER status_target
                    """
                )
            )
            print("Added column tukar_shift.dikonfirmasi_target_at")
        else:
            print("Column tukar_shift.dikonfirmasi_target_at already exists")

        # Sinkronkan baris lama yang sudah selesai diproses agar konsisten
        await conn.execute(
            text(
                """
                UPDATE tukar_shift
                SET status_target = status,
                    dikonfirmasi_target_at = COALESCE(dikonfirmasi_target_at, diproses_at)
                WHERE status IN ('disetujui', 'ditolak')
                  AND status_target = 'pending'
                """
            )
        )
        print("Migration tukar_shift target confirmation complete.")


if __name__ == "__main__":
    asyncio.run(migrate())
