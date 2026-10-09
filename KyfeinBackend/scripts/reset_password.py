import sys
import os
import getpass

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from app.core.config import settings
from app.core.security import get_password_hash

def reset_password(email):
    print(f"[Reset Password] Connecting to database {settings.DB_NAME} at {settings.DB_HOST}...")
    engine = create_engine(settings.SYNC_DATABASE_URL)
    
    with engine.connect() as conn:
        # Periksa apakah akun admin dengan email tersebut ada
        check_query = text("SELECT id, role FROM karyawan WHERE email = :email")
        existing = conn.execute(check_query, {"email": email}).fetchone()
        
        if not existing:
            print(f"Error: Akun dengan email {email} tidak ditemukan.")
            sys.exit(1)
            
        if existing[1] != 'admin':
            print(f"Peringatan: Akun dengan email {email} bukan admin (role: {existing[1]}). Tetap ganti? [y/N]")
            confirm = input().strip().lower()
            if confirm != 'y':
                print("Dibatalkan.")
                sys.exit(0)
                
        new_password = getpass.getpass(prompt=f"Masukkan password baru untuk {email}: ")
        hashed_password = get_password_hash(new_password)
        
        update_query = text("UPDATE karyawan SET password = :password, updated_at = NOW() WHERE email = :email")
        conn.execute(update_query, {"password": hashed_password, "email": email})
        conn.commit()
        
        print(f"Berhasil: Password untuk {email} telah direset.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Penggunaan: python reset_password.py <email>")
        sys.exit(1)
        
    email_target = sys.argv[1]
    reset_password(email_target)
