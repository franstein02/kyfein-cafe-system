import os
import io
import uuid
import warnings
from typing import Literal
from PIL import Image, ImageOps
from PIL.Image import DecompressionBombError, DecompressionBombWarning
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from fastapi.responses import FileResponse
from starlette.concurrency import run_in_threadpool
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.core.config import settings
from app.core.deps import get_db, get_current_user
from app.core.foto_helper import get_foto_abs_path
from app.models.karyawan import Karyawan
from app.models.foto import Foto

router = APIRouter()

ALLOWED_JENIS = {'absensi', 'izin', 'qris', 'menu', 'profil'}
ALLOWED_FORMATS = {'JPEG', 'PNG', 'WEBP'}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB
MAX_UNUSED_PHOTOS_PER_USER = 50

def _process_and_save_image(file_bytes: bytes, dest_path: str) -> None:
    Image.MAX_IMAGE_PIXELS = 40_000_000
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", DecompressionBombWarning)
            img = Image.open(io.BytesIO(file_bytes))
            fmt = img.format
            if fmt not in ALLOWED_FORMATS:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Format gambar harus JPEG, PNG, atau WebP"
                )
            
            # 1. EXIF Transpose
            img = ImageOps.exif_transpose(img)

            # Convert mode to RGB
            if img.mode != "RGB":
                img = img.convert("RGB")

            # Resize max side 1280px
            max_side = 1280
            width, height = img.size
            if width > max_side or height > max_side:
                if width >= height:
                    new_w = max_side
                    new_h = int(height * (max_side / width))
                else:
                    new_h = max_side
                    new_w = int(width * (max_side / height))
                img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)

            os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            img.save(dest_path, format="JPEG", quality=85)
    except (DecompressionBombError, DecompressionBombWarning):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File gambar terlalu besar atau terdeteksi decompression bomb"
        )
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File gambar tidak valid atau rusak"
        )

@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED)
async def upload_foto(
    file: UploadFile = File(...),
    jenis: str = Form(...),
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    if jenis not in ALLOWED_JENIS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Jenis foto tidak valid. Pilihan: {', '.join(ALLOWED_JENIS)}"
        )

    # 8. Limit unused photos per user (max 50) -> 429
    stmt_count = select(func.count(Foto.id)).where(
        and_(
            Foto.uploader_id == current_user.id,
            Foto.dipakai == False
        )
    )
    unused_count = (await db.execute(stmt_count)).scalar() or 0
    if unused_count >= MAX_UNUSED_PHOTOS_PER_USER:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Jumlah foto belum terpakai mencapai batas maksimal (50 foto)"
        )

    # 5. Read upload in chunks up to 5 MB
    chunks = []
    total_bytes = 0
    chunk_size = 64 * 1024
    while True:
        chunk = await file.read(chunk_size)
        if not chunk:
            break
        total_bytes += len(chunk)
        if total_bytes > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ukuran file foto melebihi batas maksimal 5 MB"
            )
        chunks.append(chunk)

    file_bytes = b"".join(chunks)

    foto_id = str(uuid.uuid4())
    rel_path = f"{foto_id}.jpg"
    abs_path = os.path.join(settings.UPLOAD_DIR, rel_path)

    # 3. Offload Pillow decoding/resizing/saving to threadpool
    await run_in_threadpool(_process_and_save_image, file_bytes, abs_path)

    # 6. Database commit failure file cleanup
    foto_obj = Foto(
        id=foto_id,
        jenis=jenis,
        path=rel_path,
        uploader_id=current_user.id,
        dipakai=False
    )
    db.add(foto_obj)
    try:
        await db.commit()
    except Exception:
        if os.path.exists(abs_path):
            try:
                os.remove(abs_path)
            except Exception:
                pass
        raise

    return {"id": foto_id}


@router.get("/{id}")
async def get_foto(
    id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    stmt = select(Foto).where(Foto.id == id)
    res = await db.execute(stmt)
    foto = res.scalars().first()

    if not foto:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Foto tidak ditemukan")

    # Access control
    if foto.jenis in {'absensi', 'izin', 'qris'}:
        if current_user.role not in {'admin', 'owner'} and foto.uploader_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak. Anda hanya dapat melihat foto milik Anda sendiri."
            )

    abs_path = get_foto_abs_path(foto.path)
    if not os.path.exists(abs_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File foto tidak ditemukan di server"
        )

    # Cache control: private max-age for public types (menu/profil), no-cache for evidence
    cache_header = "private, max-age=86400" if foto.jenis in {'menu', 'profil'} else "no-cache, no-store, must-revalidate"

    return FileResponse(
        path=abs_path,
        media_type="image/jpeg",
        headers={"Cache-Control": cache_header}
    )
