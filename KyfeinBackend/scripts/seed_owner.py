"""
Kyfein Cafe System — Owner Account Seed Script
Sesuai dokumen rencana pengembangan (Bagian 4.3):
Akun Owner di-seed manual langsung di database (bukan dibuat lewat UI/endpoint aplikasi)
untuk mencegah celah role-elevation yang tidak disengaja.
"""

import sys
import os
import uuid
from datetime import datetime

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from app.core.config import settings
from app.core.security import get_password_hash

def seed_owner():
    print(f"[Seed Owner] Connecting to database {settings.DB_NAME} at {settings.DB_HOST}...")
    engine = create_engine(settings.SYNC_DATABASE_URL)
    
    owner_email = "owner@kyfein.cafe"
    owner_password = "OwnerPassword123!" # Silakan ubah password ini setelah seed pertama
    hashed_password = get_password_hash(owner_password)
    owner_id = str(uuid.uuid4())
    
    with engine.connect() as conn:
        # Check if owner already exists
        check_query = text("SELECT id, email FROM karyawan WHERE role = 'owner' LIMIT 1")
        existing = conn.execute(check_query).fetchone()
        
        if existing:
            print(f"[Seed Owner] Akun Owner sudah ada di database (ID: {existing[0]}, Email: {existing[1]}). Skipping.")
            return
            
        insert_query = text("""
            INSERT INTO karyawan (id, role, nama, email, nomor_hp, password, status_aktif, created_at, updated_at)
            VALUES (:id, 'owner', 'Owner Kyfein Cafe', :email, '081234567890', :password, true, NOW(), NOW())
        """)
        
        conn.execute(insert_query, {
            "id": owner_id,
            "email": owner_email,
            "password": hashed_password
        })
        conn.commit()
        
        print("==========================================================")
        print("SUCCESS: Akun Owner berhasil di-seed langsung ke db_kyfein!")
        print(f"Email    : {owner_email}")
        print(f"Password : {owner_password}")
        print("PERINGATAN: Harap catat kredensial di atas dan segera ubah password!")
        print("==========================================================")

if __name__ == "__main__":
    seed_owner()
