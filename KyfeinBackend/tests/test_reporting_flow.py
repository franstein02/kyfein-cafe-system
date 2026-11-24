import pytest
from decimal import Decimal
import calendar

from app.core.utils import now_local
from app.models import Menu, KategoriMenu, Absensi, Transaksi, TransaksiDetail


@pytest.mark.asyncio
async def test_reporting_3_6_end_to_end(client, sample_data, test_db, mock_time_at):
    """
    End-to-end verification for Section 3.6 Reporting & Pengeluaran:
    - Master Kategori Pengeluaran (GET, POST, 409 duplicate, PUT status_aktif)
    - Pengeluaran CRUD (POST bulanan & mendadak, GET, PUT, DELETE)
    - Profit Harian & Profit Periode (harian, range, bulanan, tahunan)
    - Breakdown Pengeluaran per Kategori (harian, range, bulanan, tahunan)
    - Menu Tanpa Resep warning list
    - Laporan Shift Aktif (auto-resolve shift when jadwal_shift_id omitted)
    - Reminder Stok Menipis (/master/bahan/stok-menipis)
    """
    mock_time_at("10:00")
    today = sample_data["today"]
    days_in_month = calendar.monthrange(today.year, today.month)[1]
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    headers_k1 = {"Authorization": f"Bearer {sample_data['token_k1']}"}

    # 1. Master Kategori Pengeluaran
    res_kat_create = await client.post(
        "/api/v1/master/kategori-pengeluaran",
        headers=headers_admin,
        json={"nama": "Maintenance Mesin", "status_aktif": True},
    )
    assert res_kat_create.status_code == 200
    kat_maint = res_kat_create.json()
    assert kat_maint["nama"] == "Maintenance Mesin"
    assert kat_maint["status_aktif"] is True

    # Duplicate category name should return 409
    res_kat_dup = await client.post(
        "/api/v1/master/kategori-pengeluaran",
        headers=headers_admin,
        json={"nama": "maintenance mesin", "status_aktif": True},
    )
    assert res_kat_dup.status_code == 409

    # Update category name and toggle status_aktif
    res_kat_update = await client.put(
        f"/api/v1/master/kategori-pengeluaran/{kat_maint['id']}",
        headers=headers_admin,
        json={"nama": "Maintenance Espresso", "status_aktif": True},
    )
    assert res_kat_update.status_code == 200
    assert res_kat_update.json()["nama"] == "Maintenance Espresso"

    # 2. Input Pengeluaran (Bulanan & Mendadak)
    # Invalid kategori_id -> 400
    res_invalid_kat = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "mendadak",
            "kategori_id": "kat-tidak-ada",
            "nominal": 10000,
            "tanggal": today.isoformat(),
        },
    )
    assert res_invalid_kat.status_code == 400

    # Bulanan: Rp 300.000 * days_in_month so daily pro-rata is exactly 300000?
    # Let's use nominal = 30000 * days_in_month so daily pro-rata = 30000
    bulanan_nominal = 30000 * days_in_month
    res_p_bulanan = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "bulanan",
            "kategori_id": "katp-1",
            "nominal": bulanan_nominal,
            "bulan": f"{today.year}-{today.month:02d}",
            "keterangan": "Tagihan Listrik Bulanan",
        },
    )
    assert res_p_bulanan.status_code == 200
    p_bulanan = res_p_bulanan.json()
    assert p_bulanan["nama_kategori"] == "Operasional"

    # Mendadak: Rp 15.000 today
    res_p_mendadak = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "mendadak",
            "kategori_id": kat_maint["id"],
            "nominal": 15000,
            "tanggal": today.isoformat(),
            "keterangan": "Beli seal karet gruphead",
        },
    )
    assert res_p_mendadak.status_code == 200
    p_mendadak = res_p_mendadak.json()
    assert p_mendadak["nama_kategori"] == "Maintenance Espresso"

    # Update mendadak nominal from 15000 -> 10000
    res_p_upd = await client.put(
        f"/api/v1/reporting/pengeluaran/{p_mendadak['id']}",
        headers=headers_admin,
        json={"nominal": 10000, "keterangan": "Beli seal karet (diskon)"},
    )
    assert res_p_upd.status_code == 200
    assert Decimal(res_p_upd.json()["nominal"]) == Decimal("10000.00")

    # 3. Create a selesai transaction and a menu without recipe to verify Profit & HPP Snapshot
    menu_no_recipe = Menu(
        id="m-tanpa-resep",
        nama="Air Mineral Botol",
        kode_menu="WTR-REP-1",
        kategori_id="kat-1",
        harga=Decimal("5000.00"),
        status_aktif=True,
    )
    trx = Transaksi(
        id="trx-rep-1",
        nomor_transaksi="INV-REP-001",
        jadwal_shift_id="shift-kasir-k1",
        kasir_id="usr-karyawan1",
        metode_bayar="cash",
        status="selesai",
        total_harga=Decimal("45000.00"),
        waktu_transaksi=now_local(),
    )
    item1 = TransaksiDetail(
        id="ti-rep-1",
        transaksi_id="trx-rep-1",
        menu_id="menu-1",
        qty=2,
        harga_satuan=Decimal("20000.00"),
        hpp_satuan=Decimal("5000.00"),  # Snapshot HPP = 2 * 5000 = 10000
        subtotal=Decimal("40000.00"),
        status_item="selesai",
    )
    item2 = TransaksiDetail(
        id="ti-rep-2",
        transaksi_id="trx-rep-1",
        menu_id="m-tanpa-resep",
        qty=1,
        harga_satuan=Decimal("5000.00"),
        hpp_satuan=Decimal("0.00"),
        subtotal=Decimal("5000.00"),
        status_item="selesai",
    )
    test_db.add_all([menu_no_recipe, trx, item1, item2])
    await test_db.commit()

    # 4. Verify Profit Harian
    res_profit_harian = await client.get(
        f"/api/v1/reporting/profit-harian?tanggal={today.isoformat()}",
        headers=headers_admin,
    )
    assert res_profit_harian.status_code == 200
    ph = res_profit_harian.json()
    assert ph["jumlah_transaksi"] == 1
    assert Decimal(ph["total_penjualan"]) == Decimal("45000.00")
    assert Decimal(ph["total_hpp_teoritis"]) == Decimal("10000.00")
    assert Decimal(ph["pengeluaran_bulanan_pro_rata"]) == Decimal("30000.00")
    assert Decimal(ph["pengeluaran_mendadak"]) == Decimal("10000.00")
    # Net Profit = 45000 - 10000 - 30000 - 10000 = -5000
    assert Decimal(ph["net_profit_harian"]) == Decimal("-5000.00")
    assert "Air Mineral Botol" in ph["menu_tanpa_resep"]

    # 5. Verify Profit Periode (harian, range, bulanan, tahunan)
    for flt, extra_q in [
        ("harian", f"&tanggal={today.isoformat()}"),
        ("range", f"&tanggal_mulai={today.isoformat()}&tanggal_selesai={today.isoformat()}"),
        ("bulanan", f"&bulan={today.year}-{today.month:02d}"),
        ("tahunan", f"&tahun={today.year}"),
    ]:
        res_pp = await client.get(
            f"/api/v1/reporting/profit-periode?filter={flt}{extra_q}",
            headers=headers_admin,
        )
        assert res_pp.status_code == 200
        pp_data = res_pp.json()
        assert pp_data["filter"] == flt
        assert pp_data["jumlah_transaksi"] >= 1
        assert "Air Mineral Botol" in pp_data["menu_tanpa_resep"]

    # 6. Verify Breakdown Pengeluaran per Kategori
    res_bd = await client.get(
        f"/api/v1/reporting/pengeluaran/breakdown?filter=harian&tanggal={today.isoformat()}",
        headers=headers_admin,
    )
    assert res_bd.status_code == 200
    bd = res_bd.json()
    assert Decimal(bd["total_pengeluaran"]) == Decimal("40000.00")
    assert len(bd["items"]) == 2
    assert bd["items"][0]["nama_kategori"] == "Operasional"
    assert Decimal(bd["items"][0]["total_nominal"]) == Decimal("30000.00")
    assert Decimal(bd["items"][0]["persentase"]) == Decimal("75.00")

    # 7. Verify Laporan Shift Aktif (with and without jadwal_shift_id query param)
    mock_time_at("20:00")  # shift-kasir-k1 runs 16:00 - 23:59
    res_shift_rep = await client.get(
        "/api/v1/transaksi/shift-aktif/laporan",
        headers=headers_k1,
    )
    assert res_shift_rep.status_code == 200
    sr = res_shift_rep.json()
    assert sr["total_transaksi"] == 1
    assert Decimal(sr["total_penjualan"]) == Decimal("45000.00")

    # 8. Verify Reminder Stok Menipis
    res_stok_menipis = await client.get(
        "/api/v1/master/bahan/stok-menipis",
        headers=headers_admin,
    )
    assert res_stok_menipis.status_code == 200
    assert isinstance(res_stok_menipis.json(), list)

    # 9. Delete Pengeluaran Mendadak
    res_del = await client.delete(
        f"/api/v1/reporting/pengeluaran/{p_mendadak['id']}",
        headers=headers_admin,
    )
    assert res_del.status_code == 200


@pytest.mark.asyncio
async def test_business_processes_27_to_30_and_35_to_38(client, sample_data, test_db, mock_time_at):
    """
    Verifies business processes 27-30 and 35-38:
    27. Kasir saves transaction -> items routed to KDS by category & area_produksi.
    28. Kitchen staff views new order on KDS with status 'menunggu'.
    29. Kitchen staff updates status to 'diproses'.
    30. Kitchen staff updates status to 'selesai'.
    35. Admin manages expense categories (kategori_pengeluaran).
    36. Admin records expenses (bulanan & mendadak).
    37. Admin inspects transaction data and monitors KDS order status.
    38. Admin views sales, HPP, profit, expenses, transactions, stock, and attendance reports by day, range, month, or year.
    """
    mock_time_at("20:00")
    today = sample_data["today"]
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    headers_k1 = {"Authorization": f"Bearer {sample_data['token_k1']}"}

    # Setup Kitchen Category & Menu + Absensi for Kasir
    kat_kitchen = KategoriMenu(
        id="kat-kitchen-1",
        nama="Makanan Berat",
        area_produksi="kitchen",
        status_aktif=True,
    )
    menu_kitchen = Menu(
        id="menu-kitchen-1",
        nama="Nasi Goreng Spesial",
        kode_menu="NASGOR-01",
        kategori_id="kat-kitchen-1",
        harga=Decimal("25000.00"),
        status_aktif=True,
    )
    absen_k1 = Absensi(
        id="abs-kds-k1",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-kasir-k1",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1",
    )
    test_db.add_all([kat_kitchen, menu_kitchen, absen_k1])
    await test_db.commit()

    # 27. Kasir saves transaction with a kitchen item and a bar item
    res_trx = await client.post(
        "/api/v1/transaksi/",
        headers=headers_k1,
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "cash",
            "uang_diterima": 100000,
            "details": [
                {"menu_id": "menu-kitchen-1", "qty": 2, "catatan": "Pedas sedang"},
                {"menu_id": "menu-1", "qty": 1, "catatan": "Less ice"},
            ],
        },
    )
    assert res_trx.status_code == 200
    trx_data = res_trx.json()

    # 28. Kitchen staff views new order on KDS Kitchen with status 'menunggu'
    res_kds_kitchen = await client.get("/api/v1/kds/orders/kitchen", headers=headers_k1)
    assert res_kds_kitchen.status_code == 200
    kitchen_orders = res_kds_kitchen.json()
    assert len(kitchen_orders) == 1
    k_order = kitchen_orders[0]
    assert k_order["kode_menu"] == "NASGOR-01"
    assert k_order["nama_menu"] == "Nasi Goreng Spesial"
    assert k_order["qty"] == 2
    assert k_order["status_item"] == "menunggu"
    detail_id = k_order["id"]

    # 29. Kitchen staff changes status to 'diproses'
    res_diproses = await client.put(
        f"/api/v1/kds/orders/detail/{detail_id}/status",
        headers=headers_k1,
        json={"status_item": "diproses"},
    )
    assert res_diproses.status_code == 200
    assert res_diproses.json()["status_item"] == "diproses"

    # 30. Kitchen staff changes status to 'selesai'
    res_selesai = await client.put(
        f"/api/v1/kds/orders/detail/{detail_id}/status?status_item=selesai",
        headers=headers_k1,
    )
    assert res_selesai.status_code == 200
    assert res_selesai.json()["status_item"] == "selesai"

    # 35. Admin manages expense categories
    res_cat = await client.post(
        "/api/v1/master/kategori-pengeluaran",
        headers=headers_admin,
        json={"nama": "Gas & Dapur", "status_aktif": True},
    )
    assert res_cat.status_code == 200
    cat_id = res_cat.json()["id"]

    # 36. Admin records bulanan & mendadak expenses
    res_exp_b = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "bulanan",
            "kategori_id": cat_id,
            "nominal": 300000,
            "bulan": f"{today.year}-{today.month:02d}",
            "keterangan": "Langganan Gas Bulanan",
        },
    )
    assert res_exp_b.status_code == 200

    res_exp_m = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "mendadak",
            "kategori_id": cat_id,
            "nominal": 20000,
            "tanggal": today.isoformat(),
            "keterangan": "Beli korek gas dapur",
        },
    )
    assert res_exp_m.status_code == 200

    # 37. Admin inspects transaction data and monitors KDS order status
    res_admin_trx = await client.get(
        f"/api/v1/transaksi?tanggal={today.isoformat()}",
        headers=headers_admin,
    )
    assert res_admin_trx.status_code == 200
    trx_list = res_admin_trx.json()
    assert len(trx_list) >= 1
    found_trx = next(t for t in trx_list if t["id"] == trx_data["id"])
    kitchen_detail = next(d for d in found_trx["details"] if d["id"] == detail_id)
    assert kitchen_detail["status_item"] == "selesai"

    res_admin_kds = await client.get(
        "/api/v1/kds/orders/all?include_selesai=true",
        headers=headers_admin,
    )
    assert res_admin_kds.status_code == 200
    assert any(o["id"] == detail_id and o["status_item"] == "selesai" for o in res_admin_kds.json())

    # 38. Admin views sales, HPP, profit, expenses, transactions, stock, and attendance reports
    # across harian, range, bulanan, and tahunan filters
    for flt, q in [
        ("harian", f"tanggal={today.isoformat()}"),
        ("range", f"tanggal_mulai={today.isoformat()}&tanggal_selesai={today.isoformat()}"),
        ("bulanan", f"bulan={today.year}-{today.month:02d}"),
        ("tahunan", f"tahun={today.year}"),
    ]:
        res_rep = await client.get(
            f"/api/v1/reporting/profit-periode?filter={flt}&{q}",
            headers=headers_admin,
        )
        assert res_rep.status_code == 200
        rep = res_rep.json()
        assert Decimal(rep["total_penjualan"]) == Decimal("70000.00")
        assert rep["jumlah_transaksi"] == 1
        assert Decimal(rep["total_cash"]) == Decimal("70000.00")
        assert rep["total_hadir"] >= 1
        assert "jumlah_barang_masuk" in rep
        assert "jumlah_stok_menipis" in rep


@pytest.mark.asyncio
async def test_stok_minimum_kemasan_besar_calculation(client, sample_data, test_db):
    """
    Memastikan bahan.stok_minimum dihitung dalam satuan kemasan besar
    (batas satuan kecil = stok_minimum * isi_per_kemasan).
    Contoh: UHT isi 1000 ml per pcs/kemasan, stok_minimum = 50 -> ambang 50.000 ml.
    """
    from app.models.master_data import Bahan
    from app.models.stok import StokGudang

    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    uht = Bahan(
        id="b-uht-test",
        nama="UHT Test",
        satuan="ml",
        isi_per_kemasan=Decimal("1000"),
        stok_minimum=Decimal("50"),
        harga_rata_rata=Decimal("0"),
    )
    sg = StokGudang(
        id="sg-uht-test",
        bahan_id="b-uht-test",
        jumlah_kemasan_besar=40,
        jumlah_satuan_kecil=Decimal("500"),
    )
    test_db.add_all([uht, sg])
    await test_db.commit()

    # 40 * 1000 + 500 = 40.500 ml <= 50 * 1000 ml -> masuk daftar stok menipis
    res_low = await client.get("/api/v1/master/bahan/stok-menipis", headers=headers_admin)
    assert res_low.status_code == 200
    low_ids = {item["id"]: Decimal(str(item["total_stok"])) for item in res_low.json()}
    assert "b-uht-test" in low_ids
    assert low_ids["b-uht-test"] == Decimal("40500")

    # Tambah menjadi 51 kemasan = 51.500 ml > 50.000 ml -> tidak menipis
    sg.jumlah_kemasan_besar = 51
    await test_db.commit()

    res_ok = await client.get("/api/v1/master/bahan/stok-menipis", headers=headers_admin)
    assert res_ok.status_code == 200
    ok_ids = {item["id"] for item in res_ok.json()}
    assert "b-uht-test" not in ok_ids


@pytest.mark.asyncio
async def test_hpp_menu_report_and_bar_kitchen_area_isolation(client, sample_data, test_db):
    """
    Memastikan:
    1. Bahan baru dengan area='bar' hanya membuat stok_titik 'bar' dan area='kitchen' hanya 'kitchen'.
    2. GET /master/bahan?titik=... dan GET /stok/stok-titik?titik=... terisolasi sesuai area.
    3. GET /reporting/hpp-menu menampilkan HPP live dari bahan.harga_rata_rata (AVG),
       harga jual, laba kotor, margin%, serta merespon fluktuasi harga saat ada BarangMasuk lebih murah/mahal.
    """
    from app.models.master_data import Menu, MenuResep

    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}

    # 1. Buat bahan khusus Bar & khusus Kitchen via endpoint POST /master/bahan
    res_bar = await client.post(
        "/api/v1/master/bahan",
        headers=headers_admin,
        json={
            "nama": "Susu Bar Only",
            "satuan": "ml",
            "area": "bar",
            "isi_per_kemasan": 1000,
            "stok_minimum": 5,
            "harga_rata_rata": 0,
        },
    )
    assert res_bar.status_code == 200
    bar_id = res_bar.json()["id"]
    assert res_bar.json()["area"] == "bar"

    res_kit = await client.post(
        "/api/v1/master/bahan",
        headers=headers_admin,
        json={
            "nama": "Beras Kitchen Only",
            "satuan": "gram",
            "area": "kitchen",
            "isi_per_kemasan": 5000,
            "stok_minimum": 2,
            "harga_rata_rata": 0,
        },
    )
    assert res_kit.status_code == 200
    kit_id = res_kit.json()["id"]
    assert res_kit.json()["area"] == "kitchen"

    # Cek isolasi stok_titik
    res_st_bar = await client.get("/api/v1/stok/stok-titik?titik=bar", headers=headers_admin)
    assert res_st_bar.status_code == 200
    st_bar_ids = {x["bahan_id"] for x in res_st_bar.json()}
    assert bar_id in st_bar_ids
    assert kit_id not in st_bar_ids

    res_st_kit = await client.get("/api/v1/stok/stok-titik?titik=kitchen", headers=headers_admin)
    assert res_st_kit.status_code == 200
    st_kit_ids = {x["bahan_id"] for x in res_st_kit.json()}
    assert kit_id in st_kit_ids
    assert bar_id not in st_kit_ids

    # 2. Barang masuk batch 1: 1 kemasan Susu (1000 ml) Rp 20.000 -> AVG = Rp 20/ml
    bm1 = await client.post(
        "/api/v1/stok/barang-masuk",
        headers=headers_admin,
        json={
            "catatan": "Batch 1",
            "items": [
                {
                    "bahan_id": bar_id,
                    "jumlah_kemasan_besar": 1,
                    "jumlah_satuan_kecil": 0,
                    "harga_total": 20000,
                }
            ],
        },
    )
    assert bm1.status_code == 200

    # Menu test: Latte Test harga Rp 12.000 pakai 150 ml Susu -> HPP = Rp 3.000, Laba = Rp 9.000, Margin = 75%
    m_latte = Menu(
        id="menu-hpp-test",
        nama="Latte HPP Test",
        kode_menu="TST01",
        harga=Decimal("12000.00"),
        kategori_id="kat-1",
        status_aktif=True,
    )
    test_db.add(m_latte)
    await test_db.flush()
    test_db.add(
        MenuResep(
            id="resep-hpp-test",
            menu_id="menu-hpp-test",
            bahan_id=bar_id,
            jumlah_terpakai=Decimal("150.000"),
        )
    )
    await test_db.commit()

    rep1 = await client.get("/api/v1/reporting/hpp-menu?area=bar", headers=headers_admin)
    assert rep1.status_code == 200
    data1 = rep1.json()
    item1 = next(x for x in data1["items"] if x["menu_id"] == "menu-hpp-test")
    assert Decimal(str(item1["harga_jual"])) == Decimal("12000.00")
    assert Decimal(str(item1["hpp_saat_ini"])) == Decimal("3000.00")
    assert Decimal(str(item1["laba_kotor"])) == Decimal("9000.00")
    assert Decimal(str(item1["margin_persen"])) == Decimal("75.00")

    # 3. Barang masuk batch 2 lebih mahal: 1 kemasan (1000 ml) Rp 30.000 -> AVG jadi (20k+30k)/2000 = Rp 25/ml
    # HPP Latte otomatis naik dari Rp 3.000 -> 150 * 25 = Rp 3.750, laba Rp 8.250, selisih_terakhir_vs_avg = 30 - 25 = +5
    bm2 = await client.post(
        "/api/v1/stok/barang-masuk",
        headers=headers_admin,
        json={
            "catatan": "Batch 2 lebih mahal",
            "items": [
                {
                    "bahan_id": bar_id,
                    "jumlah_kemasan_besar": 1,
                    "jumlah_satuan_kecil": 0,
                    "harga_total": 30000,
                }
            ],
        },
    )
    assert bm2.status_code == 200

    rep2 = await client.get("/api/v1/reporting/hpp-menu", headers=headers_admin)
    assert rep2.status_code == 200
    data2 = rep2.json()
    item2 = next(x for x in data2["items"] if x["menu_id"] == "menu-hpp-test")
    assert Decimal(str(item2["hpp_saat_ini"])) == Decimal("3750.00")
    assert Decimal(str(item2["laba_kotor"])) == Decimal("8250.00")

    mon = next(x for x in data2["bahan_monitor"] if x["bahan_id"] == bar_id)
    assert Decimal(str(mon["harga_rata_rata"])) == Decimal("25.00")
    assert Decimal(str(mon["harga_beli_terakhir"])) == Decimal("30.00")
    assert Decimal(str(mon["selisih_terakhir_vs_avg"])) == Decimal("5.00")


@pytest.mark.asyncio
async def test_menu_foto_url_resolution(client, sample_data):
    """Pastikan menu dengan foto URL eksternal (Supabase) memunculkan foto_url dan tetap menjaga foto_id."""
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    headers_k1 = {"Authorization": f"Bearer {sample_data['token_k1']}"}
    supa_url = "https://psdeyhujegvaczqyozbz.supabase.co/storage/v1/object/public/Storage/menu/test_photo.jpg"

    create_res = await client.post(
        "/api/v1/master/menu",
        headers=headers_admin,
        json={
            "nama": "Test Menu Foto",
            "kode_menu": "TSTF01",
            "harga": 15000,
            "kategori_id": "kat-1",
            "foto_id": supa_url,
            "status_aktif": True,
            "resep": [],
        },
    )
    assert create_res.status_code == 200
    created = create_res.json()
    assert created["foto_id"] is not None
    assert created["foto_id"] != supa_url  # Stored as Foto UUID
    assert created["foto_url"] == supa_url

    list_res = await client.get("/api/v1/master/menu", headers=headers_k1)
    assert list_res.status_code == 200
    found = next(m for m in list_res.json() if m["id"] == created["id"])
    assert found["foto_id"] == created["foto_id"]
    assert found["foto_url"] == supa_url

    # Preserving foto_id without changing photo should keep the same foto_id and foto_url
    upd_res = await client.put(
        f"/api/v1/master/menu/{created['id']}",
        headers=headers_admin,
        json={"harga": 16000, "foto_id": created["foto_id"]},
    )
    assert upd_res.status_code == 200
    assert upd_res.json()["foto_id"] == created["foto_id"]
    assert upd_res.json()["foto_url"] == supa_url


@pytest.mark.asyncio
async def test_pengeluaran_bulanan_pro_rata_harian_field(client, sample_data):
    """Pastikan pengeluaran bulanan (mis. Listrik 300k & Air 150k Nov = 30 hari) menghitung pro_rata_harian = 10k & 5k serta masuk laba rugi harian."""
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}

    kat_listrik = (
        await client.post(
            "/api/v1/master/kategori-pengeluaran",
            headers=headers_admin,
            json={"nama": "Listrik Cafe", "status_aktif": True},
        )
    ).json()
    kat_air = (
        await client.post(
            "/api/v1/master/kategori-pengeluaran",
            headers=headers_admin,
            json={"nama": "Air Cafe", "status_aktif": True},
        )
    ).json()

    p_listrik = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "kategori_id": kat_listrik["id"],
            "tipe": "bulanan",
            "nominal": 300000,
            "bulan": "2026-11",
            "keterangan": "Listrik November",
        },
    )
    assert p_listrik.status_code == 200
    assert Decimal(str(p_listrik.json()["pro_rata_harian"])) == Decimal("10000.00")
    assert p_listrik.json()["jumlah_hari_bulan"] == 30

    p_air = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "kategori_id": kat_air["id"],
            "tipe": "bulanan",
            "nominal": 150000,
            "bulan": "2026-11",
            "keterangan": "Air November",
        },
    )
    assert p_air.status_code == 200
    assert Decimal(str(p_air.json()["pro_rata_harian"])) == Decimal("5000.00")
    assert p_air.json()["jumlah_hari_bulan"] == 30

    profit_harian = await client.get(
        "/api/v1/reporting/profit-harian?tanggal=2026-11-18",
        headers=headers_admin,
    )
    assert profit_harian.status_code == 200
    ph = profit_harian.json()
    assert Decimal(str(ph["pengeluaran_bulanan_pro_rata"])) == Decimal("15000.00")
    assert Decimal(str(ph["net_profit_harian"])) == Decimal("-15000.00")

    breakdown = await client.get(
        "/api/v1/reporting/pengeluaran/breakdown?filter=harian&tanggal=2026-11-18",
        headers=headers_admin,
    )
    assert breakdown.status_code == 200
    bd = breakdown.json()
    assert Decimal(str(bd["total_pengeluaran"])) == Decimal("15000.00")
    by_name = {x["nama_kategori"]: Decimal(str(x["total_nominal"])) for x in bd["items"]}
    assert by_name["Listrik Cafe"] == Decimal("10000.00")
    assert by_name["Air Cafe"] == Decimal("5000.00")


@pytest.mark.asyncio
async def test_barang_masuk_rekap_harga_endpoint(client, sample_data):
    """Pastikan GET /stok/barang-masuk & profit-periode mencatat rekap harga barang masuk serta selisih AVG."""
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    headers_k1 = {"Authorization": f"Bearer {sample_data['token_k1']}"}
    today = sample_data["today"]

    b1 = (
        await client.post(
            "/api/v1/master/bahan",
            headers=headers_admin,
            json={
                "nama": "Susu Segar Bar",
                "satuan": "ml",
                "area": "bar",
                "isi_per_kemasan": 1000,
                "stok_minimum": 5,
            },
        )
    ).json()
    b2 = (
        await client.post(
            "/api/v1/master/bahan",
            headers=headers_admin,
            json={
                "nama": "Minyak Dapur Kit",
                "satuan": "ml",
                "area": "kitchen",
                "isi_per_kemasan": 2000,
                "stok_minimum": 2,
            },
        )
    ).json()

    # Non-admin ditolak (menjaga kerahasiaan harga beli supplier)
    forbidden = await client.get("/api/v1/stok/barang-masuk", headers=headers_k1)
    assert forbidden.status_code == 403

    bm1 = await client.post(
        "/api/v1/stok/barang-masuk",
        headers=headers_admin,
        json={
            "catatan": "Nota Supplier A",
            "items": [
                {
                    "bahan_id": b1["id"],
                    "jumlah_kemasan_besar": 2,
                    "jumlah_satuan_kecil": 0,
                    "harga_total": 40000,
                },
                {
                    "bahan_id": b2["id"],
                    "jumlah_kemasan_besar": 1,
                    "jumlah_satuan_kecil": 0,
                    "harga_total": 36000,
                },
            ],
        },
    )
    assert bm1.status_code == 200

    # Restock kedua lebih mahal utk b1 -> 25.000/kemasan (25/ml vs avg 22.50/ml -> selisih +2.50)
    bm2 = await client.post(
        "/api/v1/stok/barang-masuk",
        headers=headers_admin,
        json={
            "catatan": "Nota Supplier B (Kenaikan Harga)",
            "items": [
                {
                    "bahan_id": b1["id"],
                    "jumlah_kemasan_besar": 2,
                    "jumlah_satuan_kecil": 0,
                    "harga_total": 50000,
                },
            ],
        },
    )
    assert bm2.status_code == 200

    rekap_all = await client.get(
        f"/api/v1/stok/barang-masuk?tanggal_mulai={today.isoformat()}&tanggal_selesai={today.isoformat()}",
        headers=headers_admin,
    )
    assert rekap_all.status_code == 200
    data = rekap_all.json()
    assert data["total_transaksi"] == 2
    assert data["total_item_masuk"] == 3
    assert Decimal(str(data["total_nilai_pembelian"])) == Decimal("126000.00")

    latest = data["items"][0]
    assert latest["catatan"] == "Nota Supplier B (Kenaikan Harga)"
    assert Decimal(str(latest["total_nilai"])) == Decimal("50000.00")
    det = latest["details"][0]
    assert det["nama_bahan"] == "Susu Segar Bar"
    assert Decimal(str(det["harga_per_kemasan"])) == Decimal("25000.00")
    assert Decimal(str(det["harga_per_satuan_kecil"])) == Decimal("25.00")
    assert Decimal(str(det["harga_rata_rata_saat_ini"])) == Decimal("22.50")
    assert Decimal(str(det["selisih_vs_avg"])) == Decimal("2.50")

    rekap_kit = await client.get(
        "/api/v1/stok/barang-masuk?area=kitchen",
        headers=headers_admin,
    )
    assert rekap_kit.status_code == 200
    kdata = rekap_kit.json()
    assert kdata["total_transaksi"] == 1
    assert Decimal(str(kdata["total_nilai_pembelian"])) == Decimal("36000.00")
    assert kdata["items"][0]["details"][0]["nama_bahan"] == "Minyak Dapur Kit"

    rep = await client.get(
        f"/api/v1/reporting/profit-periode?filter=harian&tanggal={today.isoformat()}",
        headers=headers_admin,
    )
    assert rep.status_code == 200
    rep_json = rep.json()
    assert rep_json["jumlah_barang_masuk"] == 2
    assert Decimal(str(rep_json["total_belanja_barang_masuk"])) == Decimal("126000.00")


@pytest.mark.asyncio
async def test_corporate_financial_reporting_and_multi_month_stock(client, sample_data, test_db):
    """
    Verifikasi laporan keuangan standar perusahaan (Laba Rugi akrual + Arus Kas riil + Valuasi Aset Stok multi-bulan
    + pencatatan barang masuk ke histori & breakdown pengeluaran menyeluruh).
    """
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    today = sample_data["today"]
    days_in_month = calendar.monthrange(today.year, today.month)[1]

    b_kopi = (
        await client.post(
            "/api/v1/master/bahan",
            headers=headers_admin,
            json={
                "nama": "Biji Kopi Multi Bulan",
                "satuan": "gram",
                "area": "bar",
                "isi_per_kemasan": 1000,
                "stok_minimum": 5,
            },
        )
    ).json()

    # Modal stok multi-bulan Rp 50.000.000 (100 kg @ Rp 500/gram)
    bm_res = await client.post(
        "/api/v1/stok/barang-masuk",
        headers=headers_admin,
        json={
            "catatan": "Stok biji kopi 3 bulan",
            "items": [
                {
                    "bahan_id": b_kopi["id"],
                    "jumlah_kemasan_besar": 100,
                    "jumlah_satuan_kecil": 0,
                    "harga_total": 50000000,
                }
            ],
        },
    )
    assert bm_res.status_code == 200

    # Biaya operasional bulanan (10.000/hari pro-rata)
    op_res = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "kategori_id": "katp-1",
            "tipe": "bulanan",
            "nominal": 10000 * days_in_month,
            "bulan": f"{today.year}-{today.month:02d}",
            "keterangan": "Listrik cafe",
        },
    )
    assert op_res.status_code == 200

    # Penjualan Rp 50.000 dengan HPP Rp 15.000 -> Laba Kotor Rp 35.000, Laba Bersih Usaha Rp 25.000
    tx = Transaksi(
        id="trx-fin-1",
        jadwal_shift_id="shift-kasir-k1",
        kasir_id="usr-karyawan1",
        nomor_transaksi="INV-FIN-001",
        metode_bayar="cash",
        status="selesai",
        total_harga=Decimal("50000.00"),
        waktu_transaksi=now_local(),
    )
    txd = TransaksiDetail(
        id="txd-fin-1",
        transaksi_id="trx-fin-1",
        menu_id="menu-1",
        qty=2,
        harga_satuan=Decimal("25000.00"),
        hpp_satuan=Decimal("7500.00"),
        subtotal=Decimal("50000.00"),
        status_item="selesai",
    )
    test_db.add_all([tx, txd])
    await test_db.commit()

    rep = await client.get(
        f"/api/v1/reporting/profit-periode?filter=harian&tanggal={today.isoformat()}",
        headers=headers_admin,
    )
    assert rep.status_code == 200
    d = rep.json()

    # 1. Laba Rugi Usaha (Akrual)
    assert Decimal(str(d["total_penjualan"])) == Decimal("50000.00")
    assert Decimal(str(d["total_hpp_teoritis"])) == Decimal("15000.00")
    assert Decimal(str(d["laba_kotor"])) == Decimal("35000.00")
    assert Decimal(str(d["gross_margin_persen"])) == Decimal("70.00")
    assert Decimal(str(d["total_operasional"])) == Decimal("10000.00")
    assert Decimal(str(d["net_profit"])) == Decimal("25000.00")
    assert Decimal(str(d["net_margin_persen"])) == Decimal("50.00")

    # 2. Arus Kas Riil (termasuk modal stok bahan Rp 50jt + OpEx Rp 10k)
    assert Decimal(str(d["total_belanja_barang_masuk"])) == Decimal("50000000.00")
    assert Decimal(str(d["total_pengeluaran_kas"])) == Decimal("50010000.00")
    assert Decimal(str(d["arus_kas_bersih"])) == Decimal("-49960000.00")

    # 3. Valuasi Aset Persediaan Stok tersisa di gudang
    assert Decimal(str(d["nilai_aset_stok_gudang"])) == Decimal("50000000.00")
    assert Decimal(str(d["nilai_aset_stok_saat_ini"])) == Decimal("50000000.00")

    # 4. Pengeluaran terpadu (OpEx + Belanja Bahan) & Breakdown
    list_all = await client.get(
        "/api/v1/reporting/pengeluaran?include_barang_masuk=true",
        headers=headers_admin,
    )
    assert list_all.status_code == 200
    rows = list_all.json()
    bm_entries = [r for r in rows if r["sumber"] == "barang_masuk"]
    assert len(bm_entries) == 1
    assert bm_entries[0]["tipe"] == "belanja_bahan"
    assert bm_entries[0]["editable"] is False
    assert Decimal(str(bm_entries[0]["nominal"])) == Decimal("50000000.00")

    bd = await client.get(
        f"/api/v1/reporting/pengeluaran/breakdown?filter=harian&tanggal={today.isoformat()}",
        headers=headers_admin,
    )
    assert bd.status_code == 200
    bd_j = bd.json()
    assert Decimal(str(bd_j["total_pengeluaran"])) == Decimal("10000.00")
    assert Decimal(str(bd_j["total_belanja_bahan"])) == Decimal("50000000.00")
    assert Decimal(str(bd_j["total_semua_pengeluaran"])) == Decimal("50010000.00")
    assert bd_j["items_dengan_bahan"][0]["nama_kategori"] == "Belanja Stok Bahan (Gudang)"

    # 5. Dashboard overview fields
    ov = await client.get("/api/v1/reporting/dashboard-overview", headers=headers_admin)
    assert ov.status_code == 200
    ov_j = ov.json()
    assert Decimal(str(ov_j["laba_kotor"])) == Decimal("35000.00")
    assert Decimal(str(ov_j["total_belanja_barang_masuk"])) == Decimal("50000000.00")
    assert Decimal(str(ov_j["total_pengeluaran_kas"])) == Decimal("50010000.00")
    assert Decimal(str(ov_j["arus_kas_bersih"])) == Decimal("-49960000.00")
    assert Decimal(str(ov_j["nilai_aset_stok_saat_ini"])) == Decimal("50000000.00")


@pytest.mark.asyncio
async def test_pengeluaran_mendadak_free_text_without_kategori(client, sample_data):
    """Pengeluaran mendadak boleh dicatat via input nama bebas tanpa kategori bulanan, tetap masuk P&L & breakdown."""
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    today = sample_data["today"]

    # 1. Mendadak tanpa nama/kategori/keterangan harus ditolak (422)
    res_empty = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "mendadak",
            "nominal": 15000,
            "tanggal": today.isoformat(),
        },
    )
    assert res_empty.status_code == 422

    # 2. Bulanan tanpa kategori_id harus ditolak (422)
    res_bulanan_no_kat = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "bulanan",
            "nominal": 300000,
            "bulan": f"{today.year}-{today.month:02d}",
        },
    )
    assert res_bulanan_no_kat.status_code == 422

    # 3. Mendadak dengan nama_pengeluaran bebas tanpa kategori_id -> 200
    res_create = await client.post(
        "/api/v1/reporting/pengeluaran",
        headers=headers_admin,
        json={
            "tipe": "mendadak",
            "nama_pengeluaran": "Beli Galon Air & Es Batu",
            "nominal": 35000,
            "tanggal": today.isoformat(),
            "keterangan": "2 galon + 3 kantong es",
        },
    )
    assert res_create.status_code == 200
    created = res_create.json()
    assert created["kategori_id"] is None
    assert created["nama_pengeluaran"] == "Beli Galon Air & Es Batu"
    assert created["nama_kategori"] == "Beli Galon Air & Es Batu"

    # 4. List & Filter by mendadak-insidental
    res_list = await client.get(
        "/api/v1/reporting/pengeluaran?kategori_id=mendadak-insidental",
        headers=headers_admin,
    )
    assert res_list.status_code == 200
    items = res_list.json()
    assert len(items) == 1
    assert items[0]["id"] == created["id"]

    # 5. Breakdown & Profit Harian tetap akurat menghitung pengeluaran mendadak tanpa kategori
    res_bd = await client.get(
        f"/api/v1/reporting/pengeluaran/breakdown?filter=harian&tanggal={today.isoformat()}",
        headers=headers_admin,
    )
    assert res_bd.status_code == 200
    bd = res_bd.json()
    assert Decimal(str(bd["total_pengeluaran"])) == Decimal("35000.00")
    assert bd["items"][0]["kategori_id"] == "mendadak-insidental"
    assert bd["items"][0]["nama_kategori"] == "Pengeluaran Mendadak (Insidental)"

    res_ph = await client.get(
        f"/api/v1/reporting/profit-harian?tanggal={today.isoformat()}",
        headers=headers_admin,
    )
    assert res_ph.status_code == 200
    ph = res_ph.json()
    assert Decimal(str(ph["pengeluaran_mendadak"])) == Decimal("35000.00")
    assert Decimal(str(ph["net_profit_harian"])) == Decimal("-35000.00")

    # 6. Update nama & nominal pengeluaran mendadak bebas
    res_upd = await client.put(
        f"/api/v1/reporting/pengeluaran/{created['id']}",
        headers=headers_admin,
        json={"nama_pengeluaran": "Beli Galon Aqua 3 Pcs", "nominal": 45000},
    )
    assert res_upd.status_code == 200
    upd = res_upd.json()
    assert upd["nama_pengeluaran"] == "Beli Galon Aqua 3 Pcs"
    assert upd["nama_kategori"] == "Beli Galon Aqua 3 Pcs"
    assert Decimal(str(upd["nominal"])) == Decimal("45000.00")

    # 7. Delete works cleanly
    res_del = await client.delete(
        f"/api/v1/reporting/pengeluaran/{created['id']}",
        headers=headers_admin,
    )
    assert res_del.status_code == 200




