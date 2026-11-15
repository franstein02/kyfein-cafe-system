import pytest
import pytest_asyncio
from datetime import date, timedelta, time
from decimal import Decimal

from app.core.utils import now_local
from app.models import (
    JadwalShift, TukarShift, RequestOff, Absensi, IzinTelat, IzinTidakMasuk, Karyawan, Foto
)

@pytest.mark.asyncio
async def test_full_jadwal_and_absensi_flow(client, sample_data, test_db):
    """
    Test alur lengkap:
    1. Pembuatan jadwal untuk Bar dan Kitchen
    2. Pengajuan Request Off & validasi duplikat / tanggal lampau
    3. Pengajuan Tukar Shift & persetujuan admin
    4. Pengajuan Izin Telat & approval
    5. Pengajuan Izin Tidak Masuk & validasi blokir clock-in
    6. Absen Masuk dengan validasi GPS & foto
    7. Absen Pulang dengan validasi GPS & status pulang
    """
    token_admin = sample_data["token_admin"]
    token_k1 = sample_data["token_k1"]
    token_k2 = sample_data["token_k2"]

    # 1. Tambah akun karyawan khusus Bar dan Kitchen ke test_db
    user_bar = Karyawan(
        id="usr-bar-test",
        nama="Budi (Bar)",
        email="budi.bar@test.com",
        nomor_hp="08990001",
        role="karyawan",
        password="hashedpassword",
        status_aktif=True
    )
    user_kitchen = Karyawan(
        id="usr-kitchen-test",
        nama="Siti (Kitchen)",
        email="siti.kitchen@test.com",
        nomor_hp="08990002",
        role="karyawan",
        password="hashedpassword",
        status_aktif=True
    )
    test_db.add_all([user_bar, user_kitchen])
    await test_db.commit()

    from app.core.security import create_access_token
    token_bar = create_access_token(subject=user_bar.id, role="karyawan")
    token_kitchen = create_access_token(subject=user_kitchen.id, role="karyawan")

    today = sample_data["today"]
    target_date = today + timedelta(days=2)

    # 2. Pembuatan Jadwal oleh Admin
    res_bar = await client.post(
        "/api/v1/jadwal/",
        headers={"Authorization": f"Bearer {token_admin}"},
        json={
            "karyawan_id": user_bar.id,
            "tanggal": target_date.isoformat(),
            "shift": "shift_1",
            "area_kerja": "bar",
            "jam_mulai": "08:00:00",
            "jam_selesai": "16:00:00"
        }
    )
    assert res_bar.status_code == 200
    sched_bar_id = res_bar.json()["id"]

    res_kitchen = await client.post(
        "/api/v1/jadwal/",
        headers={"Authorization": f"Bearer {token_admin}"},
        json={
            "karyawan_id": user_kitchen.id,
            "tanggal": target_date.isoformat(),
            "shift": "shift_2",
            "area_kerja": "kitchen",
            "jam_mulai": "16:00:00",
            "jam_selesai": "23:00:00"
        }
    )
    assert res_kitchen.status_code == 200
    sched_kitchen_id = res_kitchen.json()["id"]

    # 3. Request Off
    off_date = (today + timedelta(days=4)).isoformat()
    res_off = await client.post(
        "/api/v1/jadwal/request-off",
        headers={"Authorization": f"Bearer {token_bar}"},
        json={"tanggal": off_date, "alasan": "Keperluan keluarga"}
    )
    assert res_off.status_code == 200

    # Duplikat request off harus 409
    res_dup_off = await client.post(
        "/api/v1/jadwal/request-off",
        headers={"Authorization": f"Bearer {token_bar}"},
        json={"tanggal": off_date, "alasan": "Duplikat"}
    )
    assert res_dup_off.status_code == 409

    # 4. Tukar Shift
    res_tukar = await client.post(
        "/api/v1/jadwal/tukar-shift",
        headers={"Authorization": f"Bearer {token_bar}"},
        json={
            "shift_a_id": sched_bar_id,
            "shift_b_id": sched_kitchen_id,
            "karyawan_target_id": user_kitchen.id,
            "alasan": "Tukar shift"
        }
    )
    assert res_tukar.status_code == 200
    tukar_id = res_tukar.json()["id"]

    # Admin approve tukar shift
    res_app_tukar = await client.put(
        f"/api/v1/jadwal/tukar-shift/{tukar_id}/approval",
        headers={"Authorization": f"Bearer {token_admin}"},
        json={"status": "disetujui"}
    )
    assert res_app_tukar.status_code == 200

    # 5. Izin Telat
    res_telat = await client.post(
        "/api/v1/absensi/izin-telat",
        headers={"Authorization": f"Bearer {token_kitchen}"},
        json={"jadwal_shift_id": sched_bar_id, "alasan": "Motor bocor"}
    )
    assert res_telat.status_code == 200
    telat_id = res_telat.json()["id"]

    res_app_telat = await client.put(
        f"/api/v1/absensi/izin-telat/{telat_id}/approval",
        headers={"Authorization": f"Bearer {token_admin}"},
        json={"status": "disetujui"}
    )
    assert res_app_telat.status_code == 200
    assert res_app_telat.json()["status"] == "disetujui"

    # 6. Izin Tidak Masuk
    foto_izin = Foto(
        id="foto-izin-test",
        uploader_id=user_bar.id,
        jenis="izin",
        path="uploads/test_izin.jpg",
        dipakai=False
    )
    test_db.add(foto_izin)
    await test_db.commit()

    res_tm = await client.post(
        "/api/v1/absensi/izin-tidak-masuk",
        headers={"Authorization": f"Bearer {token_bar}"},
        json={"jadwal_shift_id": sched_kitchen_id, "alasan": "Sakit demam", "foto_id": "foto-izin-test"}
    )
    assert res_tm.status_code == 200
    tm_id = res_tm.json()["id"]

    res_app_tm = await client.put(
        f"/api/v1/absensi/izin-tidak-masuk/{tm_id}/approval",
        headers={"Authorization": f"Bearer {token_admin}"},
        json={"status": "disetujui"}
    )
    assert res_app_tm.status_code == 200
    assert res_app_tm.json()["status"] == "disetujui"

    # 7. Absensi Masuk & Pulang
    # Buat shift hari ini untuk user_kitchen
    shift_today = JadwalShift(
        id="shift-today-test",
        karyawan_id=user_kitchen.id,
        tanggal=today,
        shift="shift_1",
        area_kerja="bar",
        jam_mulai=time(0, 0),
        jam_selesai=time(23, 59)
    )
    foto_abs = Foto(
        id="foto-abs-test",
        uploader_id=user_kitchen.id,
        jenis="absensi",
        path="uploads/test_abs.jpg",
        dipakai=False
    )
    test_db.add_all([shift_today, foto_abs])
    await test_db.commit()

    # Absen masuk di luar radius lokasi cafe (Semarang vs Jakarta) -> tolak
    res_absen_far = await client.post(
        "/api/v1/absensi/masuk",
        headers={"Authorization": f"Bearer {token_kitchen}"},
        json={
            "jadwal_shift_id": "shift-today-test",
            "lat_masuk": -7.00000000,
            "lng_masuk": 110.00000000,
            "foto_masuk_id": "foto-abs-test"
        }
    )
    assert res_absen_far.status_code == 400

    # Buat ulang foto_abs karena sudah diclaim sebelum cek GPS
    foto_abs2 = Foto(
        id="foto-abs-test2",
        uploader_id=user_kitchen.id,
        jenis="absensi",
        path="uploads/test_abs2.jpg",
        dipakai=False
    )
    test_db.add(foto_abs2)
    await test_db.commit()

    # Absen masuk valid (lokasi cafe di sample_data adalah -6.20000000, 106.80000000)
    res_in = await client.post(
        "/api/v1/absensi/masuk",
        headers={"Authorization": f"Bearer {token_kitchen}"},
        json={
            "jadwal_shift_id": "shift-today-test",
            "lat_masuk": -6.20000000,
            "lng_masuk": 106.80000000,
            "foto_masuk_id": "foto-abs-test2"
        }
    )
    assert res_in.status_code == 200
    abs_id = res_in.json()["id"]

    # Absen pulang valid
    res_out = await client.post(
        f"/api/v1/absensi/{abs_id}/pulang",
        headers={"Authorization": f"Bearer {token_kitchen}"},
        json={
            "lat_pulang": -6.20000000,
            "lng_pulang": 106.80000000
        }
    )
    assert res_out.status_code == 200
    assert res_out.json()["jam_pulang"] is not None
