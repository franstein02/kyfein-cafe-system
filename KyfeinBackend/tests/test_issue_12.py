import pytest
from httpx import AsyncClient
from app.core.security import create_access_token

@pytest.mark.asyncio
async def test_old_owner_token_rejected(client: AsyncClient, sample_data):
    # Buat token palsu yang isinya owner, tapi user aslinya admin di DB
    # Di Kyfein, payload JWT aslinya menyimpan role, tapi app.core.deps
    # mengambil user dari DB, sehingga role di dalam token tidak dipakai.
    # Namun jika di dalam token ada "sub" valid, role di DB yang menentukan.
    token = create_access_token("usr-admin", "owner")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Coba akses endpoint yang butuh role admin
    # Meskipun token bilang owner, sistem harus baca dari DB (yang isinya admin),
    # jadi endpoint admin harus sukses karena user "usr-admin" punya role "admin".
    response = await client.get("/api/v1/karyawan/", headers=headers)
    assert response.status_code == 200

@pytest.mark.asyncio
async def test_karyawan_cannot_access_admin_endpoint(client: AsyncClient, sample_data):
    # Karyawan mendapat 403 di endpoint admin
    headers = {"Authorization": f"Bearer {sample_data['token_k1']}"}
    response = await client.get("/api/v1/karyawan/", headers=headers)
    assert response.status_code == 403
    assert "akses ditolak" in response.json()["detail"].lower()

@pytest.mark.asyncio
async def test_admin_cannot_edit_admin(client: AsyncClient, sample_data, test_db):
    from app.models.karyawan import Karyawan
    # Tambahkan admin kedua
    admin2 = Karyawan(
        id="usr-admin2",
        nama="Admin Test 2",
        email="admin2@kyfein.com",
        nomor_hp="0811111112",
        role="admin",
        password="hashedpassword"
    )
    test_db.add(admin2)
    await test_db.commit()

    headers = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    
    # Admin tidak bisa edit admin lain
    response = await client.put(
        "/api/v1/karyawan/usr-admin2",
        json={"nama": "Hacked", "status_aktif": False},
        headers=headers
    )
    assert response.status_code == 403
    assert "admin tidak dapat diubah" in response.json()["detail"].lower()
    
    # Admin tidak bisa edit dirinya sendiri via API
    response = await client.put(
        "/api/v1/karyawan/usr-admin",
        json={"nama": "Hacked"},
        headers=headers
    )
    assert response.status_code == 403
    assert "admin tidak dapat diubah" in response.json()["detail"].lower()

@pytest.mark.asyncio
async def test_cannot_create_admin_via_api(client: AsyncClient, sample_data):
    headers = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    response = await client.post(
        "/api/v1/karyawan/",
        json={
            "nama": "New Admin",
            "email": "newadmin@kyfein.com",
            "nomor_hp": "123",
            "role": "admin",
            "password": "pwd",
            "status_aktif": True
        },
        headers=headers
    )
    assert response.status_code == 403
    assert "tidak dapat membuat akun admin" in response.json()["detail"].lower()
