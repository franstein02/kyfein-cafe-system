"""
Script Pembersihan Foto Yatim (Orphan Photos Cleanup)
- Menghapus foto yang dipakai == False dan created_at lebih dari 24 jam dari DB & disk.
- Menghapus file di folder upload yang tidak memiliki record di tabel foto DB.
Dapat dijalankan via Task Scheduler / Cron Job.
"""

import sys
import os
from datetime import timedelta

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, select, and_
from sqlalchemy.orm import sessionmaker
from app.core.config import settings
from app.core.utils import now_local
from app.models.foto import Foto

def clean_orphan_photos(db_session=None, db_url=None):
    cutoff = now_local() - timedelta(hours=24)
    print(f"[Orphan Photo Cleanup] Cleaning unused photos created before {cutoff}...")

    close_session = False
    if db_session is not None:
        session = db_session
    else:
        target_url = db_url or settings.SYNC_DATABASE_URL
        engine = create_engine(target_url)
        Session = sessionmaker(bind=engine)
        session = Session()
        close_session = True

    try:
        # 1. Clean DB orphan records (dipakai == False & created_at < cutoff)
        stmt = select(Foto).where(
            and_(
                Foto.dipakai == False,
                Foto.created_at < cutoff
            )
        )
        orphans = session.scalars(stmt).all()
        count = len(orphans)
        files_deleted = 0

        for foto in orphans:
            if foto.path:
                filename = os.path.basename(foto.path)
                abs_path = os.path.join(settings.UPLOAD_DIR, filename)
                if os.path.exists(abs_path):
                    try:
                        os.remove(abs_path)
                        files_deleted += 1
                    except Exception as e:
                        print(f"Failed to remove file {abs_path}: {e}")
            session.delete(foto)

        session.commit()

        # 2. Clean disk files without any corresponding row in foto table
        all_db_filenames = set(
            os.path.basename(p) for p in session.scalars(select(Foto.path)).all() if p
        )
        untracked_deleted = 0
        upload_dir = settings.UPLOAD_DIR
        if os.path.exists(upload_dir):
            for fname in os.listdir(upload_dir):
                fpath = os.path.join(upload_dir, fname)
                if os.path.isfile(fpath) and fname not in all_db_filenames:
                    try:
                        os.remove(fpath)
                        untracked_deleted += 1
                    except Exception as e:
                        print(f"Failed to remove untracked file {fpath}: {e}")

        print(f"[Orphan Photo Cleanup] Done! Removed {count} photo records, {files_deleted} orphan files, and {untracked_deleted} untracked files from disk.")
        return count
    except Exception as e:
        session.rollback()
        print(f"[Orphan Photo Cleanup] Error: {e}")
        raise
    finally:
        if close_session:
            session.close()

if __name__ == "__main__":
    clean_orphan_photos()
