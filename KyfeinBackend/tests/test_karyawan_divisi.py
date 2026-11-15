import pytest


@pytest.mark.asyncio
async def test_admin_crud_karyawan_per_divisi_and_auth_me(client, sample_data):
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    headers_k1 = {"Authorization": f"Bearer {sample_data['token_k1']}"}

    # 1. Create karyawan for kitchen, bar, and kasir (including empty/missing nomor_hp)
    res_kitchen = await client.post(
        "/api/v1/karyawan/",
        headers=headers_admin,
        json={
            "nama": "Chef Rina",
            "email": "Rina.Kitchen@kyfein.com",
            "nomor_hp": "",
            "role": "karyawan",
            "divisi": "kitchen",
            "password": "password123",
            "status_aktif": True,
        },
    )
    assert res_kitchen.status_code == 200, res_kitchen.text
    kitchen = res_kitchen.json()
    assert kitchen["email"] == "rina.kitchen@kyfein.com"
    assert kitchen["divisi"] == "kitchen"
    assert kitchen["nomor_hp"] is None
    assert kitchen["role"] == "karyawan"

    res_bar = await client.post(
        "/api/v1/karyawan/",
        headers=headers_admin,
        json={
            "nama": "Barista Andi",
            "email": "andi.bar@kyfein.com",
            "nomor_hp": None,
            "role": "karyawan",
            "divisi": "bar",
            "password": "password123",
            "status_aktif": True,
        },
    )
    assert res_bar.status_code == 200, res_bar.text
    bar = res_bar.json()
    assert bar["divisi"] == "bar"
    assert bar["nomor_hp"] is None

    res_kasir = await client.post(
        "/api/v1/karyawan/",
        headers=headers_admin,
        json={
            "nama": "Kasir Dina",
            "email": "dina.kasir@kyfein.com",
            "nomor_hp": "081234500099",
            "role": "karyawan",
            "divisi": "kasir",
            "password": "password123",
            "status_aktif": True,
        },
    )
    assert res_kasir.status_code == 200, res_kasir.text
    assert res_kasir.json()["divisi"] == "kasir"

    # Duplicate email & duplicate nomor_hp must return 409
    dup_email = await client.post(
        "/api/v1/karyawan/",
        headers=headers_admin,
        json={
            "nama": "Duplikat Email",
            "email": "andi.bar@kyfein.com",
            "nomor_hp": "081299988877",
            "role": "karyawan",
            "divisi": "bar",
            "password": "password123",
        },
    )
    assert dup_email.status_code == 409

    dup_hp = await client.post(
        "/api/v1/karyawan/",
        headers=headers_admin,
        json={
            "nama": "Duplikat HP",
            "email": "unik.baru@kyfein.com",
            "nomor_hp": "081234500099",
            "role": "karyawan",
            "divisi": "kasir",
            "password": "password123",
        },
    )
    assert dup_hp.status_code == 409

    # 2. List & filter by divisi
    res_list_kitchen = await client.get("/api/v1/karyawan/?divisi=kitchen", headers=headers_admin)
    assert res_list_kitchen.status_code == 200
    assert any(k["id"] == kitchen["id"] for k in res_list_kitchen.json())
    assert all(k["divisi"] == "kitchen" for k in res_list_kitchen.json())

    # 3. Admin updates nama, email, divisi, nomor_hp, password, and status_aktif
    res_update = await client.put(
        f"/api/v1/karyawan/{bar['id']}",
        headers=headers_admin,
        json={
            "nama": "Chef Andi Updated",
            "email": "andi.kitchen@kyfein.com",
            "divisi": "kitchen",
            "nomor_hp": "089988776655",
            "password": "newpassword123",
            "status_aktif": True,
        },
    )
    assert res_update.status_code == 200, res_update.text
    updated = res_update.json()
    assert updated["nama"] == "Chef Andi Updated"
    assert updated["email"] == "andi.kitchen@kyfein.com"
    assert updated["divisi"] == "kitchen"
    assert updated["nomor_hp"] == "089988776655"

    # Clear nomor_hp back to null with empty string
    res_clear_hp = await client.put(
        f"/api/v1/karyawan/{bar['id']}",
        headers=headers_admin,
        json={"nomor_hp": ""},
    )
    assert res_clear_hp.status_code == 200
    assert res_clear_hp.json()["nomor_hp"] is None

    # 4. Login & /auth/me reflect updated credentials and divisi
    res_login = await client.post(
        "/api/v1/auth/login",
        json={"email": "ANDI.KITCHEN@kyfein.com", "password": "newpassword123"},
    )
    assert res_login.status_code == 200, res_login.text
    token_data = res_login.json()
    assert token_data["role"] == "karyawan"
    assert token_data["divisi"] == "kitchen"
    assert token_data["nama"] == "Chef Andi Updated"

    res_me = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token_data['access_token']}"},
    )
    assert res_me.status_code == 200
    assert res_me.json()["divisi"] == "kitchen"

    # Non-admin still cannot list karyawan
    res_forbidden = await client.get("/api/v1/karyawan/", headers=headers_k1)
    assert res_forbidden.status_code == 403
