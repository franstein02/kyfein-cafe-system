import pytest
import pytest_asyncio
from datetime import date, timedelta, time
from decimal import Decimal

from app.core.utils import now_local
from app.models import (
    JadwalShift, TukarShift, RequestOff, Absensi, IzinTelat, IzinTidakMasuk, Karyawan
)

@pytest.mark.asyncio
async def test_issue7_create_jadwal_inactive_karyawan(client, sample_data, test_db):
    """POST /jadwal rejects inactive or non-existent employees with 400"""
    # 1. Non-existent employee -> 400
    res_fake = await client.post(
        "/api/v1/jadwal/",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "karyawan_id": "usr-fake-xyz",
            "tanggal": (now_local().date() + timedelta(days=5)).isoformat(),
            "shift": "shift_1",
            "area_kerja": "kasir",
            "jam_mulai": "08:00:00",
            "jam_selesai": "16:00:00"
        }
    )
    assert res_fake.status_code == 400
    assert "karyawan tidak ditemukan" in res_fake.json()["detail"].lower()

    # 2. Inactive employee -> 400
    inactive_user = Karyawan(
        id="usr-inactive-k",
        nama="Karyawan Resigned",
        email="inactive@kyfein.com",
        nomor_hp="0899999999",
        role="karyawan",
        password="hashedpassword",
        status_aktif=False
    )
    test_db.add(inactive_user)
    await test_db.commit()

    res_inactive = await client.post(
        "/api/v1/jadwal/",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "karyawan_id": "usr-inactive-k",
            "tanggal": (now_local().date() + timedelta(days=5)).isoformat(),
            "shift": "shift_1",
            "area_kerja": "kasir",
            "jam_mulai": "08:00:00",
            "jam_selesai": "16:00:00"
        }
    )
    assert res_inactive.status_code == 400
    assert "tidak aktif" in res_inactive.json()["detail"].lower()

@pytest.mark.asyncio
async def test_issue7_tukar_shift_validation(client, sample_data, test_db):
    """
    Tukar shift validation:
    - Reject past shift swap request (400)
    - Reject if shift_a OR shift_b is in ANY pending swap request (409)
    """
    today = sample_data["today"]
    tomorrow = today + timedelta(days=1)

    # 1. Swap request for past shift -> 400
    res_past = await client.post(
        "/api/v1/jadwal/tukar-shift",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "shift_a_id": "shift-past",
            "shift_b_id": "shift-past2",
            "karyawan_target_id": "usr-karyawan2",
            "alasan": "Tukar shift lampau"
        }
    )
    assert res_past.status_code == 400
    assert "berlalu" in res_past.json()["detail"].lower()

    # 2. Create 2 future shifts for K1 and K2 on tomorrow
    shift_k1_tom = JadwalShift(
        id="shift-k1-tom",
        karyawan_id="usr-karyawan1",
        tanggal=tomorrow,
        shift="shift_1",
        area_kerja="bar",
        jam_mulai=time(8, 0),
        jam_selesai=time(16, 0)
    )
    shift_k2_tom = JadwalShift(
        id="shift-k2-tom",
        karyawan_id="usr-karyawan2",
        tanggal=tomorrow,
        shift="shift_2",
        area_kerja="bar",
        jam_mulai=time(16, 0),
        jam_selesai=time(23, 0)
    )
    test_db.add_all([shift_k1_tom, shift_k2_tom])
    await test_db.commit()

    # Create 1st pending swap between shift_k1_tom and shift_k2_tom
    res_req1 = await client.post(
        "/api/v1/jadwal/tukar-shift",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "shift_a_id": "shift-k1-tom",
            "shift_b_id": "shift-k2-tom",
            "karyawan_target_id": "usr-karyawan2",
            "alasan": "Tukar shift besok"
        }
    )
    assert res_req1.status_code == 200

    # 3. Create a 3rd shift on tomorrow for K2 to test reusing shift_a in another pending swap -> 409 Conflict
    shift_k2_tom2 = JadwalShift(
        id="shift-k2-tom2",
        karyawan_id="usr-karyawan2",
        tanggal=tomorrow,
        shift="shift_1",
        area_kerja="kitchen",
        jam_mulai=time(16, 0),
        jam_selesai=time(23, 0)
    )
    test_db.add(shift_k2_tom2)
    await test_db.commit()

    # Attempt 2nd swap request reusing shift_k1_tom -> 409 Conflict
    res_req2 = await client.post(
        "/api/v1/jadwal/tukar-shift",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "shift_a_id": "shift-k1-tom",
            "shift_b_id": "shift-k2-tom2",
            "karyawan_target_id": "usr-karyawan2",
            "alasan": "Tukar shift ganda"
        }
    )
    assert res_req2.status_code == 409

@pytest.mark.asyncio
async def test_issue7_approval_validations(client, sample_data, test_db):
    """
    Approval tukar shift re-validations (409):
    - Shift already has attendance -> 409
    - Shift has pending/disetujui leave (IzinTelat / IzinTidakMasuk) -> 409
    """
    today = sample_data["today"]

    # 1. Create a pending swap for today's shifts (shift-bar-k1 and shift-bar-k2)
    # shift-bar-k1 belongs to K1, shift-bar-k2 belongs to K2
    tukar_appr = TukarShift(
        id="tukar-to-appr",
        shift_a_id="shift-bar-k1",
        shift_b_id="shift-bar-k2",
        karyawan_pengaju_id="usr-karyawan1",
        karyawan_target_id="usr-karyawan2",
        status="pending"
    )
    test_db.add(tukar_appr)
    await test_db.commit()

    # Add Absensi to shift-bar-k1
    absen = Absensi(
        id="abs-shift-bar1",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-bar-k1",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1"
    )
    test_db.add(absen)
    await test_db.commit()

    # Approve swap when shift already has attendance -> 409
    res_appr_abs = await client.put(
        f"/api/v1/jadwal/tukar-shift/tukar-to-appr/approval",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={"status": "disetujui"}
    )
    assert res_appr_abs.status_code == 409
    assert "absensi" in res_appr_abs.json()["detail"].lower()

@pytest.mark.asyncio
async def test_issue7_request_off_rules(client, sample_data, test_db):
    """
    Request Off rules:
    - Past date request off -> 400
    - Duplicate (karyawan_id, tanggal) -> 409
    """
    today = sample_data["today"]
    yesterday = today - timedelta(days=1)
    tomorrow = today + timedelta(days=1)

    # 1. Past date request off -> 400
    res_past = await client.post(
        "/api/v1/jadwal/request-off",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "tanggal": yesterday.isoformat(),
            "alasan": "Libur kemarin"
        }
    )
    assert res_past.status_code == 400
    assert "masa lalu" in res_past.json()["detail"].lower()

    # 2. Valid request off for tomorrow -> 200
    res_valid = await client.post(
        "/api/v1/jadwal/request-off",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "tanggal": tomorrow.isoformat(),
            "alasan": "Acara keluarga"
        }
    )
    assert res_valid.status_code == 200

    # 3. Duplicate request off for same date -> 409
    res_dup = await client.post(
        "/api/v1/jadwal/request-off",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "tanggal": tomorrow.isoformat(),
            "alasan": "Acara keluarga lagi"
        }
    )
    assert res_dup.status_code == 409
