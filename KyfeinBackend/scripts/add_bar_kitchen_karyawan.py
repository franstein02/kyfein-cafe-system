import sys
import os
import uuid

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from app.core.config import settings
from app.core.security import get_password_hash

def add_bar_and_kitchen():
    print(f"Connecting to database {settings.DB_NAME} at {settings.DB_HOST}...")
    engine = create_engine(settings.SYNC_DATABASE_URL)
    hashed_password = get_password_hash("password123")
    
    users = [
        {
            "nama": "Budi (Bar)",
            "email": "barista@kyfein.cafe",
            "nomor_hp": "081299900002",
            "role": "karyawan"
        },
        {
            "nama": "Siti (Kitchen)",
            "email": "kitchen@kyfein.cafe",
            "nomor_hp": "081299900003",
            "role": "karyawan"
        }
    ]
    
    with engine.connect() as conn:
        for u in users:
            check = conn.execute(
                text("SELECT id, nama FROM karyawan WHERE email = :email"),
                {"email": u["email"]}
            ).fetchone()
            
            if check:
                conn.execute(
                    text("""
                        UPDATE karyawan 
                        SET nama = :nama, nomor_hp = :nomor_hp, password = :password, status_aktif = 1, updated_at = NOW() 
                        WHERE email = :email
                    """),
                    {
                        "nama": u["nama"],
                        "nomor_hp": u["nomor_hp"],
                        "password": hashed_password,
                        "email": u["email"]
                    }
                )
                print(f"[OK] Updated existing user: {u['nama']} ({u['email']}) [ID: {check[0]}]")
            else:
                user_id = str(uuid.uuid4())
                conn.execute(
                    text("""
                        INSERT INTO karyawan (id, role, nama, email, nomor_hp, password, status_aktif, created_at, updated_at)
                        VALUES (:id, :role, :nama, :email, :nomor_hp, :password, 1, NOW(), NOW())
                    """),
                    {
                        "id": user_id,
                        "role": u["role"],
                        "nama": u["nama"],
                        "email": u["email"],
                        "nomor_hp": u["nomor_hp"],
                        "password": hashed_password
                    }
                )
                print(f"[OK] Created new user: {u['nama']} ({u['email']}) [ID: {user_id}]")
        
        conn.commit()
        
        rows = conn.execute(text("SELECT id, nama, email, role, nomor_hp, status_aktif FROM karyawan")).fetchall()
        print("\n=== Current Karyawan List ===")
        for r in rows:
            print(f"- ID: {r[0]} | Nama: {r[1]} | Email: {r[2]} | Role: {r[3]} | HP: {r[4]} | Aktif: {r[5]}")

if __name__ == "__main__":
    add_bar_and_kitchen()

