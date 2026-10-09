"""
Kyfein Cafe System — Admin Account Seed Script
Sesuai dokumen rencana pengembangan:
Akun Admin awal di-seed manual langsung di database (bukan dibuat lewat UI/endpoint aplikasi)
untuk mencegah celah role-elevation yang tidak disengaja.
"""

import sys
import os
import uuid
import getpass
from datetime import datetime

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from app.core.config import settings
from app.core.security import get_password_hash

def seed_admin():
    print(f"[Seed Admin] Connecting to database {settings.DB_NAME} at {settings.DB_HOST}...")
    engine = create_engine(settings.SYNC_DATABASE_URL)
    
    admin_email = os.environ.get("KYFEIN_ADMIN_EMAIL", "admin@kyfein.cafe")
    admin_password = os.environ.get("KYFEIN_ADMIN_PASSWORD")
    if not admin_password:
        admin_password = getpass.getpass(prompt="Masukkan password untuk admin baru: ")
    
    hashed_password = get_password_hash(admin_password)
    admin_id = str(uuid.uuid4())
    
    with engine.connect() as conn:
        # Check if admin already exists
        check_query = text("SELECT id, email FROM karyawan WHERE role = 'admin' LIMIT 1")
        existing = conn.execute(check_query).fetchone()
        
        if existing:
            print(f"[Seed Admin] Akun Admin sudah ada di database (ID: {existing[0]}, Email: {existing[1]}). Skipping.")
            return
            
        insert_query = text("""
            INSERT INTO karyawan (id, role, nama, email, nomor_hp, password, status_aktif, created_at, updated_at)
            VALUES (:id, 'admin', 'Admin Kyfein Cafe', :email, '081234567890', :password, true, NOW(), NOW())
        """)
        
        conn.execute(insert_query, {
            "id": admin_id,
            "email": admin_email,
            "password": hashed_password
        })
        conn.commit()
        
        print("==========================================================")
        print("SUCCESS: Akun Admin berhasil di-seed langsung ke db_kyfein!")
        print(f"Email    : {admin_email}")
        print(f"Password : {admin_password}")
        print("PERINGATAN: Harap catat kredensial di atas dan segera ubah password!")
        print("==========================================================")

if __name__ == "__main__":
    seed_admin()
