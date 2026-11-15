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
