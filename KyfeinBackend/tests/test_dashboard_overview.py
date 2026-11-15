import calendar
from datetime import datetime, time, timedelta
from decimal import Decimal

import pytest

from app.models import (
    Absensi,
    Foto,
    JadwalShift,
    Pengeluaran,
    Transaksi,
    TransaksiDetail,
)


@pytest.mark.asyncio
async def test_dashboard_overview_sales_profit_chart_and_behavior(
    client, sample_data, test_db, mock_time_at
):
    mock_time_at("14:00")
    today = sample_data["today"]
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    headers_k1 = {"Authorization": f"Bearer {sample_data['token_k1']}"}

    # Karyawan dilarang mengakses endpoint dashboard admin
    res_forbidden = await client.get(
        "/api/v1/reporting/dashboard-overview",
        headers=headers_k1,
    )
    assert res_forbidden.status_code == 403

    # Setup pengeluaran bulanan (pro-rata harian exact = 10.000/hari) & mendadak hari ini (15.000)
    days_in_month = calendar.monthrange(today.year, today.month)[1]
    p_bulanan = Pengeluaran(
        id="peng-bul-dash",
        kategori_id="katp-1",
        tipe="bulanan",
        nominal=Decimal(str(10000 * days_in_month)),
        bulan=today.replace(day=1),
        keterangan="Sewa pro-rata",
        dicatat_oleh="usr-admin",
    )
    p_mendadak = Pengeluaran(
        id="peng-mend-dash",
        kategori_id="katp-1",
        tipe="mendadak",
        nominal=Decimal("15000.00"),
        tanggal=today,
        keterangan="Es batu tambahan",
        dicatat_oleh="usr-admin",
    )
    test_db.add_all([p_bulanan, p_mendadak])

    # Transaksi hari ini (2 selesai: Cash 60k HPP 20k, QRIS 40k HPP 15k) & kemarin (Cash 50k HPP 10k)
    yesterday = today - timedelta(days=1)
    tx_today_1 = Transaksi(
        id="tx-dash-1",
        jadwal_shift_id="shift-kasir-k1",
        kasir_id="usr-karyawan1",
        nomor_transaksi="TRX-DASH-001",
        metode_bayar="cash",
        total_harga=Decimal("60000.00"),
        status="selesai",
        waktu_transaksi=datetime.combine(today, time(10, 15)),
    )
    tx_today_2 = Transaksi(
        id="tx-dash-2",
        jadwal_shift_id="shift-kasir-k1",
        kasir_id="usr-karyawan1",
        nomor_transaksi="TRX-DASH-002",
        metode_bayar="qris",
        total_harga=Decimal("40000.00"),
        status="selesai",
        waktu_transaksi=datetime.combine(today, time(13, 30)),
    )
    tx_yesterday = Transaksi(
        id="tx-dash-prev",
        jadwal_shift_id="shift-past",
        kasir_id="usr-karyawan1",
        nomor_transaksi="TRX-DASH-000",
        metode_bayar="cash",
        total_harga=Decimal("50000.00"),
        status="selesai",
        waktu_transaksi=datetime.combine(yesterday, time(11, 0)),
    )
    test_db.add_all([tx_today_1, tx_today_2, tx_yesterday])
    await test_db.flush()

    test_db.add_all([
        TransaksiDetail(
            id="txd-1",
            transaksi_id="tx-dash-1",
            menu_id="menu-1",
            qty=2,
            harga_satuan=Decimal("30000.00"),
            hpp_satuan=Decimal("10000.00"),
            subtotal=Decimal("60000.00"),
            status_item="selesai",
        ),
        TransaksiDetail(
            id="txd-2",
            transaksi_id="tx-dash-2",
            menu_id="menu-1",
            qty=1,
            harga_satuan=Decimal("40000.00"),
            hpp_satuan=Decimal("15000.00"),
            subtotal=Decimal("40000.00"),
            status_item="selesai",
        ),
        TransaksiDetail(
            id="txd-3",
            transaksi_id="tx-dash-prev",
            menu_id="menu-1",
            qty=1,
            harga_satuan=Decimal("50000.00"),
            hpp_satuan=Decimal("10000.00"),
            subtotal=Decimal("50000.00"),
            status_item="selesai",
        ),
    ])

    # Perilaku karyawan:
    # - usr-karyawan1: telat 3x di 4 hari terakhir (+ lupa absen pulang di shift lampau) => perlu_perhatian
    # - usr-karyawan2: hadir 2x tepat waktu & absen pulang => disiplin
    extra_shifts = [
        JadwalShift(
            id="shift-beh-1",
            karyawan_id="usr-karyawan1",
            tanggal=today - timedelta(days=4),
            shift="shift_1",
            area_kerja="kasir",
            jam_mulai=time(8, 0),
            jam_selesai=time(16, 0),
        ),
        JadwalShift(
            id="shift-beh-2",
            karyawan_id="usr-karyawan1",
            tanggal=today - timedelta(days=3),
            shift="shift_1",
            area_kerja="kasir",
            jam_mulai=time(8, 0),
            jam_selesai=time(16, 0),
        ),
    ]
    fotos = [
        Foto(id=f"f-beh-{i}", jenis="absensi", path=f"u/{i}.jpg", uploader_id="usr-karyawan1", dipakai=True)
        for i in range(1, 6)
    ]
    test_db.add_all(extra_shifts + fotos)
    await test_db.flush()

    test_db.add_all([
        Absensi(
            id="abs-k1-1",
            karyawan_id="usr-karyawan1",
            jadwal_shift_id="shift-beh-1",
            jam_masuk=datetime.combine(today - timedelta(days=4), time(8, 25)),
            jam_pulang=datetime.combine(today - timedelta(days=4), time(16, 0)),
            lat_masuk=Decimal("-6.2"),
            lng_masuk=Decimal("106.8"),
            foto_masuk_id="f-beh-1",
            menit_telat=25,
            status_pulang="tepat_waktu",
        ),
        Absensi(
            id="abs-k1-2",
            karyawan_id="usr-karyawan1",
            jadwal_shift_id="shift-beh-2",
            jam_masuk=datetime.combine(today - timedelta(days=3), time(8, 20)),
            jam_pulang=datetime.combine(today - timedelta(days=3), time(16, 5)),
            lat_masuk=Decimal("-6.2"),
            lng_masuk=Decimal("106.8"),
            foto_masuk_id="f-beh-2",
            menit_telat=20,
            status_pulang="tepat_waktu",
        ),
        Absensi(
            id="abs-k1-3",
            karyawan_id="usr-karyawan1",
            jadwal_shift_id="shift-past",
            jam_masuk=datetime.combine(today - timedelta(days=2), time(8, 30)),
            jam_pulang=None,  # lupa absen pulang (> 90 mnt lewat 16:00)
            lat_masuk=Decimal("-6.2"),
            lng_masuk=Decimal("106.8"),
            foto_masuk_id="f-beh-3",
            menit_telat=30,
            status_pulang="lupa_absen",
        ),
        Absensi(
            id="abs-k2-1",
            karyawan_id="usr-karyawan2",
            jadwal_shift_id="shift-past2",
            jam_masuk=datetime.combine(today - timedelta(days=2), time(7, 55)),
            jam_pulang=datetime.combine(today - timedelta(days=2), time(16, 0)),
            lat_masuk=Decimal("-6.2"),
            lng_masuk=Decimal("106.8"),
            foto_masuk_id="f-beh-4",
            menit_telat=0,
            status_pulang="tepat_waktu",
        ),
    ])
    await test_db.commit()

    # 1. Test preset = hari_ini (default 7-day trend chart)
    res_today = await client.get(
        "/api/v1/reporting/dashboard-overview?preset=hari_ini",
        headers=headers_admin,
    )
    assert res_today.status_code == 200
    data = res_today.json()

    assert Decimal(str(data["total_penjualan"])) == Decimal("100000.00")
    assert Decimal(str(data["total_hpp_teoritis"])) == Decimal("35000.00")
    assert Decimal(str(data["pengeluaran_bulanan_pro_rata"])) == Decimal("10000.00")
    assert Decimal(str(data["pengeluaran_mendadak"])) == Decimal("15000.00")
    assert Decimal(str(data["total_pengeluaran"])) == Decimal("25000.00")
    # Net Profit = 100.000 - 35.000 - 25.000 = 40.000
    assert Decimal(str(data["net_profit"])) == Decimal("40000.00")
    assert data["jumlah_transaksi"] == 2
    assert Decimal(str(data["total_cash"])) == Decimal("60000.00")
    assert Decimal(str(data["total_qris"])) == Decimal("40000.00")
    # 100k hari ini vs 50k kemarin -> +100.0%
    assert data["perubahan_penjualan_persen"] == 100.0

    # Chart defaults to 7 days in hari_ini preset
    assert data["chart_granularity"] == "hari"
    assert len(data["grafik_penjualan"]) == 7
    today_point = [p for p in data["grafik_penjualan"] if p["tanggal"] == today.isoformat()][0]
    assert Decimal(str(today_point["total_penjualan"])) == Decimal("100000.00")
    assert Decimal(str(today_point["net_profit"])) == Decimal("40000.00")

    # Perilaku karyawan: K1 harus di urutan paling atas (perlu_perhatian, telat 3x = 75 menit)
    beh_list = data["perilaku_karyawan"]
    assert len(beh_list) >= 2
    assert beh_list[0]["karyawan_id"] == "usr-karyawan1"
    assert beh_list[0]["kategori_perilaku"] == "perlu_perhatian"
    assert beh_list[0]["telat_count"] == 3
    assert beh_list[0]["total_menit_telat"] == 75
    assert beh_list[0]["lupa_absen_pulang_count"] == 1
    assert "Sering telat" in beh_list[0]["ringkasan_perilaku"]

    k2_beh = [b for b in beh_list if b["karyawan_id"] == "usr-karyawan2"][0]
    assert k2_beh["kategori_perilaku"] == "disiplin"
    assert k2_beh["telat_count"] == 0
    assert k2_beh["tingkat_ketepatan_persen"] == 100.0

    # 2. Test chart_mode = jam pada hari_ini
    res_hourly = await client.get(
        "/api/v1/reporting/dashboard-overview?preset=hari_ini&chart_mode=jam",
        headers=headers_admin,
    )
    assert res_hourly.status_code == 200
    d_hr = res_hourly.json()
    assert d_hr["chart_granularity"] == "jam"
    jam10 = [p for p in d_hr["grafik_penjualan"] if p["label"] == "10:00"][0]
    assert Decimal(str(jam10["total_penjualan"])) == Decimal("60000.00")
    jam13 = [p for p in d_hr["grafik_penjualan"] if p["label"] == "13:00"][0]
    assert Decimal(str(jam13["total_penjualan"])) == Decimal("40000.00")

    # 3. Test preset = 7_hari
    res_7d = await client.get(
        "/api/v1/reporting/dashboard-overview?preset=7_hari",
        headers=headers_admin,
    )
    assert res_7d.status_code == 200
    d_7 = res_7d.json()
    assert Decimal(str(d_7["total_penjualan"])) == Decimal("150000.00")
    assert d_7["jumlah_transaksi"] == 3

