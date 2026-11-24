"""Idempotent migration: make pengeluaran.kategori_id nullable & add nama_pengeluaran."""

import asyncio
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from sqlalchemy import text
from app.core.database import engine


async def migrate() -> None:
    async with engine.begin() as conn:
        col_res = await conn.execute(text("SHOW COLUMNS FROM pengeluaran LIKE 'nama_pengeluaran'"))
        has_nama = col_res.first() is not None

        kat_res = await conn.execute(text("SHOW COLUMNS FROM pengeluaran LIKE 'kategori_id'"))
        kat_row = kat_res.mappings().first()

        if kat_row and str(kat_row.get("Null", "")).upper() != "YES":
            await conn.execute(text("ALTER TABLE pengeluaran MODIFY COLUMN kategori_id CHAR(36) NULL"))
            print("Updated pengeluaran.kategori_id -> NULL")
        else:
            print("pengeluaran.kategori_id already NULL")

        if not has_nama:
            await conn.execute(
                text(
                    "ALTER TABLE pengeluaran "
                    "ADD COLUMN nama_pengeluaran VARCHAR(150) NULL AFTER kategori_id"
                )
            )
            print("Added column pengeluaran.nama_pengeluaran")
        else:
            print("pengeluaran.nama_pengeluaran already exists")


if __name__ == "__main__":
    asyncio.run(migrate())

