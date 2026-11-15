import pytest
from datetime import timedelta
from sqlalchemy import select

from app.models.jadwal import ShiftTemplate


@pytest.mark.asyncio
async def test_shift_template_crud_and_jadwal_integration(client, sample_data, test_db):
    """
    Pastikan endpoint shift-template:
    1. Auto-seed shift_1 & shift_2 ke tabel shift_template jika kosong.
    2. Admin dapat mengubah jam mulai & selesai template di DB.
    3. Karyawan biasa ditolak (403) saat mengubah template, serta jam selesai <= jam mulai ditolak (400).
    4. POST /jadwal/ menautkan shift_template_id dan memakai jam dari template DB saat jam_mulai/jam_selesai tidak diisi.
    """
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    headers_k1 = {"Authorization": f"Bearer {sample_data['token_k1']}"}

    # 1. GET /jadwal/shift-template auto-seed defaults
    res_list = await client.get("/api/v1/jadwal/shift-template", headers=headers_admin)
    assert res_list.status_code == 200
    items = res_list.json()
    assert len(items) == 2
    by_shift = {item["shift"]: item for item in items}
    assert by_shift["shift_1"]["jam_mulai"].startswith("08:00")
    assert by_shift["shift_1"]["jam_selesai"].startswith("16:00")
    assert by_shift["shift_2"]["jam_mulai"].startswith("16:00")
    assert by_shift["shift_2"]["jam_selesai"].startswith("23:00")

    # 2. Non-admin tidak boleh mengubah template
    res_forbidden = await client.put(
        "/api/v1/jadwal/shift-template/shift_1",
        headers=headers_k1,
        json={"jam_mulai": "07:00:00", "jam_selesai": "15:00:00"},
    )
    assert res_forbidden.status_code == 403

    # 3. Jam selesai <= jam mulai harus 400
    res_invalid = await client.put(
        "/api/v1/jadwal/shift-template/shift_1",
        headers=headers_admin,
        json={"jam_mulai": "16:00:00", "jam_selesai": "08:00:00"},
    )
    assert res_invalid.status_code == 400

    # 4. Admin update template shift_1 di database
    res_update = await client.put(
        "/api/v1/jadwal/shift-template/shift_1",
        headers=headers_admin,
        json={"jam_mulai": "07:30:00", "jam_selesai": "15:30:00"},
    )
    assert res_update.status_code == 200
    updated_tpl = res_update.json()
    assert updated_tpl["shift"] == "shift_1"
    assert updated_tpl["jam_mulai"].startswith("07:30")
    assert updated_tpl["jam_selesai"].startswith("15:30")

    # Verify DB persistence directly
    db_row = (
        await test_db.execute(select(ShiftTemplate).where(ShiftTemplate.shift == "shift_1"))
    ).scalars().first()
    assert db_row is not None
    assert db_row.jam_mulai.strftime("%H:%M") == "07:30"
    assert db_row.jam_selesai.strftime("%H:%M") == "15:30"

    # 5. Create jadwal tanpa jam_mulai/jam_selesai -> ikut template DB & terhubung shift_template_id
    target_date = (sample_data["today"] + timedelta(days=3)).isoformat()
    res_jadwal = await client.post(
        "/api/v1/jadwal/",
        headers=headers_admin,
        json={
            "karyawan_id": "usr-karyawan1",
            "tanggal": target_date,
            "shift": "shift_1",
            "area_kerja": "bar",
        },
    )
    assert res_jadwal.status_code == 200
    created_jadwal = res_jadwal.json()
    assert created_jadwal["shift_template_id"] == updated_tpl["id"]
    assert created_jadwal["jam_mulai"].startswith("07:30")
    assert created_jadwal["jam_selesai"].startswith("15:30")

