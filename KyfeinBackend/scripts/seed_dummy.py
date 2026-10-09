import sys
import os
import uuid

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from app.core.config import settings
from app.core.security import get_password_hash

def seed_dummies():
    engine = create_engine(settings.SYNC_DATABASE_URL)
    hashed_password = get_password_hash("123")
    
    users = [
        ("admin@kyfein.cafe", "admin", "Admin"),
        ("manager@kyfein.cafe", "karyawan", "Manager"),
        ("kasir@kyfein.cafe", "karyawan", "Kasir"),
        ("barista@kyfein.cafe", "karyawan", "Barista")
    ]
    
    with engine.connect() as conn:
        for email, role, nama in users:
            check = conn.execute(text("SELECT id FROM karyawan WHERE email = :email"), {"email": email}).fetchone()
            if check:
                conn.execute(text("UPDATE karyawan SET password = :password WHERE email = :email"), 
                             {"password": hashed_password, "email": email})
                print(f"Updated password for {email} to 123")
            else:
                conn.execute(text("""
                    INSERT INTO karyawan (id, role, nama, email, nomor_hp, password, status_aktif, created_at, updated_at)
                    VALUES (:id, :role, :nama, :email, '081234567890', :password, true, NOW(), NOW())
                """), {"id": str(uuid.uuid4()), "role": role, "nama": nama, "email": email, "password": hashed_password})
                print(f"Created new {role} user: {email} with password 123")
        conn.commit()
    print("Done!")

if __name__ == "__main__":
    seed_dummies()
