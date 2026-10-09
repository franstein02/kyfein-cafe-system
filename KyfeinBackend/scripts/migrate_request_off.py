import asyncio
from sqlalchemy import text
from app.core.database import engine

async def run_migration():
    async with engine.begin() as conn:
        # 1. Cek duplikat
        check_query = text("""
            SELECT karyawan_id, tanggal, COUNT(*) as cnt
            FROM request_off
            GROUP BY karyawan_id, tanggal
            HAVING cnt > 1
        """)
        result = await conn.execute(check_query)
        duplicates = result.fetchall()
        
        if duplicates:
            print("MIGRATION DIBATALKAN: Ditemukan duplikat data pada request_off.")
            for row in duplicates:
                print(f"karyawan_id: {row.karyawan_id}, tanggal: {row.tanggal}, jumlah: {row.cnt}")
            return
            
        # 2. Tambah constraint jika belum ada
        try:
            alter_query = text("""
                ALTER TABLE request_off 
                ADD CONSTRAINT uq_request_off_karyawan_tanggal UNIQUE (karyawan_id, tanggal)
            """)
            await conn.execute(alter_query)
            print("Migration berhasil: constraint uq_request_off_karyawan_tanggal ditambahkan.")
        except Exception as e:
            if "Duplicate key name" in str(e):
                print("Constraint sudah ada, abaikan.")
            else:
                print(f"Error alter table: {e}")

if __name__ == "__main__":
    asyncio.run(run_migration())
