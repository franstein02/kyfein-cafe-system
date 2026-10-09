import asyncio
from app.core.database import AsyncSessionLocal
from app.models.karyawan import Karyawan
from sqlalchemy import text

async def main():
    async with AsyncSessionLocal() as db:
        # Check current enum values
        result = await db.execute(text("SHOW COLUMNS FROM karyawan LIKE 'role'"))
        row = result.fetchone()
        
        if not row:
            print("Tabel karyawan atau kolom role tidak ditemukan.")
            return

        enum_def = row[1]
        print(f"Definisi role saat ini: {enum_def}")
        
        if enum_def == "enum('karyawan','admin')":
            print("Role ENUM sudah benar, migrasi dilewati.")
            return
            
        # Hitung baris karyawan dengan role = 'owner'
        owners = await db.execute(text("SELECT id, email FROM karyawan WHERE role = 'owner'"))
        owner_rows = owners.fetchall()
        print(f"Ditemukan {len(owner_rows)} akun dengan role 'owner':")
        for row in owner_rows:
            print(f"- ID: {row[0]}, Email: {row[1]}")
            
        # Ubah role owner menjadi admin
        if owner_rows:
            await db.execute(text("UPDATE karyawan SET role = 'admin' WHERE role = 'owner'"))
            await db.commit()
            print("Berhasil mengubah role owner menjadi admin.")
            
        # Ubah ENUM definition
        print("Mengubah ENUM role...")
        await db.execute(text("ALTER TABLE karyawan MODIFY role ENUM('karyawan','admin') NOT NULL"))
        await db.commit()
        print("Migrasi selesai.")

if __name__ == "__main__":
    asyncio.run(main())
