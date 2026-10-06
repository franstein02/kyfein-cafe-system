import os
from typing import Optional
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.config import settings
from app.models.foto import Foto

def get_foto_abs_path(path: str) -> str:
    if not path:
        return ""
    filename = os.path.basename(path)
    return os.path.join(settings.UPLOAD_DIR, filename)

async def validate_and_claim_foto(
    db: AsyncSession,
    foto_id: Optional[str],
    uploader_id: str,
    expected_jenis: str,
    required: bool = True
) -> Optional[Foto]:
    if not foto_id or not str(foto_id).strip():
        if required:
            raise HTTPException(status_code=400, detail="foto_id wajib diisi")
        return None

    stmt = select(Foto).where(Foto.id == foto_id)
    res = await db.execute(stmt)
    foto = res.scalars().first()

    if not foto:
        raise HTTPException(status_code=400, detail="Foto tidak ditemukan")

    if foto.uploader_id != uploader_id:
        raise HTTPException(status_code=400, detail="Foto bukan milik user ini")

    if foto.jenis != expected_jenis:
        raise HTTPException(status_code=400, detail=f"Jenis foto tidak sesuai, diharapkan '{expected_jenis}'")

    if foto.dipakai:
        raise HTTPException(status_code=400, detail="Foto sudah dipakai")

    foto.dipakai = True
    return foto

async def remove_old_foto_if_replaced(db: AsyncSession, old_foto_id: Optional[str], new_foto_id: Optional[str]):
    if old_foto_id and old_foto_id != new_foto_id:
        res = await db.execute(select(Foto).where(Foto.id == old_foto_id))
        old_foto = res.scalars().first()
        if old_foto:
            abs_path = get_foto_abs_path(old_foto.path)
            if abs_path and os.path.exists(abs_path):
                try:
                    os.remove(abs_path)
                except Exception:
                    pass
            await db.delete(old_foto)
