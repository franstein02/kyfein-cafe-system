"""
Comprehensive tests for the 5 operational hardening & reporting requirements:
1. Pengeluaran bulanan hanya bulan ini & maks 1x per kategori per bulan.
2. Stok opname selisih Shift 1 vs Shift 2 + perhitungan pemakaian sistem (BOM) vs stok aktual & ekspektasi stok.
3. Tukar shift konfirmasi dua tahap (target rekan -> admin).
4. Rekap stok & POS hanya dapat diakses saat karyawan sedang bekerja hari ini (tidak off/libur).
5. Off-shift & belum absen masuk mengunci seluruh fitur operasional (POS, KDS, stok opname, gudang, rekap stok).
"""

from datetime import datetime, time, timedelta
from decimal import Decimal
import pytest

from app.core.security import create_access_token
from app.core.utils import now_local
from app.models import (
    Absensi,
    Bahan,
    JadwalShift,
    Karyawan,
    MenuResep,
    StokGudang,
    Transaksi,
    TransaksiDetail,
)


@pytest.mark.asyncio
async def test_req1_pengeluaran_bulanan_current_month_only_and_unique_per_category(
    client, sample_data
):
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    today = now_local().date()
    cur_month = f"{today.year}-{today.month:02d}"
    prev_month_date = today.replace(day=1) - timedelta(days=1)
    prev_month = f"{prev_month_date.year}-{prev_month_date.month:02d}"
    next_month_date = (today.replace(day=28) + timedelta(days=4)).replace(day=1)
    next_month = f"{next_month_date.year}-{next_month_date.month:02d}"

    kat_listrik = (
        await client.post(
            "/api/v1/master/kategori-pengeluaran",
            headers=headers_admin,
            json={"nama": "Listrik Hardening", "status_aktif": True},
        )
    ).json()
    kat_air = (
        await client.post(
            "/api/v1/master/kategori-pengeluaran",
            headers=headers_admin,
            json={"nama": "Air Hardening", "status_aktif": True},
        )
    ).json()

    # 1. Bulan lalu ditolak 400
    r_prev = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "bulanan",
            "kategori_id": kat_listrik["id"],
            "nominal": 300000,
            "bulan": prev_month,
        },
    )
    assert r_prev.status_code == 400
    assert "bulan berjalan" in r_prev.json()["detail"].lower()

    # 2. Bulan depan ditolak 400
    r_next = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "bulanan",
            "kategori_id": kat_listrik["id"],
            "nominal": 300000,
            "bulan": next_month,
        },
    )
    assert r_next.status_code == 400

    # 3. Bulan berjalan pertama kali -> 200 OK
    r_ok = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "bulanan",
            "kategori_id": kat_listrik["id"],
            "nominal": 300000,
            "bulan": cur_month,
            "keterangan": "Listrik bulan ini",
        },
    )
    assert r_ok.status_code == 200
    listrik_id = r_ok.json()["id"]

    # 4. Duplikat kategori sama di bulan yang sama -> 409 Conflict
    r_dup = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "bulanan",
            "kategori_id": kat_listrik["id"],
            "nominal": 350000,
            "bulan": cur_month,
        },
    )
    assert r_dup.status_code == 409
    assert "1 kali per bulan" in r_dup.json()["detail"].lower()

    # 5. Kategori berbeda di bulan yang sama -> 200 OK
    r_air = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "bulanan",
            "kategori_id": kat_air["id"],
            "nominal": 150000,
            "bulan": cur_month,
        },
    )
    assert r_air.status_code == 200
    air_id = r_air.json()["id"]

    # 6. PUT edit nominal di kategori sendiri -> 200 OK, tapi ganti kategori ke Listrik yang sudah ada -> 409
    r_edit_ok = await client.put(
        f"/api/v1/reporting/pengeluaran/{listrik_id}",
        headers=headers_admin,
        json={"nominal": 325000},
    )
    assert r_edit_ok.status_code == 200

    r_edit_dup = await client.put(
        f"/api/v1/reporting/pengeluaran/{air_id}",
        headers=headers_admin,
        json={"kategori_id": kat_listrik["id"]},
    )
    assert r_edit_dup.status_code == 409


@pytest.mark.asyncio
async def test_req2_opname_shift1_vs_shift2_and_bom_expected_vs_actual(
    client, sample_data, test_db, mock_time_at
):
    """
    Skenario persis seperti contoh pengguna:
    - Shift 1 Bar: Stok Awal = 1000, BOM = 45 (3 cup x 15 gram) -> Ekspektasi Stok = 955
      Stok Akhir Aktual = 900 -> Pemakaian Aktual = 100 -> Selisih vs BOM = -55 (Indikasi Tumpah / Susut)
    - Shift 2 Bar: Stok Awal = 880 (selisih handover -20 dari Akhir S1 = 900!),
      BOM = 75 (5 cup x 15 gram) -> Ekspektasi Stok = 805, Stok Akhir Aktual = 805 -> Selisih vs BOM = 0 (Sesuai)
    """
    today = sample_data["today"]
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    headers_k1 = {"Authorization": f"Bearer {sample_data['token_k1']}"}
    headers_k2 = {"Authorization": f"Bearer {sample_data['token_k2']}"}

    # Resep menu-1 (Espresso Bar): 15 gram Biji Kopi (b-1) per cup
    test_db.add(
        MenuResep(
            id="resep-req2-kopi",
            menu_id="menu-1",
            bahan_id="b-1",
            jumlah_terpakai=Decimal("15.000"),
        )
    )
    # Absensi masuk untuk K1 (shift_1 bar) & K2 (shift_2 bar)
    test_db.add_all([
        Absensi(
            id="abs-req2-k1",
            karyawan_id="usr-karyawan1",
            jadwal_shift_id="shift-bar-k1",
            lat_masuk=Decimal("-6.20000000"),
            lng_masuk=Decimal("106.80000000"),
            foto_masuk_id="foto-k1",
        ),
        Absensi(
            id="abs-req2-k2",
            karyawan_id="usr-karyawan2",
            jadwal_shift_id="shift-bar-k2",
            lat_masuk=Decimal("-6.20000000"),
            lng_masuk=Decimal("106.80000000"),
            foto_masuk_id="foto-k1",
        ),
    ])

    # Shift kasir shift_1 untuk transaksi pagi (jam 11:00) -> 3 cup Espresso = 45 gram BOM
    shift_kasir_s1 = JadwalShift(
        id="shift-kasir-s1-req2",
        karyawan_id="usr-admin",
        tanggal=today,
        shift="shift_1",
        area_kerja="kasir",
        jam_mulai=time(8, 0),
        jam_selesai=time(16, 0),
    )
    trx_s1 = Transaksi(
        id="trx-req2-s1",
        nomor_transaksi="TRX-REQ2-S1",
        jadwal_shift_id="shift-kasir-s1-req2",
        kasir_id="usr-admin",
        metode_bayar="cash",
        status="selesai",
        total_harga=Decimal("60000.00"),
        waktu_transaksi=datetime.combine(today, time(11, 0)),
    )
    td_s1 = TransaksiDetail(
        id="td-req2-s1",
        transaksi_id="trx-req2-s1",
        menu_id="menu-1",
        qty=3,
        harga_satuan=Decimal("20000.00"),
        hpp_satuan=Decimal("2250.00"),
        subtotal=Decimal("60000.00"),
        status_item="selesai",
    )
    # Transaksi sore di shift_2 (jam 19:00) -> 5 cup Espresso = 75 gram BOM
    trx_s2 = Transaksi(
        id="trx-req2-s2",
        nomor_transaksi="TRX-REQ2-S2",
        jadwal_shift_id="shift-kasir-k1",
        kasir_id="usr-karyawan1",
        metode_bayar="cash",
        status="selesai",
        total_harga=Decimal("100000.00"),
        waktu_transaksi=datetime.combine(today, time(19, 0)),
    )
    td_s2 = TransaksiDetail(
        id="td-req2-s2",
        transaksi_id="trx-req2-s2",
        menu_id="menu-1",
        qty=5,
        harga_satuan=Decimal("20000.00"),
        hpp_satuan=Decimal("2250.00"),
        subtotal=Decimal("100000.00"),
        status_item="selesai",
    )
    test_db.add_all([shift_kasir_s1, trx_s1, td_s1, trx_s2, td_s2])
    await test_db.commit()

    # Opname Shift 1 (Awal 1000 -> Akhir 900)
    mock_time_at("10:00")
    r_s1_awal = await client.post(
        "/api/v1/stok/opname",
        headers=headers_k1,
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "titik": "bar",
            "tipe": "awal_shift",
            "items": [{"bahan_id": "b-1", "jumlah": 1000}],
        },
    )
    assert r_s1_awal.status_code == 200

    mock_time_at("15:50")
    r_s1_akhir = await client.post(
        "/api/v1/stok/opname",
        headers=headers_k1,
        json={
            "jadwal_shift_id": "shift-bar-k1",
            "titik": "bar",
            "tipe": "akhir_shift",
            "items": [{"bahan_id": "b-1", "jumlah": 900}],
        },
    )
    assert r_s1_akhir.status_code == 200

    # Opname Shift 2 (Awal 880 -> Akhir 805)
    # Catatan: input awal shift 2 manual via hitung fisik (admin/susulan atau manual)
    mock_time_at("16:10")
    r_s2_awal = await client.post(
        "/api/v1/stok/opname",
        headers=headers_k2,
        json={
            "jadwal_shift_id": "shift-bar-k2",
            "titik": "bar",
            "tipe": "awal_shift",
            "items": [{"bahan_id": "b-1", "jumlah": 880}],
        },
    )
    assert r_s2_awal.status_code == 200
    # Jika carry_forward menyalin 900, uji skenario selisih handover dengan mengubah detail awal S2 ke 880
    from sqlalchemy import select
    from app.models.stok import StokOpnameDetail
    s2_det_res = await test_db.execute(
        select(StokOpnameDetail).where(StokOpnameDetail.stok_opname_id == r_s2_awal.json()["id"])
    )
    s2_det = s2_det_res.scalars().first()
    s2_det.jumlah = Decimal("880")
    await test_db.commit()

    mock_time_at("22:50")
    r_s2_akhir = await client.post(
        "/api/v1/stok/opname",
        headers=headers_k2,
        json={
            "jadwal_shift_id": "shift-bar-k2",
            "titik": "bar",
            "tipe": "akhir_shift",
            "items": [{"bahan_id": "b-1", "jumlah": 805}],
        },
    )
    assert r_s2_akhir.status_code == 200

    # Verifikasi GET /stok/opname/audit
    res_audit = await client.get(
        f"/api/v1/stok/opname/audit?tanggal={today.isoformat()}&titik=bar",
        headers=headers_admin,
    )
    assert res_audit.status_code == 200
    audit = res_audit.json()

    # Harian: Awal 1000, BOM total = 45 + 75 = 120 -> Ekspektasi = 880, Akhir = 805 -> Selisih = -75 (tumpah/susut)
    item_kopi = next(i for i in audit["items"] if i["bahan_id"] == "b-1")
    assert Decimal(str(item_kopi["stok_awal"])) == Decimal("1000")
    assert Decimal(str(item_kopi["pemakaian_bom"])) == Decimal("120")
    assert Decimal(str(item_kopi["ekspektasi_stok"])) == Decimal("880")
    assert Decimal(str(item_kopi["stok_akhir"])) == Decimal("805")
    assert Decimal(str(item_kopi["pemakaian_fisik"])) == Decimal("195")
    assert Decimal(str(item_kopi["selisih_stok_akhir_vs_ekspektasi"])) == Decimal("-75")
    assert item_kopi["status_audit"] == "lebih_boros"
    assert "tumpah" in item_kopi["diagnosa"].lower() or "susut" in item_kopi["diagnosa"].lower()

    # Perbandingan Shift 1 vs Shift 2
    comp = next(c for c in audit["perbandingan_shift"] if c["bahan_id"] == "b-1")
    s1 = comp["shift_1"]
    s2 = comp["shift_2"]
    assert Decimal(str(s1["stok_awal"])) == Decimal("1000")
    assert Decimal(str(s1["pemakaian_bom"])) == Decimal("45")
    assert Decimal(str(s1["ekspektasi_stok"])) == Decimal("955")
    assert Decimal(str(s1["stok_akhir"])) == Decimal("900")
    assert Decimal(str(s1["pemakaian_aktual"])) == Decimal("100")
    assert Decimal(str(s1["selisih_vs_bom"])) == Decimal("-55")
    assert s1["status_audit"] == "lebih_boros"

    assert Decimal(str(s2["stok_awal"])) == Decimal("880")
    assert Decimal(str(s2["pemakaian_bom"])) == Decimal("75")
    assert Decimal(str(s2["ekspektasi_stok"])) == Decimal("805")
    assert Decimal(str(s2["stok_akhir"])) == Decimal("805")
    assert Decimal(str(s2["pemakaian_aktual"])) == Decimal("75")
    assert Decimal(str(s2["selisih_vs_bom"])) == Decimal("0")
    assert s2["status_audit"] == "sesuai"

    assert Decimal(str(comp["selisih_akhir_s1_vs_awal_s2"])) == Decimal("-20")
    assert comp["status_handover"] == "kurang"
    assert Decimal(str(comp["selisih_stok_akhir_s1_vs_s2"])) == Decimal("-95")
    assert Decimal(str(comp["selisih_pemakaian_s1_vs_s2"])) == Decimal("-25")
    assert audit["summary"]["handover_selisih_count"] == 1

    # Endpoint harian juga menyertakan perbandingan_shift & ekspektasi_stok
    res_harian = await client.get(
        f"/api/v1/stok/opname/harian?tanggal={today.isoformat()}&titik=bar",
        headers=headers_admin,
    )
    assert res_harian.status_code == 200
    harian = res_harian.json()
    assert len(harian["perbandingan_shift"]) >= 1
    h_kopi = next(i for i in harian["items"] if i["bahan_id"] == "b-1")
    assert Decimal(str(h_kopi["ekspektasi_stok"])) == Decimal("880")
    assert Decimal(str(h_kopi["selisih_vs_bom"])) == Decimal("-75")


@pytest.mark.asyncio
async def test_req3_tukar_shift_two_stage_target_confirmation(
    client, sample_data, test_db
):
    today = sample_data["today"]
    future = today + timedelta(days=3)
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    headers_k1 = {"Authorization": f"Bearer {sample_data['token_k1']}"}
    headers_k2 = {"Authorization": f"Bearer {sample_data['token_k2']}"}

    s1 = JadwalShift(
        id="sh-swap-a",
        karyawan_id="usr-karyawan1",
        tanggal=future,
        shift="shift_1",
        area_kerja="bar",
        jam_mulai=time(8, 0),
        jam_selesai=time(16, 0),
    )
    s2 = JadwalShift(
        id="sh-swap-b",
        karyawan_id="usr-karyawan2",
        tanggal=future,
        shift="shift_2",
        area_kerja="bar",
        jam_mulai=time(16, 0),
        jam_selesai=time(23, 0),
    )
    test_db.add_all([s1, s2])
    await test_db.commit()

    # 1. K1 ajukan tukar shift ke K2 -> status_target='pending'
    r_req = await client.post(
        "/api/v1/jadwal/tukar-shift",
        headers=headers_k1,
        json={
            "shift_a_id": "sh-swap-a",
            "shift_b_id": "sh-swap-b",
            "karyawan_target_id": "usr-karyawan2",
            "alasan": "Ada urusan pagi",
        },
    )
    assert r_req.status_code == 200
    req1 = r_req.json()
    assert req1["status"] == "pending"
    assert req1["status_target"] == "pending"
    assert req1["nama_pengaju"] == "Karyawan One"
    assert req1["nama_target"] == "Karyawan Two"

    # 2. Admin tidak boleh approve sebelum K2 konfirmasi -> 409
    r_early_admin = await client.put(
        f"/api/v1/jadwal/tukar-shift/{req1['id']}/approval",
        headers=headers_admin,
        json={"status": "disetujui"},
    )
    assert r_early_admin.status_code == 409
    assert "target" in r_early_admin.json()["detail"].lower()

    # 3. Pengaju (K1) tidak boleh mengonfirmasi dirinya sendiri -> 403
    r_wrong_user = await client.put(
        f"/api/v1/jadwal/tukar-shift/{req1['id']}/konfirmasi-target",
        headers=headers_k1,
        json={"status": "disetujui"},
    )
    assert r_wrong_user.status_code == 403

    # 4. Target (K2) menolak -> status_target='ditolak' & status='ditolak'
    r_reject = await client.put(
        f"/api/v1/jadwal/tukar-shift/{req1['id']}/konfirmasi-target",
        headers=headers_k2,
        json={"status": "ditolak"},
    )
    assert r_reject.status_code == 200
    assert r_reject.json()["status_target"] == "ditolak"
    assert r_reject.json()["status"] == "ditolak"

    # 5. Pengajuan ulang: K2 setuju -> lalu Admin setuju -> shift benar-benar tertukar!
    r_req2 = await client.post(
        "/api/v1/jadwal/tukar-shift",
        headers=headers_k1,
        json={
            "shift_a_id": "sh-swap-a",
            "shift_b_id": "sh-swap-b",
            "karyawan_target_id": "usr-karyawan2",
            "alasan": "Sudah koordinasi langsung",
        },
    )
    assert r_req2.status_code == 200
    req2_id = r_req2.json()["id"]

    r_k2_ok = await client.put(
        f"/api/v1/jadwal/tukar-shift/{req2_id}/konfirmasi-target",
        headers=headers_k2,
        json={"status": "disetujui"},
    )
    assert r_k2_ok.status_code == 200
    assert r_k2_ok.json()["status_target"] == "disetujui"
    assert r_k2_ok.json()["status"] == "pending"

    r_adm_ok = await client.put(
        f"/api/v1/jadwal/tukar-shift/{req2_id}/approval",
        headers=headers_admin,
        json={"status": "disetujui"},
    )
    assert r_adm_ok.status_code == 200
    assert r_adm_ok.json()["status"] == "disetujui"

    await test_db.refresh(s1)
    await test_db.refresh(s2)
    assert s1.karyawan_id == "usr-karyawan2"
    assert s2.karyawan_id == "usr-karyawan1"


@pytest.mark.asyncio
async def test_req4_req5_offshift_and_unclocked_in_complete_lockdown(
    client, sample_data, test_db, mock_time_at
):
    """
    Verifikasi penuh penguncian operasional:
    - Karyawan libur (tanpa jadwal hari ini): semua operasional (POS, KDS, stok gudang, titik, opname, rekap) -> 403 & shift-aktif -> 404.
    - Karyawan punya jadwal tapi BELUM absen masuk: semua operasional -> 403.
    - Karyawan sudah absen masuk: fitur sesuai shift -> 200 OK.
    - Karyawan sudah absen pulang: semua operasional -> 403 kembali.
    - Admin selalu dapat mengakses seluruh endpoint operasional -> 200 OK.
    """
    mock_time_at("10:00")
    today = sample_data["today"]

    # Karyawan 3 yang sedang LIBUR (tidak punya jadwal hari ini)
    k_libur = Karyawan(
        id="usr-libur",
        nama="Karyawan Libur",
        email="libur@kyfein.com",
        nomor_hp="08550001",
        role="karyawan",
        divisi="kasir",
        password="hashedpassword",
        status_aktif=True,
    )
    sg = StokGudang(
        id="sg-req5-b1",
        bahan_id="b-1",
        jumlah_kemasan_besar=5,
        jumlah_satuan_kecil=Decimal("5000"),
    )
    test_db.add_all([k_libur, sg])
    await test_db.commit()

    headers_libur = {"Authorization": f"Bearer {create_access_token('usr-libur', 'karyawan')}"}
    headers_k1 = {"Authorization": f"Bearer {sample_data['token_k1']}"}
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}

    # --- A. KARYAWAN LIBUR / OFF-SHIFT ---
    assert (await client.get("/api/v1/jadwal/shift-aktif", headers=headers_libur)).status_code == 404
    assert (
        await client.post(
            "/api/v1/transaksi/",
            headers=headers_libur,
            json={
                "metode_bayar": "cash",
                "uang_diterima": 50000,
                "details": [{"menu_id": "menu-1", "qty": 1}],
            },
        )
    ).status_code == 403
    assert (await client.get("/api/v1/transaksi/", headers=headers_libur)).status_code == 403
    assert (await client.get("/api/v1/kds/orders/bar", headers=headers_libur)).status_code == 403
    assert (await client.get("/api/v1/stok/stok-gudang", headers=headers_libur)).status_code == 403
    assert (await client.get("/api/v1/stok/stok-titik", headers=headers_libur)).status_code == 403
    assert (await client.get("/api/v1/stok/opname/harian", headers=headers_libur)).status_code == 403
    assert (await client.get("/api/v1/stok/opname/audit", headers=headers_libur)).status_code == 403
    assert (
        await client.post(
            "/api/v1/stok/opname",
            headers=headers_libur,
            json={
                "titik": "bar",
                "tipe": "awal_shift",
                "items": [{"bahan_id": "b-1", "jumlah": 100}],
            },
        )
    ).status_code == 403
    assert (
        await client.post(
            "/api/v1/stok/barang-keluar",
            headers=headers_libur,
            json={
                "titik_tujuan": "bar",
                "items": [{"bahan_id": "b-1", "jumlah": 10}],
            },
        )
    ).status_code == 403

    # Jadwal & Request Off tetap bisa diakses saat libur
    assert (await client.get("/api/v1/jadwal/", headers=headers_libur)).status_code == 200
    assert (await client.get("/api/v1/absensi/status", headers=headers_libur)).status_code == 200

    # --- B. KARYAWAN PUNYA SHIFT (K1: shift-bar-k1 08:00-16:00) TAPI BELUM ABSEN MASUK ---
    r_sa_before = await client.get("/api/v1/jadwal/shift-aktif", headers=headers_k1)
    assert r_sa_before.status_code == 200
    assert r_sa_before.json()["sudah_absen_masuk"] is False

    assert (await client.get("/api/v1/stok/opname/harian", headers=headers_k1)).status_code == 403
    assert (await client.get("/api/v1/stok/stok-gudang", headers=headers_k1)).status_code == 403
    assert (await client.get("/api/v1/kds/orders/bar", headers=headers_k1)).status_code == 403
    assert (
        await client.post(
            "/api/v1/stok/opname",
            headers=headers_k1,
            json={
                "jadwal_shift_id": "shift-bar-k1",
                "titik": "bar",
                "tipe": "awal_shift",
                "items": [{"bahan_id": "b-1", "jumlah": 100}],
            },
        )
    ).status_code == 403

    # --- C. K1 MELAKUKAN ABSEN MASUK -> SEMUA FITUR AREA BAR TERBUKA ---
    abs_k1 = Absensi(
        id="abs-req5-k1",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-bar-k1",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1",
    )
    test_db.add(abs_k1)
    await test_db.commit()

    r_sa_after = await client.get("/api/v1/jadwal/shift-aktif", headers=headers_k1)
    assert r_sa_after.status_code == 200
    assert r_sa_after.json()["sudah_absen_masuk"] is True
    assert r_sa_after.json()["sudah_absen_pulang"] is False

    assert (await client.get("/api/v1/stok/opname/harian", headers=headers_k1)).status_code == 200
    assert (await client.get("/api/v1/stok/stok-gudang", headers=headers_k1)).status_code == 200
    assert (await client.get("/api/v1/kds/orders/bar", headers=headers_k1)).status_code == 200
    # Bar staff mencoba buka KDS Kitchen -> 403 (area tidak cocok)
    assert (await client.get("/api/v1/kds/orders/kitchen", headers=headers_k1)).status_code == 403
    # Bar staff mencoba buat transaksi POS -> 403 (area bukan kasir)
    assert (
        await client.post(
            "/api/v1/transaksi/",
            headers=headers_k1,
            json={
                "metode_bayar": "cash",
                "uang_diterima": 50000,
                "details": [{"menu_id": "menu-1", "qty": 1}],
            },
        )
    ).status_code == 403
    assert (
        await client.post(
            "/api/v1/stok/opname",
            headers=headers_k1,
            json={
                "jadwal_shift_id": "shift-bar-k1",
                "titik": "bar",
                "tipe": "awal_shift",
                "items": [{"bahan_id": "b-1", "jumlah": 100}],
            },
        )
    ).status_code == 200

    # --- D. K1 ABSEN PULANG -> TERKUNCI LAGI ---
    abs_k1.jam_pulang = datetime.combine(today, time(16, 0))
    await test_db.commit()
    assert (await client.get("/api/v1/stok/opname/harian", headers=headers_k1)).status_code == 403
    assert (await client.get("/api/v1/kds/orders/bar", headers=headers_k1)).status_code == 403

    # --- E. ADMIN TETAP BEBAS AKSES ---
    assert (await client.get("/api/v1/stok/opname/harian", headers=headers_admin)).status_code == 200
    assert (await client.get("/api/v1/stok/opname/audit", headers=headers_admin)).status_code == 200
    assert (await client.get("/api/v1/kds/orders/all", headers=headers_admin)).status_code == 200


@pytest.mark.asyncio
async def test_stok_gudang_avg_price_and_bom_admin_only(
    client, test_db, sample_data, mock_time_at
):
    """
    Stok Gudang menampilkan AVG harga per satuan, AVG per kemasan, nilai persediaan,
    dan rincian pemakaian + biaya per BOM khusus untuk admin/owner, sementara karyawan
    on-duty tidak menerima data harga/biaya.
    """
    mock_time_at("10:00")
    today = sample_data["today"]
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    headers_k1 = {"Authorization": f"Bearer {sample_data['token_k1']}"}

    # Pastikan stok gudang b-1 (Biji Kopi: isi=1000g, avg=Rp150/g) ada 2 kemasan + 500g = 2500g
    sg = StokGudang(
        id="sg-avg-bom-1",
        bahan_id="b-1",
        jumlah_kemasan_besar=2,
        jumlah_satuan_kecil=Decimal("500"),
    )
    test_db.add(sg)
    # Tambahkan 1 resep BOM menu-1 (Espresso) memakai 18g b-1 -> biaya Rp 2.700 / porsi, est 138 porsi
    test_db.add(
        MenuResep(
            id="resep-sg-bom-1",
            menu_id="menu-1",
            bahan_id="b-1",
            jumlah_terpakai=Decimal("18"),
        )
    )
    # Buat karyawan1 on-duty (shift aktif + absen masuk) agar bisa akses GET /stok-gudang
    test_db.add(
        JadwalShift(
            id="shift-sg-k1",
            karyawan_id="usr-karyawan1",
            tanggal=today,
            shift="shift_1",
            jam_mulai=time(8, 0),
            jam_selesai=time(16, 0),
            area_kerja="bar",
        )
    )
    test_db.add(
        Absensi(
            id="abs-sg-k1",
            karyawan_id="usr-karyawan1",
            jadwal_shift_id="shift-sg-k1",
            lat_masuk=Decimal("-6.20000000"),
            lng_masuk=Decimal("106.80000000"),
            foto_masuk_id="foto-k1",
        )
    )
    await test_db.commit()

    # 1. Admin mendapatkan AVG harga, AVG/kemasan, nilai persediaan, dan daftar BOM
    r_admin = await client.get("/api/v1/stok/stok-gudang", headers=headers_admin)
    assert r_admin.status_code == 200
    rows_admin = r_admin.json()
    b1_row = next(r for r in rows_admin if r["bahan_id"] == "b-1")
    assert Decimal(str(b1_row["harga_rata_rata"])) == Decimal("150.00")
    assert Decimal(str(b1_row["harga_rata_rata_per_kemasan"])) == Decimal("150000.00")
    assert Decimal(str(b1_row["nilai_persediaan"])) == Decimal("375000.00")
    assert len(b1_row["bom_pemakaian"]) >= 1
    bom_m1 = next(b for b in b1_row["bom_pemakaian"] if b["menu_id"] == "menu-1")
    assert Decimal(str(bom_m1["jumlah_terpakai"])) == Decimal("18")
    assert Decimal(str(bom_m1["biaya_per_porsi"])) == Decimal("2700.00")
    assert bom_m1["estimasi_porsi"] == 138

    # 2. PUT /stok-gudang/{bahan_id} oleh Admin tetap mengembalikan AVG & BOM terbaru
    r_upd = await client.put(
        "/api/v1/stok/stok-gudang/b-1",
        headers=headers_admin,
        json={"jumlah_kemasan_besar": 3, "jumlah_satuan_kecil": 0},
    )
    assert r_upd.status_code == 200
    upd_json = r_upd.json()
    assert Decimal(str(upd_json["harga_rata_rata"])) == Decimal("150.00")
    assert Decimal(str(upd_json["nilai_persediaan"])) == Decimal("450000.00")
    bom_m1_upd = next(b for b in upd_json["bom_pemakaian"] if b["menu_id"] == "menu-1")
    assert bom_m1_upd["estimasi_porsi"] == 166  # 3000 // 18

    # 3. Karyawan on-duty tetap mendapat stok gudang TANPA field harga/biaya/BOM
    r_k1 = await client.get("/api/v1/stok/stok-gudang", headers=headers_k1)
    assert r_k1.status_code == 200
    b1_k1 = next(r for r in r_k1.json() if r["bahan_id"] == "b-1")
    assert "harga_rata_rata" not in b1_k1
    assert "nilai_persediaan" not in b1_k1
    assert "bom_pemakaian" not in b1_k1
    assert "harga_rata_rata" not in (b1_k1.get("bahan") or {})


@pytest.mark.asyncio
async def test_laporan_absensi_per_karyawan_metrics_and_logs(
    client, test_db, sample_data, mock_time_at
):
    """
    Laporan Absensi (/reporting/profit-periode) mengembalikan rekap per karyawan:
    total menit telat, rata-rata menit telat, jumlah telat, alpha (tidak hadir),
    izin tidak masuk, lupa absen pulang, serta riwayat shift per tanggal.
    """
    mock_time_at("18:00")
    today = sample_data["today"] - timedelta(days=4)
    yesterday = today - timedelta(days=1)
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}

    # Karyawan 1: kemarin telat 25 menit + lupa absen pulang; hari ini telat 15 menit + pulang tepat waktu
    js_k1_d1 = JadwalShift(
        id="js-lap-k1-d1",
        karyawan_id="usr-karyawan1",
        tanggal=yesterday,
        shift="shift_1",
        jam_mulai=time(8, 0),
        jam_selesai=time(16, 0),
        area_kerja="bar",
    )
    js_k1_d2 = JadwalShift(
        id="js-lap-k1-d2",
        karyawan_id="usr-karyawan1",
        tanggal=today,
        shift="shift_1",
        jam_mulai=time(8, 0),
        jam_selesai=time(16, 0),
        area_kerja="bar",
    )
    # Karyawan 2: kemarin alpha (tidak hadir tanpa keterangan); hari ini tepat waktu
    js_k2_d1 = JadwalShift(
        id="js-lap-k2-d1",
        karyawan_id="usr-karyawan2",
        tanggal=yesterday,
        shift="shift_1",
        jam_mulai=time(8, 0),
        jam_selesai=time(16, 0),
        area_kerja="kasir",
    )
    js_k2_d2 = JadwalShift(
        id="js-lap-k2-d2",
        karyawan_id="usr-karyawan2",
        tanggal=today,
        shift="shift_1",
        jam_mulai=time(8, 0),
        jam_selesai=time(16, 0),
        area_kerja="kasir",
    )
    test_db.add_all([js_k1_d1, js_k1_d2, js_k2_d1, js_k2_d2])
    await test_db.flush()

    test_db.add_all([
        Absensi(
            id="abs-lap-k1-d1",
            karyawan_id="usr-karyawan1",
            jadwal_shift_id=js_k1_d1.id,
            jam_masuk=datetime.combine(yesterday, time(8, 25)),
            jam_pulang=None,
            lat_masuk=Decimal("-6.20000000"),
            lng_masuk=Decimal("106.80000000"),
            foto_masuk_id="foto-k1",
            menit_telat=25,
            status_pulang="lupa_absen",
        ),
        Absensi(
            id="abs-lap-k1-d2",
            karyawan_id="usr-karyawan1",
            jadwal_shift_id=js_k1_d2.id,
            jam_masuk=datetime.combine(today, time(8, 15)),
            jam_pulang=datetime.combine(today, time(16, 5)),
            lat_masuk=Decimal("-6.20000000"),
            lng_masuk=Decimal("106.80000000"),
            foto_masuk_id="foto-k1",
            menit_telat=15,
            status_pulang="tepat_waktu",
        ),
        Absensi(
            id="abs-lap-k2-d2",
            karyawan_id="usr-karyawan2",
            jadwal_shift_id=js_k2_d2.id,
            jam_masuk=datetime.combine(today, time(7, 58)),
            jam_pulang=datetime.combine(today, time(16, 0)),
            lat_masuk=Decimal("-6.20000000"),
            lng_masuk=Decimal("106.80000000"),
            foto_masuk_id="foto-k1",
            menit_telat=0,
            status_pulang="tepat_waktu",
        ),
    ])
    await test_db.commit()

    r = await client.get(
        "/api/v1/reporting/profit-periode",
        headers=headers_admin,
        params={
            "filter": "range",
            "tanggal_mulai": yesterday.isoformat(),
            "tanggal_selesai": today.isoformat(),
        },
    )
    assert r.status_code == 200
    body = r.json()
    assert body["total_shift_terjadwal"] == 4
    assert body["total_hadir"] == 3
    assert body["total_terlambat"] == 2
    assert body["total_menit_telat"] == 40
    assert body["total_tanpa_keterangan"] == 1
    assert body["total_lupa_absen_pulang"] == 1

    per_emp = {e["karyawan_id"]: e for e in body["absensi_per_karyawan"]}
    k1 = per_emp["usr-karyawan1"]
    assert k1["telat_count"] == 2
    assert k1["total_menit_telat"] == 40
    assert k1["rata_menit_telat"] == 20.0
    assert k1["lupa_absen_pulang_count"] == 1
    assert k1["tanpa_keterangan_count"] == 0
    assert len(k1["riwayat_shift"]) == 2

    k2 = per_emp["usr-karyawan2"]
    assert k2["total_hadir"] == 1
    assert k2["tepat_waktu_count"] == 1
    assert k2["tanpa_keterangan_count"] == 1
    assert k2["total_menit_telat"] == 0
    assert any(log["status_kehadiran"] == "alpha" for log in k2["riwayat_shift"])
