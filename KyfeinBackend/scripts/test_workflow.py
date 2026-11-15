import os
import sys
import io
import json
import uuid
from datetime import datetime, timedelta, time
import requests
from PIL import Image

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.security import create_access_token
from app.core.utils import now_local

BASE_URL = "http://127.0.0.1:8000/api/v1"
CAFE_LAT = -7.82841199
CAFE_LNG = 111.99807238

def make_dummy_image_bytes():
    buf = io.BytesIO()
    img = Image.new("RGB", (100, 100), color=(73, 109, 137))
    img.save(buf, format="JPEG")
    return buf.getvalue()

def run_tests():
    print("=" * 60)
    print("KYFEIN E2E TEST: AKUN BAR, KITCHEN & WORKFLOW JADWAL / ABSENSI")
    print("=" * 60)

    # 1. LOGIN TESTS
    print("\n[1] Testing Login Karyawan Bar & Kitchen...")
    resp_bar = requests.post(f"{BASE_URL}/auth/login", json={
        "email": "barista@kyfein.cafe",
        "password": "password123"
    })
    assert resp_bar.status_code == 200, f"Login Barista failed: {resp_bar.text}"
    bar_data = resp_bar.json()
    token_bar = bar_data["access_token"]
    user_bar_id = bar_data["user_id"]
    print(f"  -> Bar login OK! Name: {bar_data['nama']}, Role: {bar_data['role']}, ID: {user_bar_id}")

    resp_kitchen = requests.post(f"{BASE_URL}/auth/login", json={
        "email": "kitchen@kyfein.cafe",
        "password": "password123"
    })
    assert resp_kitchen.status_code == 200, f"Login Kitchen failed: {resp_kitchen.text}"
    kitchen_data = resp_kitchen.json()
    token_kitchen = kitchen_data["access_token"]
    user_kitchen_id = kitchen_data["user_id"]
    print(f"  -> Kitchen login OK! Name: {kitchen_data['nama']}, Role: {kitchen_data['role']}, ID: {user_kitchen_id}")

    # Admin Token (Frans)
    admin_id = "6eb0abd6-c196-11f1-84bd-00155dbd31c3"
    token_admin = create_access_token(subject=admin_id, role="admin")
    admin_headers = {"Authorization": f"Bearer {token_admin}"}
    bar_headers = {"Authorization": f"Bearer {token_bar}"}
    kitchen_headers = {"Authorization": f"Bearer {token_kitchen}"}

    today = now_local().date()
    target_date = today + timedelta(days=2)
    target_date_str = target_date.isoformat()

    # 2. PEMBUATAN JADWAL
    print(f"\n[2] Testing Pembuatan Jadwal (Admin) untuk Bar & Kitchen pada {target_date_str}...")
    
    # 2a. Admin creates schedule for Bar
    sched_bar_payload = {
        "karyawan_id": user_bar_id,
        "tanggal": target_date_str,
        "shift": "shift_1",
        "area_kerja": "bar",
        "jam_mulai": "08:00:00",
        "jam_selesai": "16:00:00"
    }
    r_create_bar = requests.post(f"{BASE_URL}/jadwal/", headers=admin_headers, json=sched_bar_payload)
    assert r_create_bar.status_code == 200, f"Create Bar schedule failed: {r_create_bar.text}"
    sched_bar = r_create_bar.json()
    sched_bar_id = sched_bar["id"]
    print(f"  -> Created Bar schedule: ID={sched_bar_id}, Shift={sched_bar['shift']}, Area={sched_bar['area_kerja']}")

    # 2b. Admin creates schedule for Kitchen
    sched_kitchen_payload = {
        "karyawan_id": user_kitchen_id,
        "tanggal": target_date_str,
        "shift": "shift_2",
        "area_kerja": "kitchen",
        "jam_mulai": "16:00:00",
        "jam_selesai": "23:00:00"
    }
    r_create_kitchen = requests.post(f"{BASE_URL}/jadwal/", headers=admin_headers, json=sched_kitchen_payload)
    assert r_create_kitchen.status_code == 200, f"Create Kitchen schedule failed: {r_create_kitchen.text}"
    sched_kitchen = r_create_kitchen.json()
    sched_kitchen_id = sched_kitchen["id"]
    print(f"  -> Created Kitchen schedule: ID={sched_kitchen_id}, Shift={sched_kitchen['shift']}, Area={sched_kitchen['area_kerja']}")

    # 2c. Constraint test: Karyawan cannot have 2 shifts on same date
    r_dup_sched = requests.post(f"{BASE_URL}/jadwal/", headers=admin_headers, json={
        "karyawan_id": user_bar_id,
        "tanggal": target_date_str,
        "shift": "shift_2",
        "area_kerja": "bar",
        "jam_mulai": "16:00:00",
        "jam_selesai": "23:00:00"
    })
    assert r_dup_sched.status_code == 400, "Duplicate schedule should be rejected with 400"
    print(f"  -> [Constraint OK] Duplicate schedule on same date rejected: {r_dup_sched.json()['detail']}")

    # 2d. Non-admin cannot create schedule
    r_non_admin = requests.post(f"{BASE_URL}/jadwal/", headers=bar_headers, json=sched_bar_payload)
    assert r_non_admin.status_code == 403, "Karyawan creating schedule should be rejected with 403"
    print("  -> [Constraint OK] Karyawan create schedule rejected with 403 Forbidden")

    # 2e. List schedule filtering
    r_list_bar = requests.get(f"{BASE_URL}/jadwal/?tanggal={target_date_str}", headers=bar_headers)
    bar_items = r_list_bar.json()
    assert len(bar_items) == 1 and bar_items[0]["id"] == sched_bar_id, "Bar should only see their own schedule"
    print(f"  -> [Filter OK] Bar employee only sees their own schedule (count: {len(bar_items)})")

    r_list_admin = requests.get(f"{BASE_URL}/jadwal/?tanggal={target_date_str}", headers=admin_headers)
    admin_items = r_list_admin.json()
    assert len(admin_items) >= 2, "Admin should see all schedules"
    print(f"  -> [Filter OK] Admin sees all schedules on date (count: {len(admin_items)})")

    # 3. REQUEST OFF
    print("\n[3] Testing Request Off...")
    req_off_date = (today + timedelta(days=5)).isoformat()
    
    # 3a. Submit valid request off
    r_req_off = requests.post(f"{BASE_URL}/jadwal/request-off", headers=bar_headers, json={
        "tanggal": req_off_date,
        "alasan": "Ada keperluan keluarga penting"
    })
    assert r_req_off.status_code == 200, f"Submit request off failed: {r_req_off.text}"
    req_off_data = r_req_off.json()
    print(f"  -> Request Off submitted: ID={req_off_data['id']}, Tanggal={req_off_data['tanggal']}")

    # 3b. Past date rejection
    past_date = (today - timedelta(days=1)).isoformat()
    r_past_off = requests.post(f"{BASE_URL}/jadwal/request-off", headers=bar_headers, json={
        "tanggal": past_date,
        "alasan": "Kemarin lupa off"
    })
    assert r_past_off.status_code == 400, "Past date request off should be 400"
    print(f"  -> [Constraint OK] Past date request off rejected: {r_past_off.json()['detail']}")

    # 3c. Duplicate request off rejection
    r_dup_off = requests.post(f"{BASE_URL}/jadwal/request-off", headers=bar_headers, json={
        "tanggal": req_off_date,
        "alasan": "Ajukan lagi"
    })
    assert r_dup_off.status_code == 409, "Duplicate request off should be 409"
    print(f"  -> [Constraint OK] Duplicate request off rejected: {r_dup_off.json()['detail']}")

    # 3d. Visibility check (all karyawan can see request off to coordinate off days)
    r_list_off = requests.get(f"{BASE_URL}/jadwal/request-off", headers=kitchen_headers)
    assert any(x["id"] == req_off_data["id"] for x in r_list_off.json()), "Kitchen should see Bar's request off"
    print("  -> [Visibility OK] Kitchen employee can view other employees' request off")

    # 4. TUKAR SHIFT
    print("\n[4] Testing Tukar Shift...")
    # 4a. Check available shifts on target date for swap
    r_avail = requests.get(f"{BASE_URL}/jadwal/tukar-shift/jadwal-tersedia?tanggal={target_date_str}", headers=bar_headers)
    assert r_avail.status_code == 200
    avail_shifts = r_avail.json()
    assert any(s["id"] == sched_kitchen_id for s in avail_shifts), "Kitchen shift should be available for swap"
    print(f"  -> Available target shifts found: {len(avail_shifts)}")

    # 4b. Bar submits tukar shift targeting Kitchen's shift
    r_tukar = requests.post(f"{BASE_URL}/jadwal/tukar-shift", headers=bar_headers, json={
        "shift_a_id": sched_bar_id,
        "shift_b_id": sched_kitchen_id,
        "karyawan_target_id": user_kitchen_id,
        "alasan": "Ingin tukar ke shift sore (kitchen)"
    })
    assert r_tukar.status_code == 200, f"Submit tukar shift failed: {r_tukar.text}"
    tukar_data = r_tukar.json()
    tukar_id = tukar_data["id"]
    print(f"  -> Tukar shift submitted: ID={tukar_id}, Status={tukar_data['status']}")

    # 4c. Reject swap with self
    r_self_swap = requests.post(f"{BASE_URL}/jadwal/tukar-shift", headers=bar_headers, json={
        "shift_a_id": sched_bar_id,
        "shift_b_id": sched_bar_id,
        "karyawan_target_id": user_bar_id,
        "alasan": "Tukar sendiri"
    })
    assert r_self_swap.status_code in [400, 409], "Self swap should be rejected"
    print("  -> [Constraint OK] Self swap rejected")

    # 4d. Admin approves tukar shift
    r_app_tukar = requests.put(f"{BASE_URL}/jadwal/tukar-shift/{tukar_id}/approval", headers=admin_headers, json={
        "status": "disetujui"
    })
    assert r_app_tukar.status_code == 200, f"Approve tukar shift failed: {r_app_tukar.text}"
    print(f"  -> Tukar shift approved: Status={r_app_tukar.json()['status']}")

    # 4e. Verify swap result in database
    r_check_bar_new = requests.get(f"{BASE_URL}/jadwal/?tanggal={target_date_str}", headers=bar_headers)
    bar_assigned = r_check_bar_new.json()
    assert len(bar_assigned) == 1
    assert bar_assigned[0]["id"] == sched_kitchen_id, "Bar should now have sched_kitchen_id (Shift 2)!"
    print(f"  -> [Swap Verified] Bar now holds: Shift={bar_assigned[0]['shift']}, Area={bar_assigned[0]['area_kerja']}")

    r_check_kitch_new = requests.get(f"{BASE_URL}/jadwal/?tanggal={target_date_str}", headers=kitchen_headers)
    kitch_assigned = r_check_kitch_new.json()
    assert len(kitch_assigned) == 1
    assert kitch_assigned[0]["id"] == sched_bar_id, "Kitchen should now have sched_bar_id (Shift 1)!"
    print(f"  -> [Swap Verified] Kitchen now holds: Shift={kitch_assigned[0]['shift']}, Area={kitch_assigned[0]['area_kerja']}")

    # 5. IZIN TELAT
    print("\n[5] Testing Izin Telat...")
    # Kitchen (currently holding sched_bar_id) submits izin telat
    r_iz_telat = requests.post(f"{BASE_URL}/absensi/izin-telat", headers=kitchen_headers, json={
        "jadwal_shift_id": sched_bar_id,
        "alasan": "Macet parah karena ada perbaikan jalan"
    })
    assert r_iz_telat.status_code == 200, f"Submit izin telat failed: {r_iz_telat.text}"
    iz_telat_data = r_iz_telat.json()
    iz_telat_id = iz_telat_data["id"]
    print(f"  -> Izin Telat submitted: ID={iz_telat_id}, Status={iz_telat_data['status']}")

    # Duplicate pending check
    r_dup_telat = requests.post(f"{BASE_URL}/absensi/izin-telat", headers=kitchen_headers, json={
        "jadwal_shift_id": sched_bar_id,
        "alasan": "Ajukan lagi"
    })
    assert r_dup_telat.status_code == 400, "Duplicate pending izin telat should be 400"
    print(f"  -> [Constraint OK] Duplicate pending izin telat rejected: {r_dup_telat.json()['detail']}")

    # Admin approves izin telat
    r_app_telat = requests.put(f"{BASE_URL}/absensi/izin-telat/{iz_telat_id}/approval", headers=admin_headers, json={
        "status": "disetujui"
    })
    assert r_app_telat.status_code == 200, f"Approve izin telat failed: {r_app_telat.text}"
    print(f"  -> Izin Telat approved: Status={r_app_telat.json()['status']}")

    # 6. IZIN TIDAK MASUK
    print("\n[6] Testing Izin Tidak Masuk...")
    # Create a schedule for Bar on today + 3 for testing izin tidak masuk
    inact_date_str = (today + timedelta(days=3)).isoformat()
    r_sched_tm = requests.post(f"{BASE_URL}/jadwal/", headers=admin_headers, json={
        "karyawan_id": user_bar_id,
        "tanggal": inact_date_str,
        "shift": "shift_1",
        "area_kerja": "bar",
        "jam_mulai": "08:00:00",
        "jam_selesai": "16:00:00"
    })
    assert r_sched_tm.status_code == 200
    sched_tm_id = r_sched_tm.json()["id"]

    # Bar uploads photo proof for izin
    img_bytes = make_dummy_image_bytes()
    r_upload_izin = requests.post(
        f"{BASE_URL}/foto",
        headers=bar_headers,
        data={"jenis": "izin"},
        files={"file": ("surat_dokter.jpg", img_bytes, "image/jpeg")}
    )
    assert r_upload_izin.status_code in [200, 201], f"Upload photo failed: {r_upload_izin.text}"
    foto_izin_id = r_upload_izin.json()["id"]
    print(f"  -> Uploaded proof photo: ID={foto_izin_id}")

    # Bar submits izin tidak masuk
    r_iz_tm = requests.post(f"{BASE_URL}/absensi/izin-tidak-masuk", headers=bar_headers, json={
        "jadwal_shift_id": sched_tm_id,
        "alasan": "Sakit radang tenggorokan, surat istirahat dokter terlampir",
        "foto_id": foto_izin_id
    })
    assert r_iz_tm.status_code == 200, f"Submit izin tidak masuk failed: {r_iz_tm.text}"
    iz_tm_id = r_iz_tm.json()["id"]
    print(f"  -> Izin Tidak Masuk submitted: ID={iz_tm_id}, Status={r_iz_tm.json()['status']}")

    # Admin approves izin tidak masuk
    r_app_tm = requests.put(f"{BASE_URL}/absensi/izin-tidak-masuk/{iz_tm_id}/approval", headers=admin_headers, json={
        "status": "disetujui"
    })
    assert r_app_tm.status_code == 200, f"Approve izin tidak masuk failed: {r_app_tm.text}"
    print(f"  -> Izin Tidak Masuk approved: Status={r_app_tm.json()['status']}")

    # 7. ABSENSI MASUK & ABSEN PULANG
    print("\n[7] Testing Absensi (Masuk) & Absen Pulang...")
    # Create active shift for TODAY for Bar (Budi)
    # Using 00:00:00 to 23:59:00 so it covers current time
    today_str = today.isoformat()
    r_today_sched = requests.post(f"{BASE_URL}/jadwal/", headers=admin_headers, json={
        "karyawan_id": user_bar_id,
        "tanggal": today_str,
        "shift": "shift_2",
        "area_kerja": "bar",
        "jam_mulai": "00:00:00",
        "jam_selesai": "23:59:00"
    })
    assert r_today_sched.status_code == 200, f"Create today schedule failed: {r_today_sched.text}"
    today_sched_id = r_today_sched.json()["id"]
    print(f"  -> Created active shift today for Bar: ID={today_sched_id}")

    # Check shift-aktif endpoint
    r_shift_aktif = requests.get(f"{BASE_URL}/jadwal/shift-aktif", headers=bar_headers)
    assert r_shift_aktif.status_code == 200, f"Get shift aktif failed: {r_shift_aktif.text}"
    print(f"  -> shift-aktif endpoint returned: ID={r_shift_aktif.json()['id']}")

    # Upload photo for absensi
    r_upload_abs = requests.post(
        f"{BASE_URL}/foto",
        headers=bar_headers,
        data={"jenis": "absensi"},
        files={"file": ("selfie_masuk.jpg", img_bytes, "image/jpeg")}
    )
    assert r_upload_abs.status_code in [200, 201]
    foto_masuk_id = r_upload_abs.json()["id"]
    print(f"  -> Uploaded check-in selfie: ID={foto_masuk_id}")

    # 7a. Test GPS validation on check-in (outside radius: Jakarta)
    r_absen_far = requests.post(f"{BASE_URL}/absensi/masuk", headers=bar_headers, json={
        "jadwal_shift_id": today_sched_id,
        "lat_masuk": -6.20000000,
        "lng_masuk": 106.81666600,
        "foto_masuk_id": foto_masuk_id
    })
    assert r_absen_far.status_code == 400, "Absen outside radius should be rejected"
    print(f"  -> [Constraint OK] GPS radius rejection: {r_absen_far.json()['detail']}")

    # Note: Because the photo validation helper only claims photo when validation passes,
    # let's verify if we need to re-upload or if photo is still unclaimed.
    # In foto_helper: validate_and_claim_foto marks dipakai=True before GPS check.
    # So let's re-upload a photo for the valid check-in if claimed:
    r_upload_abs_valid = requests.post(
        f"{BASE_URL}/foto",
        headers=bar_headers,
        data={"jenis": "absensi"},
        files={"file": ("selfie_masuk_valid.jpg", img_bytes, "image/jpeg")}
    )
    assert r_upload_abs_valid.status_code in [200, 201]
    foto_masuk_valid_id = r_upload_abs_valid.json()["id"]

    # 7b. Valid Absen Masuk (within cafe radius)
    r_absen_in = requests.post(f"{BASE_URL}/absensi/masuk", headers=bar_headers, json={
        "jadwal_shift_id": today_sched_id,
        "lat_masuk": CAFE_LAT,
        "lng_masuk": CAFE_LNG,
        "foto_masuk_id": foto_masuk_valid_id
    })
    assert r_absen_in.status_code == 200, f"Absen masuk failed: {r_absen_in.text}"
    absensi_data = r_absen_in.json()
    absensi_id = absensi_data["id"]
    print(f"  -> Absen Masuk SUCCESS! ID={absensi_id}, Jam Masuk={absensi_data['jam_masuk']}, Menit Telat={absensi_data['menit_telat']}")

    # 7c. Reject duplicate Absen Masuk
    r_absen_in_dup = requests.post(f"{BASE_URL}/absensi/masuk", headers=bar_headers, json={
        "jadwal_shift_id": today_sched_id,
        "lat_masuk": CAFE_LAT,
        "lng_masuk": CAFE_LNG,
        "foto_masuk_id": foto_masuk_valid_id
    })
    assert r_absen_in_dup.status_code == 400
    print(f"  -> [Constraint OK] Duplicate check-in rejected: {r_absen_in_dup.json()['detail']}")

    # 7d. Absen Pulang - Test GPS validation (outside radius)
    r_pulang_far = requests.post(f"{BASE_URL}/absensi/{absensi_id}/pulang", headers=bar_headers, json={
        "lat_pulang": -6.20000000,
        "lng_pulang": 106.81666600
    })
    assert r_pulang_far.status_code == 400
    print(f"  -> [Constraint OK] Absen pulang outside radius rejected: {r_pulang_far.json()['detail']}")

    # 7e. Valid Absen Pulang
    r_pulang = requests.post(f"{BASE_URL}/absensi/{absensi_id}/pulang", headers=bar_headers, json={
        "lat_pulang": CAFE_LAT,
        "lng_pulang": CAFE_LNG
    })
    assert r_pulang.status_code == 200, f"Absen pulang failed: {r_pulang.text}"
    pulang_data = r_pulang.json()
    print(f"  -> Absen Pulang SUCCESS! Jam Pulang={pulang_data['jam_pulang']}, Status={pulang_data['status_pulang']}")

    # 7f. Reject duplicate Absen Pulang
    r_pulang_dup = requests.post(f"{BASE_URL}/absensi/{absensi_id}/pulang", headers=bar_headers, json={
        "lat_pulang": CAFE_LAT,
        "lng_pulang": CAFE_LNG
    })
    assert r_pulang_dup.status_code == 400
    print(f"  -> [Constraint OK] Duplicate clock-out rejected: {r_pulang_dup.json()['detail']}")

    print("\n" + "=" * 60)
    print("ALL TESTS PASSED SUCCESSFULLY! (100% VERIFIED)")
    print("=" * 60)

if __name__ == "__main__":
    run_tests()

