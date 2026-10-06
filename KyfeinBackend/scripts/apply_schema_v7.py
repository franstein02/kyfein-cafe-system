"""
Kyfein Cafe System — Incremental Migration Script v7
Applies Issue 6:
- Ensures foto.path stores only relative filenames ({uuid}.jpg).
- Re-running script safely skips records that are already converted.
"""

import sys
import os

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from app.core.config import settings
from app.models.foto import Foto

def apply_migration():
    print(f"[Migration v7] Connecting to {settings.DB_NAME} at {settings.DB_HOST}:{settings.DB_PORT}...")
    engine = create_engine(settings.SYNC_DATABASE_URL)
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        photos = session.scalars(select(Foto)).all()
        updated = 0
        for foto in photos:
            if foto.path:
                rel_filename = os.path.basename(foto.path)
                if foto.path != rel_filename:
                    foto.path = rel_filename
                    updated += 1

        session.commit()
        print(f"[Migration v7] Migration v7 completed successfully! Converted {updated} foto.path entries to relative filenames.")
    except Exception as e:
        session.rollback()
        print(f"[Migration v7] Migration failed: {e}")
        raise
    finally:
        session.close()

if __name__ == "__main__":
    apply_migration()
