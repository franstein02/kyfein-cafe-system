import pytest
from datetime import date, timedelta, time
from decimal import Decimal
from sqlalchemy.exc import IntegrityError

from app.core.utils import now_local
from app.models import JadwalShift, StokOpname, KonfigurasiLokasi, Karyawan, KategoriPengeluaran, Pengeluaran

@pytest.mark.asyncio
async def test_issue9_opname_server_determined_method_and_rules(client, sample_data, test_db, mock_time_at):
    """
    Test Opname A6 sisa:
    - akhir_shift rejected if awal_shift missing -> 400
    - metode from client ignored, server sets hitung_manual / carry_forward
    - karyawan_id set to shift assigned employee
    """
    mock_time_at("10:00")
    today = sample_data["today"]

    # 1. akhir_shift submitted without prior awal_shift -> 400
    res_akhir_no_awal = await client.post(
        "/api/v1/stok/opname",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "titik": "bar",
            "tipe": "akhir_shift",
            "metode": "carry_forward",  # Client attempts to send carry_forward (ignored)
            "items": [{"bahan_id": "b-1", "jumlah": 10}]
        }
    )
    assert res_akhir_no_awal.status_code == 400
    assert "awal_shift harus ada" in res_akhir_no_awal.json()["detail"].lower()

    # 2. awal_shift submitted -> method set to hitung_manual (no prior shift today)
    res_awal = await client.post(
        "/api/v1/stok/opname",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "titik": "bar",
            "tipe": "awal_shift",
            "items": [{"bahan_id": "b-1", "jumlah": 100}]
        }
    )
    assert res_awal.status_code == 200
    awal_data = res_awal.json()
    assert awal_data["metode"] == "hitung_manual"
    assert awal_data["karyawan_id"] == "usr-karyawan1"

    # 3. akhir_shift submitted now -> succeeds with hitung_manual
    res_akhir = await client.post(
        "/api/v1/stok/opname",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "titik": "bar",
            "tipe": "akhir_shift",
            "items": [{"bahan_id": "b-1", "jumlah": 90}]
        }
    )
    assert res_akhir.status_code == 200
    akhir_data = res_akhir.json()
    assert akhir_data["metode"] == "hitung_manual"
    assert akhir_data["karyawan_id"] == "usr-karyawan1"

    mock_time_at("20:00")
    # 4. Next shift on same day for K2 -> awal_shift automatically gets carry_forward
    res_awal_k2 = await client.post(
        "/api/v1/stok/opname",
        headers={"Authorization": f"Bearer {sample_data['token_k2']}"},
        json={
            "jadwal_shift_id": "shift-bar-k2",
            "titik": "bar",
            "tipe": "awal_shift",
            "items": []
        }
    )
    assert res_awal_k2.status_code == 200
    awal_k2_data = res_awal_k2.json()
    assert awal_k2_data["metode"] == "carry_forward"
    assert awal_k2_data["karyawan_id"] == "usr-karyawan2"

@pytest.mark.asyncio
async def test_issue9_pengeluaran_pydantic_validation(client, sample_data):
    """
    Test PengeluaranCreate validator:
    - bulanan: requires bulan & no tanggal
    - mendadak: requires tanggal & no bulan
    - nominal <= 0 -> 422
    """
    # 1. bulanan without bulan -> 422
    res1 = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "kategori_id": "katp-1",
            "tipe": "bulanan",
            "nominal": 50000
        }
    )
    assert res1.status_code == 422

    # 2. bulanan with valid bulan -> 200
    res2 = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "kategori_id": "katp-1",
            "tipe": "bulanan",
            "nominal": 50000,
            "bulan": now_local().date().isoformat()
        }
    )
    assert res2.status_code == 200

    # 3. mendadak without tanggal -> 422
    res3 = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "kategori_id": "katp-1",
            "tipe": "mendadak",
            "nominal": 20000
        }
    )
    assert res3.status_code == 422

    # 4. nominal <= 0 -> 422
    res4 = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "kategori_id": "katp-1",
            "tipe": "mendadak",
            "nominal": 0,
            "tanggal": now_local().date().isoformat()
        }
    )
    assert res4.status_code == 422

@pytest.mark.asyncio
async def test_issue9_konfigurasi_lokasi_update_and_audit(client, sample_data):
    """
    Test GET & PUT /master/konfigurasi-lokasi:
    - PUT updates location config and sets updated_by = current_user.id
    """
    # 1. GET location config
    res_get = await client.get(
        "/api/v1/master/konfigurasi-lokasi",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"}
    )
    assert res_get.status_code == 200

    # 2. PUT update location config
    res_put = await client.put(
        "/api/v1/master/konfigurasi-lokasi",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "latitude": -6.21000000,
            "longitude": 106.81000000,
            "radius_meter": 75.0
        }
    )
    assert res_put.status_code == 200
    data = res_put.json()
    assert float(data["latitude"]) == -6.21000000
    assert float(data["longitude"]) == 106.81000000
    assert float(data["radius_meter"]) == 75.0
    assert data["updated_by"] == "usr-admin"
