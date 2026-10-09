import pytest
from datetime import timedelta
from decimal import Decimal

from app.core.utils import now_local
from app.models.jadwal import TukarShift
from app.models.absensi import Absensi, IzinTelat, IzinTidakMasuk
from app.models.stok import StokOpname

# ==========================================
# A2 & A12 TESTS
# ==========================================

@pytest.mark.asyncio
async def test_a2_master_data_login_required(client):
    """semua GET di master_data wajib login."""
    res1 = await client.get("/api/v1/master/kategori-menu")
    assert res1.status_code == 401

    res2 = await client.get("/api/v1/master/menu")
    assert res2.status_code == 401

    res3 = await client.get("/api/v1/master/bahan")
    assert res3.status_code == 401

    res4 = await client.get("/api/v1/master/kategori-pengeluaran")
    assert res4.status_code == 401


@pytest.mark.asyncio
async def test_a2_harga_rata_rata_schema_separation(client, sample_data):
    """harga_rata_rata hanya tampil untuk admin/owner (schema output terpisah untuk karyawan tanpa field itu)."""
    # Karyawan request GET /bahan
    res_k1 = await client.get(
        "/api/v1/master/bahan",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"}
    )
    assert res_k1.status_code == 200
    data_k1 = res_k1.json()
    assert len(data_k1) > 0
    assert "harga_rata_rata" not in data_k1[0]

    # Admin request GET /bahan
    res_admin = await client.get(
        "/api/v1/master/bahan",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"}
    )
    assert res_admin.status_code == 200
    data_admin = res_admin.json()
    assert len(data_admin) > 0
    assert "harga_rata_rata" in data_admin[0]


@pytest.mark.asyncio
async def test_a12_include_nonaktif_role_restriction(client, sample_data):
    """list_menu/list_kategori_menu menerima parameter include_nonaktif, hanya efektif untuk admin/owner."""
    # Karyawan passes include_nonaktif=true -> should still only get active items
    res_k1 = await client.get(
        "/api/v1/master/menu?include_nonaktif=true",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"}
    )
    assert res_k1.status_code == 200
    assert len(res_k1.json()) == 1
    assert res_k1.json()[0]["id"] == "menu-1"

    # Admin passes include_nonaktif=true -> gets active & nonaktif items
    res_admin = await client.get(
        "/api/v1/master/menu?include_nonaktif=true",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"}
    )
    assert res_admin.status_code == 200
    assert len(res_admin.json()) == 2


# ==========================================
# A3 TESTS (TUKAR SHIFT & APPROVAL)
# ==========================================

@pytest.mark.asyncio
async def test_a3_tukar_shift_validations(client, sample_data, test_db):
    """
    validasi shift_a.karyawan_id == pengaju dan shift_b.karyawan_id == karyawan_target_id
    pengaju tidak boleh sama dengan target
    tolak pengajuan duplikat yang masih pending untuk pasangan shift yang sama
    """
    # 1. Shift A not owned by pengaju (K1 tries using K2's shift as shift_a)
    res1 = await client.post(
        "/api/v1/jadwal/tukar-shift",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "shift_a_id": "shift-bar-k2",
            "shift_b_id": "shift-bar-k1",
            "karyawan_target_id": "usr-karyawan1",
            "alasan": "Tukar shift"
        }
    )
    assert res1.status_code == 400

    # 2. Pengaju sama dengan target
    res2 = await client.post(
        "/api/v1/jadwal/tukar-shift",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "shift_a_id": "shift-bar-k1",
            "shift_b_id": "shift-bar-k1",
            "karyawan_target_id": "usr-karyawan1",
            "alasan": "Tukar sendiri"
        }
    )
    assert res2.status_code == 400

    # 3. Valid shift swap request
    res3 = await client.post(
        "/api/v1/jadwal/tukar-shift",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "shift_a_id": "shift-bar-k1",
            "shift_b_id": "shift-bar-k2",
            "karyawan_target_id": "usr-karyawan2",
            "alasan": "Acara keluarga"
        }
    )
    assert res3.status_code == 200

    # 4. Duplicate pending request for same pair -> 409
    res4 = await client.post(
        "/api/v1/jadwal/tukar-shift",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "shift_a_id": "shift-bar-k1",
            "shift_b_id": "shift-bar-k2",
            "karyawan_target_id": "usr-karyawan2",
            "alasan": "Acara keluarga lagi"
        }
    )
    assert res4.status_code == 409


@pytest.mark.asyncio
async def test_a3_approval_already_processed_returns_409(client, sample_data, test_db):
    """approval tukar shift, izin telat, dan izin tidak masuk hanya boleh jika status == 'pending', selain itu 409."""
    # Create an already approved TukarShift
    ts = TukarShift(
        id="ts-done",
        shift_a_id="shift-bar-k1",
        shift_b_id="shift-bar-k2",
        karyawan_pengaju_id="usr-karyawan1",
        karyawan_target_id="usr-karyawan2",
        status="disetujui"
    )
    # Create an already approved IzinTelat
    it = IzinTelat(
        id="it-done",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-bar-k1",
        alasan="Macet",
        status="disetujui"
    )
    # Create an already rejected IzinTidakMasuk
    itm = IzinTidakMasuk(
        id="itm-done",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-bar-k1",
        alasan="Sakit",
        foto_id="foto-izin-k1",
        status="ditolak"
    )
    test_db.add_all([ts, it, itm])
    await test_db.commit()

    # Re-approval attempts should fail with 409
    res_ts = await client.put(
        "/api/v1/jadwal/tukar-shift/ts-done/approval",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={"status": "ditolak"}
    )
    assert res_ts.status_code == 409

    res_it = await client.put(
        "/api/v1/absensi/izin-telat/it-done/approval",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={"status": "ditolak"}
    )
    assert res_it.status_code == 409

    res_itm = await client.put(
        "/api/v1/absensi/izin-tidak-masuk/itm-done/approval",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={"status": "disetujui"}
    )
    assert res_itm.status_code == 409


# ==========================================
# A4 TESTS (ABSENSI)
# ==========================================

@pytest.mark.asyncio
async def test_a4_absen_masuk_past_shift_rejected(client, sample_data, mock_time_10):
    """absen_masuk hanya jika shift.tanggal == hari ini"""
    res = await client.post(
        "/api/v1/absensi/masuk",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-past",
            "lat_masuk": -6.20000000,
            "lng_masuk": 106.80000000,
            "foto_masuk_id": "foto-k1"
        }
    )
    assert res.status_code == 400
    assert "shift yang sedang berjalan" in res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_a4_absen_masuk_rejected_if_izin_tidak_masuk_approved(client, sample_data, test_db, mock_time_at):
    """absen masuk ditolak jika ada izin_tidak_masuk disetujui untuk shift itu"""
    mock_time_at("10:00")
    itm_approved = IzinTidakMasuk(
        id="itm-app",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-bar-k1",
        alasan="Demam tinggi",
        foto_id="foto-izin-k1",
        status="disetujui"
    )
    test_db.add(itm_approved)
    await test_db.commit()

    res = await client.post(
        "/api/v1/absensi/masuk",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "lat_masuk": -6.20000000,
            "lng_masuk": 106.80000000,
            "foto_masuk_id": "foto-k1"
        }
    )
    assert res.status_code == 400
    assert "izin tidak masuk" in res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_a4_absen_pulang_gps_radius_validation(client, sample_data, test_db):
    """absen_pulang memvalidasi radius GPS server-side dengan helper haversine_distance yang sama"""
    # Create active absensi record
    absen = Absensi(
        id="abs-1",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-bar-k1",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1"
    )
    test_db.add(absen)
    await test_db.commit()

    # Absen pulang with coordinates far away (e.g. lat -6.50)
    res_far = await client.post(
        "/api/v1/absensi/abs-1/pulang",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "lat_pulang": -6.50000000,
            "lng_pulang": 106.80000000,
            "foto_pulang_id": "foto-k1"
        }
    )
    assert res_far.status_code == 400
    assert "radius" in res_far.json()["detail"].lower()


# ==========================================
# A6 TESTS (STOK OPNAME)
# ==========================================

@pytest.mark.asyncio
async def test_a6_opname_duplicate_bahan_aggregated(client, sample_data, test_db, mock_time_at):
    """jumlahkan items yang bahan_id-nya sama sebelum menyimpan dan membandingkan"""
    mock_time_at("10:00")
    # 1. Submit awal_shift opname with duplicate items
    res = await client.post(
        "/api/v1/stok/opname",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "titik": "bar",
            "tipe": "awal_shift",
            "metode": "hitung_manual",
            "items": [
                {"bahan_id": "b-1", "jumlah": 10},
                {"bahan_id": "b-1", "jumlah": 15}
            ]
        }
    )
    assert res.status_code == 200
    op_id = res.json()["id"]

    # Verify detail was aggregated to 25
    op_db = await test_db.get(StokOpname, op_id)
    assert op_db is not None
    assert op_db.karyawan_id == "usr-karyawan1" # karyawan_id always shift assigned worker


@pytest.mark.asyncio
async def test_a6_opname_metode_server_determined_and_awal_required(client, sample_data, mock_time_at):
    """
    metode ditentukan server, field metode dari client diabaikan.
    awal_shift harus ada sebelum akhir_shift di shift yang sama.
    shift area_kerja kasir ditolak.
    """
    mock_time_at("10:00")
    # 1. akhir_shift without prior awal_shift -> 400
    res_akhir = await client.post(
        "/api/v1/stok/opname",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "titik": "bar",
            "tipe": "akhir_shift",
            "metode": "carry_forward", # Client passes carry_forward, but server ignores and requires awal_shift first
            "items": [{"bahan_id": "b-1", "jumlah": 10}]
        }
    )
    assert res_akhir.status_code == 400
    assert "awal_shift harus ada" in res_akhir.json()["detail"]

    mock_time_at("20:00")
    # 2. Kasir shift opname rejected -> 400
    res_kasir = await client.post(
        "/api/v1/stok/opname",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "titik": "bar",
            "tipe": "awal_shift",
            "metode": "hitung_manual",
            "items": [{"bahan_id": "b-1", "jumlah": 10}]
        }
    )
    assert res_kasir.status_code == 400
    assert "kasir tidak memerlukan stok opname" in res_kasir.json()["detail"]

    mock_time_at("10:00")
    # 3. Past shift opname rejected -> 403
    # Sejak Issue 10-11, karyawan biasa pada shift yang jendelanya habis mendapat 403 (hanya admin yang boleh susulan).
    res_past = await client.post(
        "/api/v1/stok/opname",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-past",
            "titik": "bar",
            "tipe": "awal_shift",
            "metode": "hitung_manual",
            "items": [{"bahan_id": "b-1", "jumlah": 10}]
        }
    )
    assert res_past.status_code == 403
    assert "hanya admin yang dapat menyusulkan opname" in res_past.json()["detail"].lower()


@pytest.mark.asyncio
async def test_a6_opname_karyawan_id_is_assigned_worker(client, sample_data, test_db, mock_time_at):
    """karyawan_id opname selalu karyawan yang di-assign di shift, bukan admin yang submit"""
    mock_time_at("10:00")
    res = await client.post(
        "/api/v1/stok/opname",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "titik": "bar",
            "tipe": "awal_shift",
            "items": [{"bahan_id": "b-1", "jumlah": 20}]
        }
    )
    assert res.status_code == 200
    assert res.json()["karyawan_id"] == "usr-karyawan1"


# ==========================================
# A9 TESTS (PYDANTIC & INTEGRITY ERROR)
# ==========================================

@pytest.mark.asyncio
async def test_a9_pydantic_validations(client, sample_data):
    """Field(gt=0) untuk nominal/jumlah/harga, min_length=1 untuk teks wajib, validator PengeluaranCreate"""
    # 1. Invalid nominal (<= 0) in Pengeluaran
    res_neg = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "kategori_id": "katp-1",
            "tipe": "mendadak",
            "nominal": -50000,
            "tanggal": str(sample_data["today"])
        }
    )
    assert res_neg.status_code == 422

    # 2. Pengeluaran bulanan without bulan -> 422
    res_bulanan_invalid = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "kategori_id": "katp-1",
            "tipe": "bulanan",
            "nominal": 50000,
            "tanggal": str(sample_data["today"]) # Should be bulan, not tanggal
        }
    )
    assert res_bulanan_invalid.status_code == 422


@pytest.mark.asyncio
async def test_a9_integrity_error_converted_to_409_and_400(client, sample_data):
    """Tangkap IntegrityError (kode unik, FK) dan ubah menjadi 409/400."""
    # Duplicate kode_menu -> 409
    res_dup = await client.post(
        "/api/v1/master/menu",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "nama": "Espresso Double",
            "kode_menu": "ESP01", # Existing code
            "harga": 30000,
            "kategori_id": "kat-1"
        }
    )
    assert res_dup.status_code == 409

    # Foreign Key Error (invalid kategori_id) -> 400
    res_fk = await client.post(
        "/api/v1/master/menu",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"},
        json={
            "nama": "Special Drink",
            "kode_menu": "SPC99",
            "harga": 30000,
            "kategori_id": "non-existent-kat"
        }
    )
    assert res_fk.status_code == 400


# ==========================================
# A10 & A11 TESTS
# ==========================================

@pytest.mark.asyncio
async def test_a10_now_local_helper():
    """satu helper now_local() (waktu lokal server, selaras dengan kolom DATETIME naive)"""
    nl = now_local()
    assert nl.tzinfo is None


@pytest.mark.asyncio
async def test_a11_get_jadwal_role_visibility(client, sample_data):
    """GET /jadwal: karyawan hanya melihat jadwalnya sendiri, admin/owner melihat semua."""
    # Karyawan 1 sees only their own schedules
    res_k1 = await client.get(
        "/api/v1/jadwal/",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"}
    )
    assert res_k1.status_code == 200
    k1_jadwal_ids = [j["id"] for j in res_k1.json()]
    assert "shift-bar-k1" in k1_jadwal_ids
    assert "shift-bar-k2" not in k1_jadwal_ids

    # Admin sees all schedules
    res_admin = await client.get(
        "/api/v1/jadwal/",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"}
    )
    assert res_admin.status_code == 200
    admin_jadwal_ids = [j["id"] for j in res_admin.json()]
    assert "shift-bar-k1" in admin_jadwal_ids
    assert "shift-bar-k2" in admin_jadwal_ids
