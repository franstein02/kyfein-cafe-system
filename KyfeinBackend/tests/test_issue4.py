import pytest
import pytest_asyncio
from datetime import time, timedelta
from decimal import Decimal

from app.core.utils import now_local
from app.models import JadwalShift, Absensi, StokOpname, Transaksi, TransaksiDetail, Karyawan
from app.core.transaksi_helper import is_transaksi_locked

@pytest.mark.asyncio
async def test_issue4_create_transaksi_prerequisites(client, sample_data, test_db, mock_time_at):
    """
    POST /transaksi validation:
    - User must have shift with area_kerja = 'kasir'
    - Shift must be today
    - Kasir must have checked in (Absensi row exists)
    """
    mock_time_at("20:00")
    today = now_local().date()

    # 1. Kasir 1 has shift-kasir-k1, but hasn't done absen_masuk yet -> 400
    res_no_absen = await client.post(
        "/api/v1/transaksi/",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "cash",
            "uang_diterima": 50000,
            "details": [{"menu_id": "menu-1", "qty": 1}]
        }
    )
    assert res_no_absen.status_code == 400
    assert "absen masuk" in res_no_absen.json()["detail"].lower()

    # Create Absensi for shift-kasir-k1
    absen_k1 = Absensi(
        id="abs-kasir-1",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-kasir-k1",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1"
    )
    test_db.add(absen_k1)
    await test_db.commit()

    # 2. Non-kasir shift (shift-bar-k1 with area_kerja 'bar') -> 400
    mock_time_at("10:00")
    res_bar = await client.post(
        "/api/v1/transaksi/",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "metode_bayar": "cash",
            "uang_diterima": 50000,
            "details": [{"menu_id": "menu-1", "qty": 1}]
        }
    )
    assert res_bar.status_code == 400
    assert "area_kerja kasir" in res_bar.json()["detail"].lower()

    # 3. Valid kasir create transaction -> 200
    mock_time_at("20:00")
    res_valid = await client.post(
        "/api/v1/transaksi/",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "cash",
            "uang_diterima": 50000,
            "details": [{"menu_id": "menu-1", "qty": 1}]
        }
    )
    assert res_valid.status_code == 200
    assert "id" in res_valid.json()

@pytest.mark.asyncio
async def test_issue4_lock_1_titik(client, sample_data, test_db, mock_time_at):
    """
    1 titik (bar only):
    Terkunci ketika shift bar pada tanggal & shift yang sama mengirim opname akhir_shift
    """
    mock_time_at("20:00")
    today = sample_data["today"]

    # Absen kasir
    absen = Absensi(
        id="abs-kasir-1t",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-kasir-k1",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1"
    )
    test_db.add(absen)
    await test_db.commit()

    # Before bar opname -> Not locked
    assert not await is_transaksi_locked(test_db, "shift-kasir-k1")

    # Bar submits akhir_shift opname for shift_2 (shift-bar-k2)
    op_bar = StokOpname(
        id="op-bar-end",
        jadwal_shift_id="shift-bar-k2",
        titik="bar",
        tipe="akhir_shift",
        metode="hitung_manual",
        karyawan_id="usr-karyawan2"
    )
    test_db.add(op_bar)
    await test_db.commit()

    # After bar opname -> Locked!
    assert await is_transaksi_locked(test_db, "shift-kasir-k1")

    # Create transaction attempted after lock -> 403
    res_trx = await client.post(
        "/api/v1/transaksi/",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "cash",
            "uang_diterima": 50000,
            "details": [{"menu_id": "menu-1", "qty": 1}]
        }
    )
    assert res_trx.status_code == 403

@pytest.mark.asyncio
async def test_issue4_lock_2_titik_and_separuh(client, sample_data, test_db, mock_time_at):
    """
    2 titik (bar & kitchen):
    - Bar submit akhir_shift (opname separuh) -> Belum terkunci!
    - Kitchen submit akhir_shift -> Terkunci!
    """
    mock_time_at("20:00")
    today = sample_data["today"]

    # Add kitchen shift on same day and shift_2
    shift_kitchen = JadwalShift(
        id="shift-kitchen-k2",
        karyawan_id="usr-karyawan2",
        tanggal=today,
        shift="shift_2",
        area_kerja="kitchen",
        jam_mulai=time(16, 0),
        jam_selesai=time(23, 0)
    )
    test_db.add(shift_kitchen)
    await test_db.commit()

    # Shift kasir is shift-kasir-k1 (shift_2)
    # 1. Bar submits akhir_shift for shift_bar_k2 (shift_2)
    op_bar = StokOpname(
        id="op-bar2-end",
        jadwal_shift_id="shift-bar-k2",
        titik="bar",
        tipe="akhir_shift",
        metode="hitung_manual",
        karyawan_id="usr-karyawan2"
    )
    test_db.add(op_bar)
    await test_db.commit()

    # Opname separuh (bar done, kitchen pending) -> NOT locked yet!
    assert not await is_transaksi_locked(test_db, "shift-kasir-k1")

    # 2. Kitchen submits akhir_shift
    op_kitchen = StokOpname(
        id="op-kitchen-end",
        jadwal_shift_id="shift-kitchen-k2",
        titik="kitchen",
        tipe="akhir_shift",
        metode="hitung_manual",
        karyawan_id="usr-karyawan2"
    )
    test_db.add(op_kitchen)
    await test_db.commit()

    # Both done -> Locked!
    assert await is_transaksi_locked(test_db, "shift-kasir-k1")

@pytest.mark.asyncio
async def test_issue4_lock_0_titik_fallback(client, sample_data, test_db, mock_time_at):
    """
    0 titik (no bar or kitchen shifts scheduled):
    - Fallback: locked when kasir completes absen_pulang (jam_pulang is filled)
    """
    mock_time_at("10:00")
    today = sample_data["today"]

    # Create kasir-only shift on a different day/shift (e.g. tomorrow shift_1)
    tomorrow = today + timedelta(days=1)
    shift_kasir_solo = JadwalShift(
        id="shift-kasir-solo",
        karyawan_id="usr-karyawan1",
        tanggal=tomorrow,
        shift="shift_1",
        area_kerja="kasir",
        jam_mulai=time(8, 0),
        jam_selesai=time(16, 0)
    )
    test_db.add(shift_kasir_solo)
    await test_db.commit()

    # 1. Before absensi -> Not locked
    assert not await is_transaksi_locked(test_db, "shift-kasir-solo")

    # 2. Absen masuk -> Not locked
    absen_solo = Absensi(
        id="abs-solo",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-kasir-solo",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1"
    )
    test_db.add(absen_solo)
    await test_db.commit()

    assert not await is_transaksi_locked(test_db, "shift-kasir-solo")

    # 3. Absen pulang (jam_pulang set) -> Locked!
    absen_solo.jam_pulang = now_local()
    await test_db.commit()

    assert await is_transaksi_locked(test_db, "shift-kasir-solo")

@pytest.mark.asyncio
async def test_issue4_cancel_transaksi_authorization(client, sample_data, test_db, mock_time_at):
    """
    Cancel transaksi rules:
    - Kasir can cancel own transaction before locked
    - Kasir trying to cancel another kasir's transaction -> 403
    - After locked: Kasir and Admin both get 403 when trying to cancel
    """
    mock_time_at("20:00")
    # Create Absensi for kasir
    absen = Absensi(
        id="abs-kasir-cancel",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-kasir-k1",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1"
    )
    test_db.add(absen)
    await test_db.commit()

    # Create transaction 1 by K1
    res_create1 = await client.post(
        "/api/v1/transaksi/",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "cash",
            "uang_diterima": 50000,
            "details": [{"menu_id": "menu-1", "qty": 1}]
        }
    )
    trx_id1 = res_create1.json()["id"]

    # 1. K1 cancels own transaction before lock -> 200 (status = dibatalkan)
    res_k1_cancel = await client.put(
        f"/api/v1/transaksi/{trx_id1}/cancel",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"}
    )
    assert res_k1_cancel.status_code == 200
    assert res_k1_cancel.json()["status"] == "dibatalkan"

    # Create transaction 2 by K1
    res_create2 = await client.post(
        "/api/v1/transaksi/",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "cash",
            "uang_diterima": 50000,
            "details": [{"menu_id": "menu-1", "qty": 1}]
        }
    )
    trx_id2 = res_create2.json()["id"]

    # 2. K2 (another kasir) tries to cancel K1's transaction -> 403
    res_k2_cancel = await client.put(
        f"/api/v1/transaksi/{trx_id2}/cancel",
        headers={"Authorization": f"Bearer {sample_data['token_k2']}"}
    )
    assert res_k2_cancel.status_code == 403

    # 3. Lock the shift via bar opname akhir_shift
    op_bar = StokOpname(
        id="op-bar-end-cancel",
        jadwal_shift_id="shift-bar-k2",
        titik="bar",
        tipe="akhir_shift",
        metode="hitung_manual",
        karyawan_id="usr-karyawan2"
    )
    test_db.add(op_bar)
    await test_db.commit()

    # 4. After locked: K1 (kasir) gets 403
    res_k1_after_lock = await client.put(
        f"/api/v1/transaksi/{trx_id2}/cancel",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"}
    )
    assert res_k1_after_lock.status_code == 403

    # 5. After locked: Admin also gets 403
    res_admin_after_lock = await client.put(
        f"/api/v1/transaksi/{trx_id2}/cancel",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"}
    )
    assert res_admin_after_lock.status_code == 403

@pytest.mark.asyncio
async def test_issue4_opname_kasir_area_rejected(client, sample_data, mock_time_at):
    """Opname endpoint rejects shifts with area_kerja = 'kasir' with 400"""
    mock_time_at("20:00")
    res = await client.post(
        "/api/v1/stok/opname",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "titik": "bar",
            "tipe": "awal_shift",
            "items": [{"bahan_id": "b-1", "jumlah": 10}]
        }
    )
    assert res.status_code == 400
    assert "kasir" in res.json()["detail"].lower()
