import pytest
import pytest_asyncio
from datetime import date, timedelta, time
from decimal import Decimal

from app.core.utils import now_local
from app.models import (
    JadwalShift, Absensi, Menu, MenuResep, Bahan, Transaksi, TransaksiDetail, KategoriMenu
)

@pytest.mark.asyncio
async def test_issue3_hpp_snapshot_and_price_immutability(client, sample_data, test_db):
    """
    Issue 3 Requirements:
    1. Transaction detail snapshots hpp_satuan at creation time.
    2. Changing bahan.harga_rata_rata later does NOT alter existing transaction's hpp_satuan or daily profit report.
    """
    today = sample_data["today"]

    # 1. Setup Menu & Recipe
    # Recipe: menu-1 (Espresso) uses 10g of b-1 (Biji Kopi, current harga_rata_rata = 150)
    resep1 = MenuResep(
        id="resep-1",
        menu_id="menu-1",
        bahan_id="b-1",
        jumlah_terpakai=Decimal("10.000") # 10 gram * 150 = 1500 HPP
    )
    test_db.add(resep1)

    # Add Absensi for kasir
    absen = Absensi(
        id="abs-kasir-hpp",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-kasir-k1",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1"
    )
    test_db.add(absen)
    await test_db.commit()

    # 2. Create transaction when HPP is 1500 per item
    res_trx1 = await client.post(
        "/api/v1/transaksi/",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "cash",
            "uang_diterima": 50000,
            "details": [{"menu_id": "menu-1", "qty": 2}] # 2 * 20000 = 40000 total, total HPP = 2 * 1500 = 3000
        }
    )
    assert res_trx1.status_code == 200
    trx_data1 = res_trx1.json()
    assert Decimal(str(trx_data1["details"][0]["hpp_satuan"])) == Decimal("1500.00")

    # Check daily profit report
    res_profit1 = await client.get(
        f"/api/v1/reporting/profit-harian?tanggal={today.isoformat()}",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"}
    )
    assert res_profit1.status_code == 200
    profit1 = res_profit1.json()
    assert Decimal(str(profit1["total_hpp_teoritis"])) == Decimal("3000.00")

    # 3. Change ingredient price (harga_rata_rata of b-1 doubles to 300)
    bahan = await test_db.get(Bahan, "b-1")
    bahan.harga_rata_rata = Decimal("300.00")
    await test_db.commit()

    # 4. Verify existing transaction HPP and daily profit report DO NOT CHANGE!
    res_profit1_after = await client.get(
        f"/api/v1/reporting/profit-harian?tanggal={today.isoformat()}",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"}
    )
    assert res_profit1_after.status_code == 200
    profit1_after = res_profit1_after.json()
    assert Decimal(str(profit1_after["total_hpp_teoritis"])) == Decimal("3000.00") # Remains 3000!

    # 5. Create NEW transaction after price change -> should use new HPP (10 * 300 = 3000 per item)
    res_trx2 = await client.post(
        "/api/v1/transaksi/",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "cash",
            "uang_diterima": 50000,
            "details": [{"menu_id": "menu-1", "qty": 1}] # 1 item * 3000 HPP = 3000 HPP
        }
    )
    assert res_trx2.status_code == 200
    trx_data2 = res_trx2.json()
    assert Decimal(str(trx_data2["details"][0]["hpp_satuan"])) == Decimal("3000.00")

    # Daily profit report now includes new transaction: 3000 + 3000 = 6000 total HPP
    res_profit_combined = await client.get(
        f"/api/v1/reporting/profit-harian?tanggal={today.isoformat()}",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"}
    )
    assert Decimal(str(res_profit_combined.json()["total_hpp_teoritis"])) == Decimal("6000.00")

@pytest.mark.asyncio
async def test_issue3_menu_tanpa_resep_and_default_date(client, sample_data, test_db):
    """
    - Menu without recipe has hpp_satuan = 0
    - Appears in menu_tanpa_resep list on profit report
    - Default date param (None -> today) works dynamically
    """
    # Create menu without recipe
    menu_no_recipe = Menu(
        id="menu-no-rec",
        nama="Mineral Water",
        kode_menu="WTR01",
        harga=Decimal("5000"),
        kategori_id="kat-1",
        status_aktif=True
    )
    test_db.add(menu_no_recipe)

    absen = Absensi(
        id="abs-kasir-norec",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-kasir-k1",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1"
    )
    test_db.add(absen)
    await test_db.commit()

    # Buy menu without recipe
    res_trx = await client.post(
        "/api/v1/transaksi/",
        headers={"Authorization": f"Bearer {sample_data['token_k1']}"},
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "cash",
            "uang_diterima": 10000,
            "details": [{"menu_id": "menu-no-rec", "qty": 1}]
        }
    )
    assert res_trx.status_code == 200
    assert Decimal(str(res_trx.json()["details"][0]["hpp_satuan"])) == Decimal("0.00")

    # Fetch daily profit without supplying 'tanggal' query param
    res_profit = await client.get(
        "/api/v1/reporting/profit-harian",
        headers={"Authorization": f"Bearer {sample_data['token_admin']}"}
    )
    assert res_profit.status_code == 200
    profit_data = res_profit.json()
    assert "Mineral Water" in profit_data["menu_tanpa_resep"]
