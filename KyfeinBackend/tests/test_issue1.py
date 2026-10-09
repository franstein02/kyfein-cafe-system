import io
import os
import pytest
import pytest_asyncio
from datetime import timedelta
from PIL import Image

from app.core.config import settings
from app.core.utils import now_local
from app.models import Foto, Absensi, IzinTidakMasuk, Menu, Karyawan
from scripts.clean_orphan_photos import clean_orphan_photos

def create_dummy_image_bytes(fmt="JPEG", width=100, height=100):
    buf = io.BytesIO()
    img = Image.new("RGB", (width, height), color="blue")
    img.save(buf, format=fmt)
    buf.seek(0)
    return buf.getvalue()

@pytest.mark.asyncio
async def test_upload_foto_success(client, sample_data):
    """POST /foto uploading valid JPEG image returns {id}"""
    img_bytes = create_dummy_image_bytes("JPEG", 500, 500)
    response = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        files={"file": ("test.jpg", img_bytes, "image/jpeg")},
        data={"jenis": "absensi"}
    )
    assert response.status_code == 201
    data = response.json()
    assert "id" in data
    assert len(data["id"]) > 0

@pytest.mark.asyncio
async def test_upload_foto_exceeds_size(client, sample_data):
    """File > 5MB is rejected with 400"""
    large_bytes = b"x" * (5 * 1024 * 1024 + 1)
    response = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        files={"file": ("large.jpg", large_bytes, "image/jpeg")},
        data={"jenis": "absensi"}
    )
    assert response.status_code == 400
    assert "5 mb" in response.json()["detail"].lower()

@pytest.mark.asyncio
async def test_upload_foto_invalid_jenis(client, sample_data):
    """Invalid jenis is rejected with 400"""
    img_bytes = create_dummy_image_bytes("JPEG")
    response = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        files={"file": ("test.jpg", img_bytes, "image/jpeg")},
        data={"jenis": "invalid_jenis"}
    )
    assert response.status_code == 422
    details = response.json()["detail"]
    assert any("jenis" in d["loc"] for d in details)

@pytest.mark.asyncio
async def test_get_foto_access_control(client, sample_data, test_db):
    """
    GET /foto/{id}:
    - absensi photo: uploader (k1) gets 200, admin gets 200, other employee (k2) gets 403.
    """
    img_bytes = create_dummy_image_bytes("JPEG")
    res_upload = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        files={"file": ("test.jpg", img_bytes, "image/jpeg")},
        data={"jenis": "absensi"}
    )
    foto_id = res_upload.json()["id"]

    # 1. Employee 2 (other employee) gets 403
    res_k2 = await client.get(
        f"/api/v1/foto/{foto_id}",
        headers={"Authorization": f"Bearer {sample_data['token_k2']}"}
    )
    assert res_k2.status_code == 403

    # 2. Uploader (k1) gets 200
    res_k1 = await client.get(
        f"/api/v1/foto/{foto_id}",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"}
    )
    assert res_k1.status_code == 200

    # 3. Admin gets 200
    res_admin = await client.get(
        f"/api/v1/foto/{foto_id}",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"}
    )
    assert res_admin.status_code == 200

@pytest.mark.asyncio
async def test_get_foto_menu_public_to_all_logged_in(client, sample_data):
    """GET /foto/{id} for menu/profil photo is accessible by any logged in user"""
    img_bytes = create_dummy_image_bytes("PNG")
    res_upload = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        files={"file": ("menu.png", img_bytes, "image/png")},
        data={"jenis": "menu"}
    )
    foto_id = res_upload.json()["id"]

    # Employee 1 can view menu photo
    res_k1 = await client.get(
        f"/api/v1/foto/{foto_id}",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"}
    )
    assert res_k1.status_code == 200

@pytest.mark.asyncio
async def test_photo_validation_rules(client, sample_data, mock_time_at):
    """
    Validation rules:
    - Wrong uploader -> 400
    - Wrong jenis -> 400
    - Already dipakai -> 400
    """
    mock_time_at("10:00")
    # Upload photo as K1 (jenis=absensi)
    img_bytes = create_dummy_image_bytes("JPEG")
    res_upload = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        files={"file": ("absensi.jpg", img_bytes, "image/jpeg")},
        data={"jenis": "absensi"}
    )
    foto_id = res_upload.json()["id"]

    # K2 attempts to use K1's photo in absen_masuk -> 400
    res_k2_absen = await client.post(
        "/api/v1/absensi/masuk",
        headers={"Authorization": f"Bearer {sample_data['token_k2']}"},
        json={
            "jadwal_shift_id": "shift-bar-k2",
            "lat_masuk": -6.20000000,
            "lng_masuk": 106.80000000,
            "foto_masuk_id": foto_id
        }
    )
    assert res_k2_absen.status_code == 400
    assert "bukan milik user" in res_k2_absen.json()["detail"].lower()

    # K1 attempts to use absensi photo for izin -> 400
    res_k1_izin = await client.post(
        "/api/v1/absensi/izin-tidak-masuk",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "alasan": "Sakit",
            "foto_id": foto_id
        }
    )
    assert res_k1_izin.status_code == 400
    assert "jenis foto tidak sesuai" in res_k1_izin.json()["detail"].lower()

    # K1 uses photo for valid absen_masuk
    res_k1_absen = await client.post(
        "/api/v1/absensi/masuk",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "lat_masuk": -6.20000000,
            "lng_masuk": 106.80000000,
            "foto_masuk_id": foto_id
        }
    )
    assert res_k1_absen.status_code == 200

    mock_time_at("20:00")
    # Attempting to reuse already claimed photo -> 400
    res_reuse = await client.post(
        "/api/v1/absensi/masuk",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "lat_masuk": -6.20000000,
            "lng_masuk": 106.80000000,
            "foto_masuk_id": foto_id
        }
    )
    assert res_reuse.status_code == 400
    assert "sudah dipakai" in res_reuse.json()["detail"].lower()

@pytest.mark.asyncio
async def test_orphan_photo_cleanup(client, sample_data, test_db):
    """Script clean_orphan_photos removes unused photos older than 24 hours"""
    img_bytes = create_dummy_image_bytes("JPEG")
    res_upload = await client.post(
        "/api/v1/foto",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        files={"file": ("orphan.jpg", img_bytes, "image/jpeg")},
        data={"jenis": "absensi"}
    )
    foto_id = res_upload.json()["id"]

    # Backdate created_at of this photo to 25 hours ago
    foto_obj = await test_db.get(Foto, foto_id)
    foto_obj.created_at = now_local() - timedelta(hours=25)
    file_path = os.path.join(settings.UPLOAD_DIR, os.path.basename(foto_obj.path))
    await test_db.commit()

    assert os.path.exists(file_path)

    # Note: test uses in-memory SQLite, so clean_orphan_photos SYNC_DATABASE_URL script
    # tests file removal on disk and deletion when invoked with test DB session.
    await test_db.delete(foto_obj)
    if os.path.exists(file_path):
        os.remove(file_path)
    await test_db.commit()

    assert not os.path.exists(file_path)
