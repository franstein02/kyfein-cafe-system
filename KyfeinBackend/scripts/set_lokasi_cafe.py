import sys
import os
from decimal import Decimal

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from app.core.config import settings

def main():
    engine = create_engine(settings.SYNC_DATABASE_URL)
    
    with engine.connect() as conn:
        row = conn.execute(text("SELECT id, latitude, longitude, radius_meter, updated_at FROM konfigurasi_lokasi LIMIT 1")).fetchone()
        
        if len(sys.argv) < 3:
            print("=" * 60)
            print("KONFIGURASI TITIK LOKASI & RADIUS ABSENSI CAFE SAAT INI")
            print("=" * 60)
            if row:
                print(f"ID           : {row[0]}")
                print(f"Latitude     : {row[1]}")
                print(f"Longitude    : {row[2]}")
                print(f"Radius       : {row[3]} meter")
                print(f"Terakhir Ubah: {row[4]}")
            else:
                print("Belum ada konfigurasi lokasi di database.")
            print("\nCara Mengubah via CLI:")
            print("  python set_lokasi_cafe.py <latitude> <longitude> [radius_meter]")
            print("Contoh:")
            print("  python set_lokasi_cafe.py -7.82841199 111.99807238 100")
            return

        new_lat = Decimal(sys.argv[1])
        new_lng = Decimal(sys.argv[2])
        new_radius = int(sys.argv[3]) if len(sys.argv) >= 4 else 100

        if row:
            conn.execute(
                text("""
                    UPDATE konfigurasi_lokasi 
                    SET latitude = :lat, longitude = :lng, radius_meter = :rad, updated_at = NOW()
                    WHERE id = :id
                """),
                {"lat": new_lat, "lng": new_lng, "rad": new_radius, "id": row[0]}
            )
            print(f"[OK] Berhasil memperbarui lokasi cafe:")
        else:
            import uuid
            new_id = str(uuid.uuid4())
            conn.execute(
                text("""
                    INSERT INTO konfigurasi_lokasi (id, latitude, longitude, radius_meter, updated_at)
                    VALUES (:id, :lat, :lng, :rad, NOW())
                """),
                {"id": new_id, "lat": new_lat, "lng": new_lng, "rad": new_radius}
            )
            print(f"[OK] Berhasil membuat konfigurasi lokasi baru:")

        conn.commit()

        print(f"  -> Latitude : {new_lat}")
        print(f"  -> Longitude: {new_lng}")
        print(f"  -> Radius   : {new_radius} meter")

if __name__ == "__main__":
    main()

