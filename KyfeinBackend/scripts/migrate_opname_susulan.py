import asyncio
from sqlalchemy import text
from app.core.database import engine

async def run_migration():
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TABLE stok_opname ADD COLUMN susulan BOOLEAN NOT NULL DEFAULT FALSE;"))
            print("Column 'susulan' added.")
        except Exception as e:
            print("Column 'susulan' might already exist:", e)

        try:
            await conn.execute(text("ALTER TABLE stok_opname ADD COLUMN diinput_oleh CHAR(36) NULL;"))
            print("Column 'diinput_oleh' added.")
        except Exception as e:
            print("Column 'diinput_oleh' might already exist:", e)

        try:
            await conn.execute(text("ALTER TABLE stok_opname ADD CONSTRAINT fk_stok_opname_diinput_oleh FOREIGN KEY (diinput_oleh) REFERENCES karyawan(id) ON DELETE SET NULL;"))
            print("FK 'fk_stok_opname_diinput_oleh' added.")
        except Exception as e:
            print("FK 'fk_stok_opname_diinput_oleh' might already exist:", e)

if __name__ == "__main__":
    asyncio.run(run_migration())
