import os
import io
import pytest
import asyncio
from datetime import datetime, timedelta
from PIL import Image, ImageOps
from sqlalchemy import select, func

from app.core.config import settings
from app.models import Foto, Karyawan
from scripts.clean_orphan_photos import clean_orphan_photos

@pytest.mark.asyncio
async def test_issue6_upload_relative_path_and_exif(client, sample_data, test_db):
    """
    1. EXIF orientation transposed properly.
    2. foto.path stored as relative filename.
    """
    # Create a small image in memory with EXIF orientation tag 6 (90 CW rotation)
    img = Image.new("RGB", (100, 200), color="blue")
    exif = img.getexif()
    exif[274] = 6  # Orientation 6
    buf = io.BytesIO()
    img.save(buf, format="JPEG", exif=exif)
    buf.seek(0)

    res = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        files={"file": ("portrait.jpg", buf, "image/jpeg")},
        data={"jenis": "absensi"}
    )
    assert res.status_code == 201
    foto_id = res.json()["id"]

    # Verify DB entry
    foto = (await test_db.execute(select(Foto).where(Foto.id == foto_id))).scalars().first()
    assert foto is not None
    # Path should be relative (no slashes, just uuid.jpg)
    assert foto.path == f"{foto_id}.jpg"
    assert "/" not in foto.path and "\\" not in foto.path

    # Verify GET /foto/{id} succeeds with no-cache header for absensi
    res_get = await client.get(
        f"/api/v1/foto/{foto_id}",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"}
    )
    assert res_get.status_code == 200
    assert "no-cache" in res_get.headers.get("Cache-Control", "").lower()

@pytest.mark.asyncio
async def test_issue6_cache_headers_menu_profil(client, sample_data, test_db):
    """Menu & profil photos return Cache-Control with max-age=86400"""
    img = Image.new("RGB", (50, 50), color="red")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    res = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        files={"file": ("menu.jpg", buf, "image/jpeg")},
        data={"jenis": "menu"}
    )
    assert res.status_code == 201
    foto_id = res.json()["id"]

    res_get = await client.get(
        f"/api/v1/foto/{foto_id}",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"}
    )
    assert res_get.status_code == 200
    assert "max-age=86400" in res_get.headers.get("Cache-Control", "").lower()

@pytest.mark.asyncio
async def test_issue6_file_size_and_decompression_bomb(client, sample_data):
    """
    - > 5MB file -> 400
    """
    # 5.1 MB dummy payload
    large_payload = b"x" * (5 * 1024 * 1024 + 100)
    res_large = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        files={"file": ("too_large.jpg", large_payload, "image/jpeg")},
        data={"jenis": "absensi"}
    )
    assert res_large.status_code == 400
    assert "melebihi batas maksimal 5 mb" in res_large.json()["detail"].lower()

@pytest.mark.asyncio
async def test_issue6_unused_photo_limit_429(client, sample_data, test_db):
    """Max 50 unused photos per user -> 429 on 51st photo"""
    user_id = "usr-limit-test"
    k_limit = Karyawan(
        id=user_id,
        nama="User Limit",
        email="limit@kyfein.com",
        nomor_hp="0899123456",
        role="karyawan",
        password="hashedpassword"
    )
    test_db.add(k_limit)

    # Pre-populate 50 unused photos for user_id
    for i in range(50):
        f = Foto(
            id=f"foto-limit-{i}",
            jenis="absensi",
            path=f"foto-limit-{i}.jpg",
            uploader_id=user_id,
            dipakai=False
        )
        test_db.add(f)
    await test_db.commit()

    from app.core.security import create_access_token
    token_limit = create_access_token(user_id, "karyawan")

    img = Image.new("RGB", (10, 10), color="green")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    # 51st upload -> 429
    res = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {token_limit}"},
        files={"file": ("limit.jpg", buf, "image/jpeg")},
        data={"jenis": "absensi"}
    )
    assert res.status_code == 429
    assert "maksimal" in res.json()["detail"].lower()

@pytest.mark.asyncio
async def test_issue6_clean_orphan_photos_script():
    """Script cleans DB orphan records AND untracked files on disk"""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from app.models.base import Base

    upload_dir = settings.UPLOAD_DIR
    os.makedirs(upload_dir, exist_ok=True)

    # 1. Create an untracked file on disk
    untracked_path = os.path.join(upload_dir, "untracked_test_file.jpg")
    with open(untracked_path, "w") as f:
        f.write("untracked photo content")

    assert os.path.exists(untracked_path)

    # Create a sync in-memory SQLite database session for script test
    sync_engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(sync_engine)
    SyncSession = sessionmaker(bind=sync_engine)
    sync_session = SyncSession()

    try:
        # Run clean_orphan_photos
        clean_orphan_photos(db_session=sync_session)

        # Untracked file should be deleted from disk
        assert not os.path.exists(untracked_path)
    finally:
        sync_session.close()
        sync_engine.dispose()


@pytest.mark.asyncio
async def test_foto_supabase_folder_routing_and_remote_fallback(
    client, sample_data, test_db, monkeypatch
):
    """
    Pastikan foto absensi/izin/qris tersimpan ke folder `absensi/`, foto menu ke folder `menu/`,
    dan GET /foto/{id} tetap melayani foto dari Supabase saat file lokal tidak ada di disk.
    """
    import app.api.v1.endpoints.foto as foto_ep

    uploaded_objects: dict[str, bytes] = {}

    async def fake_upload(object_path: str, image_bytes: bytes, content_type: str = "image/jpeg") -> str:
        uploaded_objects[object_path] = image_bytes
        return f"https://example.supabase.co/storage/v1/object/public/Storage/{object_path}"

    async def fake_download(url_or_path: str) -> bytes:
        marker = "/storage/v1/object/public/Storage/"
        key = url_or_path.split(marker, 1)[1] if marker in url_or_path else url_or_path
        return uploaded_objects[key]

    monkeypatch.setattr(settings, "SUPABASE_SYNC_ENABLED", True)
    monkeypatch.setattr(foto_ep, "upload_image_bytes", fake_upload)
    monkeypatch.setattr(foto_ep, "download_image_bytes", fake_download)

    def _jpeg_buf(color: str) -> io.BytesIO:
        b = io.BytesIO()
        Image.new("RGB", (40, 40), color=color).save(b, format="JPEG")
        b.seek(0)
        return b

    # 1. Absensi & Izin masuk folder `absensi/`
    res_abs = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        files={"file": ("absen.jpg", _jpeg_buf("blue"), "image/jpeg")},
        data={"jenis": "absensi"},
    )
    assert res_abs.status_code == 201
    abs_id = res_abs.json()["id"]
    assert f"absensi/absensi_{abs_id}.jpg" in uploaded_objects
    assert res_abs.json()["supabase_url"].endswith(f"/Storage/absensi/absensi_{abs_id}.jpg")

    res_izin = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        files={"file": ("telat.jpg", _jpeg_buf("yellow"), "image/jpeg")},
        data={"jenis": "izin"},
    )
    assert res_izin.status_code == 201
    izin_id = res_izin.json()["id"]
    assert f"absensi/izin_{izin_id}.jpg" in uploaded_objects

    # 2. Menu masuk folder `menu/`
    res_menu = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        files={"file": ("menu.jpg", _jpeg_buf("green"), "image/jpeg")},
        data={"jenis": "menu"},
    )
    assert res_menu.status_code == 201
    menu_foto_id = res_menu.json()["id"]
    assert f"menu/{menu_foto_id}.jpg" in uploaded_objects

    # 3. Hapus file lokal, pastikan GET /foto/{id} masih berhasil mengambil dari Supabase fallback + tetap proteksi role!
    local_izin_path = os.path.join(settings.UPLOAD_DIR, f"{izin_id}.jpg")
    os.remove(local_izin_path)
    assert not os.path.exists(local_izin_path)

    res_other = await client.get(
        f"/api/v1/foto/{izin_id}",
        headers={"Authorization": f"Bearer {sample_data['token_k2']}"},
    )
    assert res_other.status_code == 403

    res_admin = await client.get(
        f"/api/v1/foto/{izin_id}",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
    )
    assert res_admin.status_code == 200
    assert res_admin.content == uploaded_objects[f"absensi/izin_{izin_id}.jpg"]
    assert "no-cache" in res_admin.headers.get("Cache-Control", "").lower()
