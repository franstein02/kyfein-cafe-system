"""Helper terpusat untuk sinkronisasi foto ke Supabase Storage (folder menu/ & absensi/)."""

import logging
from typing import Optional
import httpx
from app.core.config import settings

logger = logging.getLogger(__name__)


def supabase_object_path(jenis: str, foto_id: str) -> str:
    """Petakan jenis foto ke folder bucket Supabase (`menu/` atau `absensi/`)."""
    if jenis == "menu":
        return f"menu/{foto_id}.jpg"
    return f"absensi/{jenis}_{foto_id}.jpg"


def build_public_url(object_path: str) -> str:
    base = settings.SUPABASE_URL.rstrip("/")
    bucket = settings.SUPABASE_BUCKET.strip("/")
    clean_obj = object_path.lstrip("/")
    return f"{base}/storage/v1/object/public/{bucket}/{clean_obj}"


def _extract_object_path(url_or_path: str) -> str:
    marker = f"/storage/v1/object/public/{settings.SUPABASE_BUCKET.strip('/')}/"
    if marker in url_or_path:
        return url_or_path.split(marker, 1)[1].lstrip("/")
    return url_or_path.lstrip("/")


async def upload_image_bytes(
    object_path: str,
    image_bytes: bytes,
    content_type: str = "image/jpeg",
) -> str:
    base = settings.SUPABASE_URL.rstrip("/")
    bucket = settings.SUPABASE_BUCKET.strip("/")
    clean_obj = object_path.lstrip("/")
    upload_url = f"{base}/storage/v1/object/{bucket}/{clean_obj}"
    headers = {
        "apikey": settings.SUPABASE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_KEY}",
        "Content-Type": content_type,
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.post(upload_url, content=image_bytes, headers=headers)
        if resp.status_code not in (200, 201):
            raise RuntimeError(f"Supabase upload failed ({resp.status_code}): {resp.text[:200]}")
    return build_public_url(clean_obj)


async def download_image_bytes(url_or_path: str) -> bytes:
    target_url = url_or_path if url_or_path.startswith("http") else build_public_url(url_or_path)
    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.get(target_url)
        if resp.status_code != 200:
            raise RuntimeError(f"Supabase download failed ({resp.status_code})")
        return resp.content


async def delete_supabase_object(url_or_path: Optional[str]) -> bool:
    if not url_or_path or not settings.SUPABASE_SYNC_ENABLED:
        return False
    clean_obj = _extract_object_path(url_or_path)
    if not clean_obj or clean_obj.startswith("http"):
        return False
    base = settings.SUPABASE_URL.rstrip("/")
    bucket = settings.SUPABASE_BUCKET.strip("/")
    del_url = f"{base}/storage/v1/object/{bucket}/{clean_obj}"
    headers = {
        "apikey": settings.SUPABASE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_KEY}",
    }
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.delete(del_url, headers=headers)
            return resp.status_code in (200, 204, 404)
    except Exception as exc:
        logger.warning("Gagal menghapus objek Supabase %s: %s", clean_obj, exc)
        return False
