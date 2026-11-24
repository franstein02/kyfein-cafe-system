import calendar
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import List, Optional, Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, extract, and_
from sqlalchemy.orm import selectinload

from app.core.deps import get_db, require_roles
from app.core.utils import now_local
from app.models.transaksi import Transaksi, TransaksiDetail
from app.models.master_data import (
    KategoriMenu, Menu, MenuResep, Bahan, KategoriPengeluaran, hitung_batas_minimum_kecil,
)
from app.models.pengeluaran import Pengeluaran
from app.models.karyawan import Karyawan
from app.models.stok import BarangMasuk, BarangMasukDetail, BarangKeluar, StokOpname, StokGudang, StokTitik
from app.models.absensi import Absensi, IzinTelat, IzinTidakMasuk
from app.models.jadwal import JadwalShift
from app.schemas.reporting import (
    PengeluaranCreate, PengeluaranUpdate, PengeluaranOut,
    DailyProfitReportOut, PeriodProfitReportOut,
    KategoriBreakdownItem, PengeluaranBreakdownOut,
    DashboardOverviewOut,
    MenuHppBahanItemOut, MenuHppReportItemOut,
    BahanHargaMonitorOut, HppMenuReportOut,
)
from app.services.dashboard_service import (
    build_employee_behavior,
    build_sales_chart,
    resolve_dashboard_dates,
)

router = APIRouter()


def _resolve_period_dates(
    filter_type: Literal['harian', 'range', 'bulanan', 'tahunan'],
    tanggal: Optional[date] = None,
    tanggal_mulai: Optional[date] = None,
    tanggal_selesai: Optional[date] = None,
    bulan: Optional[str] = None,
    tahun: Optional[int] = None,
) -> tuple[date, date]:
    if filter_type == 'harian':
        if not tanggal:
            raise HTTPException(status_code=400, detail="Tanggal wajib diisi untuk filter harian")
        return tanggal, tanggal
    elif filter_type == 'range':
        if not tanggal_mulai or not tanggal_selesai:
            raise HTTPException(
                status_code=400,
                detail="Tanggal mulai dan tanggal selesai wajib diisi untuk filter range"
            )
        if tanggal_mulai > tanggal_selesai:
            raise HTTPException(
                status_code=400,
                detail="Tanggal mulai tidak boleh setelah tanggal selesai"
            )
        return tanggal_mulai, tanggal_selesai
    elif filter_type == 'bulanan':
        parsed_m: Optional[int] = None
        parsed_y: Optional[int] = tahun
        if bulan is not None:
            b_str = str(bulan).strip()
            if "-" in b_str:
                parts = b_str.split("-")
                if len(parts) >= 2 and parts[0].isdigit() and parts[1].isdigit():
                    parsed_y = int(parts[0])
                    parsed_m = int(parts[1])
            elif b_str.isdigit():
                parsed_m = int(b_str)
        if not parsed_m or not parsed_y or not (1 <= parsed_m <= 12):
            raise HTTPException(
                status_code=400,
                detail="Bulan dan tahun wajib diisi untuk filter bulanan"
            )
        start_d = date(parsed_y, parsed_m, 1)
        last_day = calendar.monthrange(parsed_y, parsed_m)[1]
        return start_d, date(parsed_y, parsed_m, last_day)
    elif filter_type == 'tahunan':
        if not tahun:
            raise HTTPException(status_code=400, detail="Tahun wajib diisi untuk filter tahunan")
        return date(tahun, 1, 1), date(tahun, 12, 31)
    raise HTTPException(status_code=400, detail="Filter tidak valid")


async def _hitung_profit_rentang(
    db: AsyncSession,
    start_date: date,
    end_date: date,
) -> dict:
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())

    # 1. Total Penjualan & Jumlah Transaksi (status='selesai')
    trx_res = await db.execute(
        select(
            func.count(Transaksi.id),
            func.sum(Transaksi.total_harga)
        ).where(
            and_(
                Transaksi.waktu_transaksi >= start_dt,
                Transaksi.waktu_transaksi <= end_dt,
                Transaksi.status == "selesai"
            )
        )
    )
    row = trx_res.one()
    jumlah_transaksi = int(row[0] or 0)
    total_penjualan = row[1] or Decimal("0")

    # 2. HPP Snapshot: sum(hpp_satuan * qty) for completed transactions
    hpp_res = await db.execute(
        select(func.sum(TransaksiDetail.hpp_satuan * TransaksiDetail.qty))
        .join(Transaksi, TransaksiDetail.transaksi_id == Transaksi.id)
        .where(
            and_(
                Transaksi.waktu_transaksi >= start_dt,
                Transaksi.waktu_transaksi <= end_dt,
                Transaksi.status == "selesai"
            )
        )
    )
    total_hpp = hpp_res.scalar() or Decimal("0")

    # 3. Distinct menu items sold to check menu_tanpa_resep
    sold_menus_res = await db.execute(
        select(Menu)
        .join(TransaksiDetail, TransaksiDetail.menu_id == Menu.id)
        .join(Transaksi, TransaksiDetail.transaksi_id == Transaksi.id)
        .where(
            and_(
                Transaksi.waktu_transaksi >= start_dt,
                Transaksi.waktu_transaksi <= end_dt,
                Transaksi.status == "selesai"
            )
        )
        .distinct()
    )
    sold_menus = sold_menus_res.scalars().all()

    menu_tanpa_resep: List[str] = []
    for menu_item in sold_menus:
        resep_check = await db.execute(
            select(MenuResep.id).where(MenuResep.menu_id == menu_item.id).limit(1)
        )
        if not resep_check.scalars().first():
            if menu_item.nama not in menu_tanpa_resep:
                menu_tanpa_resep.append(menu_item.nama)

    # 4. Pengeluaran Bulanan (Pro-Rata per bulan yang beririsan)
    pengeluaran_bulanan_pro_rata = Decimal("0")
    current = start_date.replace(day=1)
    end_month = end_date.replace(day=1)

    while current <= end_month:
        y = current.year
        m = current.month
        m_last_day = calendar.monthrange(y, m)[1]
        m_start = date(y, m, 1)
        m_end = date(y, m, m_last_day)

        o_start = max(start_date, m_start)
        o_end = min(end_date, m_end)

        if o_start <= o_end:
            active_days = Decimal(str((o_end - o_start).days + 1))
            days_in_month = Decimal(str(m_last_day))

            bulanan_res = await db.execute(
                select(func.sum(Pengeluaran.nominal)).where(
                    and_(
                        Pengeluaran.tipe == "bulanan",
                        extract("year", Pengeluaran.bulan) == y,
                        extract("month", Pengeluaran.bulan) == m
                    )
                )
            )
            total_bulanan_month = bulanan_res.scalar() or Decimal("0")
            pengeluaran_bulanan_pro_rata += (total_bulanan_month / days_in_month) * active_days

        if m == 12:
            current = date(y + 1, 1, 1)
        else:
            current = date(y, m + 1, 1)

    # 5. Pengeluaran Mendadak dalam rentang tanggal
    mendadak_res = await db.execute(
        select(func.sum(Pengeluaran.nominal)).where(
            and_(
                Pengeluaran.tipe == "mendadak",
                Pengeluaran.tanggal >= start_date,
                Pengeluaran.tanggal <= end_date
            )
        )
    )
    pengeluaran_mendadak = mendadak_res.scalar() or Decimal("0")

    # 6. Laba Kotor, Operasional, Net Profit & Arus Kas
    laba_kotor = total_penjualan - total_hpp
    total_operasional = pengeluaran_bulanan_pro_rata + pengeluaran_mendadak
    net_profit = laba_kotor - total_operasional
    gross_margin_persen = (
        round((laba_kotor / total_penjualan) * Decimal("100"), 2)
        if total_penjualan > 0
        else Decimal("0.00")
    )
    net_margin_persen = (
        round((net_profit / total_penjualan) * Decimal("100"), 2)
        if total_penjualan > 0
        else Decimal("0.00")
    )

    # 7. Ringkasan Metode Bayar & Transaksi Dibatalkan pada Periode
    cash_res = await db.execute(
        select(func.sum(Transaksi.total_harga)).where(
            and_(
                Transaksi.waktu_transaksi >= start_dt,
                Transaksi.waktu_transaksi <= end_dt,
                Transaksi.status == "selesai",
                Transaksi.metode_bayar == "cash",
            )
        )
    )
    total_cash = cash_res.scalar() or Decimal("0")

    qris_res = await db.execute(
        select(func.sum(Transaksi.total_harga)).where(
            and_(
                Transaksi.waktu_transaksi >= start_dt,
                Transaksi.waktu_transaksi <= end_dt,
                Transaksi.status == "selesai",
                Transaksi.metode_bayar == "qris",
            )
        )
    )
    total_qris = qris_res.scalar() or Decimal("0")

    cancel_res = await db.execute(
        select(func.count(Transaksi.id)).where(
            and_(
                Transaksi.waktu_transaksi >= start_dt,
                Transaksi.waktu_transaksi <= end_dt,
                Transaksi.status == "dibatalkan",
            )
        )
    )
    jumlah_transaksi_dibatalkan = int(cancel_res.scalar() or 0)

    # 8. Ringkasan Stok pada Periode
    bm_res = await db.execute(
        select(func.count(BarangMasuk.id)).where(
            and_(BarangMasuk.waktu >= start_dt, BarangMasuk.waktu <= end_dt)
        )
    )
    jumlah_barang_masuk = int(bm_res.scalar() or 0)

    bm_total_res = await db.execute(
        select(func.sum(BarangMasukDetail.harga_total))
        .join(BarangMasuk, BarangMasukDetail.barang_masuk_id == BarangMasuk.id)
        .where(and_(BarangMasuk.waktu >= start_dt, BarangMasuk.waktu <= end_dt))
    )
    total_belanja_barang_masuk = bm_total_res.scalar() or Decimal("0")

    bk_res = await db.execute(
        select(func.count(BarangKeluar.id)).where(
            and_(BarangKeluar.waktu >= start_dt, BarangKeluar.waktu <= end_dt)
        )
    )
    jumlah_barang_keluar = int(bk_res.scalar() or 0)

    op_res = await db.execute(
        select(func.count(StokOpname.id)).where(
            and_(StokOpname.waktu_opname >= start_dt, StokOpname.waktu_opname <= end_dt)
        )
    )
    jumlah_sesi_opname = int(op_res.scalar() or 0)

    all_bahan_res = await db.execute(select(Bahan))
    all_bahans = all_bahan_res.scalars().all()
    sg_res = await db.execute(select(StokGudang))
    sg_map = {s.bahan_id: s for s in sg_res.scalars().all()}
    st_res = await db.execute(select(StokTitik))
    st_list = st_res.scalars().all()
    jumlah_stok_menipis = 0
    nilai_aset_stok_gudang = Decimal("0")
    nilai_aset_stok_titik = Decimal("0")
    for b in all_bahans:
        sg = sg_map.get(b.id)
        isi = Decimal(str(b.isi_per_kemasan or 1))
        tot_gudang = (
            Decimal(str(sg.jumlah_kemasan_besar)) * isi + Decimal(str(sg.jumlah_satuan_kecil))
            if sg
            else Decimal("0")
        )
        tot_titik = sum(
            (Decimal(str(st.jumlah)) for st in st_list if st.bahan_id == b.id),
            Decimal("0"),
        )
        avg_harga = Decimal(str(b.harga_rata_rata or 0))
        nilai_aset_stok_gudang += tot_gudang * avg_harga
        nilai_aset_stok_titik += tot_titik * avg_harga
        batas_min_kecil = hitung_batas_minimum_kecil(b)
        if batas_min_kecil > 0 and (tot_gudang + tot_titik) <= batas_min_kecil:
            jumlah_stok_menipis += 1

    total_pengeluaran_kas = total_operasional + total_belanja_barang_masuk
    arus_kas_bersih = total_penjualan - total_pengeluaran_kas
    nilai_aset_stok_saat_ini = nilai_aset_stok_gudang + nilai_aset_stok_titik

    # 9. Ringkasan Absensi pada Periode
    abs_res = await db.execute(
        select(Absensi).where(
            and_(Absensi.jam_masuk >= start_dt, Absensi.jam_masuk <= end_dt)
        )
    )
    abs_list = abs_res.scalars().all()
    total_hadir = len(abs_list)
    total_terlambat = sum(1 for a in abs_list if (a.menit_telat or 0) > 0)
    total_tepat_waktu = total_hadir - total_terlambat

    it_res = await db.execute(
        select(func.count(IzinTelat.id))
        .join(JadwalShift, IzinTelat.jadwal_shift_id == JadwalShift.id)
        .where(
            and_(
                JadwalShift.tanggal >= start_date,
                JadwalShift.tanggal <= end_date,
            )
        )
    )
    total_izin_telat = int(it_res.scalar() or 0)

    itm_res = await db.execute(
        select(func.count(IzinTidakMasuk.id))
        .join(JadwalShift, IzinTidakMasuk.jadwal_shift_id == JadwalShift.id)
        .where(
            and_(
                JadwalShift.tanggal >= start_date,
                JadwalShift.tanggal <= end_date,
            )
        )
    )
    total_izin_tidak_masuk = int(itm_res.scalar() or 0)

    return {
        "jumlah_transaksi": jumlah_transaksi,
        "jumlah_transaksi_dibatalkan": jumlah_transaksi_dibatalkan,
        "total_cash": round(total_cash, 2),
        "total_qris": round(total_qris, 2),
        "total_penjualan": round(total_penjualan, 2),
        "total_hpp_teoritis": round(total_hpp, 2),
        "laba_kotor": round(laba_kotor, 2),
        "gross_margin_persen": gross_margin_persen,
        "pengeluaran_bulanan_pro_rata": round(pengeluaran_bulanan_pro_rata, 2),
        "pengeluaran_mendadak": round(pengeluaran_mendadak, 2),
        "total_operasional": round(total_operasional, 2),
        "net_profit": round(net_profit, 2),
        "net_margin_persen": net_margin_persen,
        "menu_tanpa_resep": menu_tanpa_resep,
        "jumlah_barang_masuk": jumlah_barang_masuk,
        "total_belanja_barang_masuk": round(total_belanja_barang_masuk, 2),
        "total_pengeluaran_kas": round(total_pengeluaran_kas, 2),
        "arus_kas_bersih": round(arus_kas_bersih, 2),
        "nilai_aset_stok_gudang": round(nilai_aset_stok_gudang, 2),
        "nilai_aset_stok_titik": round(nilai_aset_stok_titik, 2),
        "nilai_aset_stok_saat_ini": round(nilai_aset_stok_saat_ini, 2),
        "jumlah_barang_keluar": jumlah_barang_keluar,
        "jumlah_sesi_opname": jumlah_sesi_opname,
        "jumlah_stok_menipis": jumlah_stok_menipis,
        "total_hadir": total_hadir,
        "total_tepat_waktu": total_tepat_waktu,
        "total_terlambat": total_terlambat,
        "total_izin_telat": total_izin_telat,
        "total_izin_tidak_masuk": total_izin_tidak_masuk,
    }


@router.get("/profit-harian", response_model=DailyProfitReportOut)
async def get_daily_profit_report(
    tanggal: Optional[date] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    """
    FORMULA PROFIT HARIAN (3.6):
    Profit = Penjualan Hari Itu
           - HPP Snapshot (sum(hpp_satuan * qty) dari transaksi 'selesai' hari itu)
           - Sum(Pengeluaran Bulanan / jumlah_hari_di_bulan_itu)
           - Sum(Pengeluaran Mendadak pada tanggal_itu)
    """
    if not tanggal:
        tanggal = now_local().date()

    res = await _hitung_profit_rentang(db, tanggal, tanggal)
    return DailyProfitReportOut(
        tanggal=tanggal.isoformat(),
        jumlah_transaksi=res["jumlah_transaksi"],
        total_penjualan=res["total_penjualan"],
        total_hpp_teoritis=res["total_hpp_teoritis"],
        laba_kotor=res["laba_kotor"],
        pengeluaran_bulanan_pro_rata=res["pengeluaran_bulanan_pro_rata"],
        pengeluaran_mendadak=res["pengeluaran_mendadak"],
        total_operasional=res["total_operasional"],
        net_profit_harian=res["net_profit"],
        total_belanja_barang_masuk=res["total_belanja_barang_masuk"],
        total_pengeluaran_kas=res["total_pengeluaran_kas"],
        arus_kas_bersih=res["arus_kas_bersih"],
        nilai_aset_stok_saat_ini=res["nilai_aset_stok_saat_ini"],
        menu_tanpa_resep=res["menu_tanpa_resep"],
    )


@router.get("/profit-periode", response_model=PeriodProfitReportOut)
async def get_period_profit_report(
    filter: Literal['harian', 'range', 'bulanan', 'tahunan'] = Query('harian'),
    tanggal: Optional[date] = None,
    tanggal_mulai: Optional[date] = None,
    tanggal_selesai: Optional[date] = None,
    bulan: Optional[str] = Query(None),
    tahun: Optional[int] = Query(None, ge=2000, le=2100),
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    """
    Laporan Penghasilan & Profit untuk filter Harian / Range / Bulanan / Tahunan (3.6).
    """
    if filter == 'harian' and not tanggal:
        tanggal = now_local().date()
    start_date, end_date = _resolve_period_dates(
        filter, tanggal, tanggal_mulai, tanggal_selesai, bulan, tahun
    )
    res = await _hitung_profit_rentang(db, start_date, end_date)
    _, _, beh = await build_employee_behavior(
        db,
        start_date,
        end_date,
        now_local(),
        strict_range=True,
        include_logs=True,
    )
    return PeriodProfitReportOut(
        filter=filter,
        periode_mulai=start_date,
        periode_selesai=end_date,
        jumlah_transaksi=res["jumlah_transaksi"],
        jumlah_transaksi_dibatalkan=res["jumlah_transaksi_dibatalkan"],
        total_cash=res["total_cash"],
        total_qris=res["total_qris"],
        total_penjualan=res["total_penjualan"],
        total_hpp_teoritis=res["total_hpp_teoritis"],
        laba_kotor=res["laba_kotor"],
        gross_margin_persen=res["gross_margin_persen"],
        pengeluaran_bulanan_pro_rata=res["pengeluaran_bulanan_pro_rata"],
        pengeluaran_mendadak=res["pengeluaran_mendadak"],
        total_operasional=res["total_operasional"],
        net_profit=res["net_profit"],
        net_margin_persen=res["net_margin_persen"],
        menu_tanpa_resep=res["menu_tanpa_resep"],
        total_belanja_barang_masuk=res["total_belanja_barang_masuk"],
        total_pengeluaran_kas=res["total_pengeluaran_kas"],
        arus_kas_bersih=res["arus_kas_bersih"],
        nilai_aset_stok_gudang=res["nilai_aset_stok_gudang"],
        nilai_aset_stok_titik=res["nilai_aset_stok_titik"],
        nilai_aset_stok_saat_ini=res["nilai_aset_stok_saat_ini"],
        jumlah_barang_masuk=res["jumlah_barang_masuk"],
        jumlah_barang_keluar=res["jumlah_barang_keluar"],
        jumlah_sesi_opname=res["jumlah_sesi_opname"],
        jumlah_stok_menipis=res["jumlah_stok_menipis"],
        total_shift_terjadwal=beh["total_shift_terjadwal"],
        total_hadir=res["total_hadir"],
        total_tepat_waktu=res["total_tepat_waktu"],
        total_terlambat=res["total_terlambat"],
        total_menit_telat=beh["total_menit_telat"],
        total_izin_telat=res["total_izin_telat"],
        total_izin_tidak_masuk=res["total_izin_tidak_masuk"],
        total_tanpa_keterangan=beh["alpha"],
        total_lupa_absen_pulang=beh["lupa_absen_pulang"],
        tingkat_ketepatan_persen=beh["tingkat_ketepatan_tim_persen"],
        absensi_per_karyawan=beh["items"],
    )


@router.get("/dashboard-overview", response_model=DashboardOverviewOut)
async def get_dashboard_overview(
    preset: Literal['hari_ini', '7_hari', '30_hari', 'bulan_ini', 'custom'] = Query('hari_ini'),
    tanggal_mulai: Optional[date] = None,
    tanggal_selesai: Optional[date] = None,
    chart_mode: Literal['auto', 'jam', 'hari'] = Query('auto'),
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"])),
):
    """
    Endpoint ringkasan terpadu untuk Dashboard Admin:
    - Ringkasan penjualan, HPP, pengeluaran, net profit & margin
    - Grafik tren penjualan & keuntungan (per jam / per hari / per bulan)
    - Analisis perilaku & kedisiplinan karyawan (sering telat, lupa absen pulang, izin, alpha)
    """
    now = now_local()
    today = now.date()
    start_date, end_date = resolve_dashboard_dates(
        preset, today, tanggal_mulai, tanggal_selesai
    )

    kpi = await _hitung_profit_rentang(db, start_date, end_date)
    total_penjualan = kpi["total_penjualan"]
    net_profit = kpi["net_profit"]
    total_pengeluaran = round(
        kpi["pengeluaran_bulanan_pro_rata"] + kpi["pengeluaran_mendadak"], 2
    )
    jml_trx = kpi["jumlah_transaksi"]
    rata_trx = (
        round(total_penjualan / Decimal(str(jml_trx)), 2)
        if jml_trx > 0
        else Decimal("0.00")
    )
    margin_pct = (
        round(float(net_profit / total_penjualan) * 100, 1)
        if total_penjualan > 0
        else 0.0
    )

    # Bandingkan total penjualan dengan periode sebelumnya berdurasi sama
    period_days = (end_date - start_date).days + 1
    prev_end = start_date - timedelta(days=1)
    prev_start = prev_end - timedelta(days=period_days - 1)
    prev_res = await db.execute(
        select(func.sum(Transaksi.total_harga)).where(
            and_(
                Transaksi.waktu_transaksi >= datetime.combine(prev_start, datetime.min.time()),
                Transaksi.waktu_transaksi <= datetime.combine(prev_end, datetime.max.time()),
                Transaksi.status == "selesai",
            )
        )
    )
    prev_sales = Decimal(str(prev_res.scalar() or 0))
    if prev_sales > 0:
        perubahan_pct: Optional[float] = round(
            float((total_penjualan - prev_sales) / prev_sales) * 100, 1
        )
    elif total_penjualan > 0:
        perubahan_pct = 100.0
    else:
        perubahan_pct = None

    granularity, chart_start, chart_end, chart_points = await build_sales_chart(
        db, start_date, end_date, chart_mode
    )
    beh_start, beh_end, behavior_data = await build_employee_behavior(
        db, start_date, end_date, now
    )

    return DashboardOverviewOut(
        filter=preset,
        periode_mulai=start_date,
        periode_selesai=end_date,
        chart_granularity=granularity,
        chart_periode_mulai=chart_start,
        chart_periode_selesai=chart_end,
        periode_perilaku_mulai=beh_start,
        periode_perilaku_selesai=beh_end,
        total_penjualan=total_penjualan,
        total_hpp_teoritis=kpi["total_hpp_teoritis"],
        laba_kotor=kpi["laba_kotor"],
        pengeluaran_bulanan_pro_rata=kpi["pengeluaran_bulanan_pro_rata"],
        pengeluaran_mendadak=kpi["pengeluaran_mendadak"],
        total_pengeluaran=total_pengeluaran,
        net_profit=net_profit,
        margin_profit_persen=margin_pct,
        total_belanja_barang_masuk=kpi["total_belanja_barang_masuk"],
        total_pengeluaran_kas=kpi["total_pengeluaran_kas"],
        arus_kas_bersih=kpi["arus_kas_bersih"],
        nilai_aset_stok_saat_ini=kpi["nilai_aset_stok_saat_ini"],
        jumlah_transaksi=jml_trx,
        jumlah_transaksi_dibatalkan=kpi["jumlah_transaksi_dibatalkan"],
        rata_rata_transaksi=rata_trx,
        total_cash=kpi["total_cash"],
        total_qris=kpi["total_qris"],
        perubahan_penjualan_persen=perubahan_pct,
        grafik_penjualan=chart_points,
        ringkasan_disiplin_total_hadir=behavior_data["total_hadir"],
        ringkasan_disiplin_tepat_waktu=behavior_data["tepat_waktu"],
        ringkasan_disiplin_telat=behavior_data["telat"],
        ringkasan_disiplin_alpha=behavior_data["alpha"],
        tingkat_ketepatan_tim_persen=behavior_data["tingkat_ketepatan_tim_persen"],
        perilaku_karyawan=behavior_data["items"],
    )


MENDADAK_BREAKDOWN_ID = "mendadak-insidental"
MENDADAK_BREAKDOWN_NAMA = "Pengeluaran Mendadak (Insidental)"


@router.get("/pengeluaran/breakdown", response_model=PengeluaranBreakdownOut)
async def get_pengeluaran_breakdown(
    filter: Literal['harian', 'range', 'bulanan', 'tahunan'] = Query('harian'),
    tanggal: Optional[date] = None,
    tanggal_mulai: Optional[date] = None,
    tanggal_selesai: Optional[date] = None,
    bulan: Optional[str] = Query(None),
    tahun: Optional[int] = Query(None, ge=2000, le=2100),
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    """
    Breakdown pengeluaran (mendadak + pro-rata bulanan) per kategori untuk periode yang diminta.
    """
    if filter == 'harian' and not tanggal:
        tanggal = now_local().date()
    start_date, end_date = _resolve_period_dates(
        filter, tanggal, tanggal_mulai, tanggal_selesai, bulan, tahun
    )

    # 2. Fetch all categories
    cat_res = await db.execute(select(KategoriPengeluaran))
    all_cats = cat_res.scalars().all()
    cat_name_map = {c.id: c.nama for c in all_cats}
    cat_totals = {c.id: Decimal('0') for c in all_cats}

    # 3. Mendadak expenses within date range (grouped by kategori_id, or MENDADAK_BREAKDOWN_ID if none)
    mendadak_res = await db.execute(
        select(Pengeluaran).where(
            and_(
                Pengeluaran.tipe == "mendadak",
                Pengeluaran.tanggal >= start_date,
                Pengeluaran.tanggal <= end_date
            )
        )
    )
    for p in mendadak_res.scalars().all():
        cat_id = p.kategori_id or MENDADAK_BREAKDOWN_ID
        if cat_id == MENDADAK_BREAKDOWN_ID:
            cat_name_map[MENDADAK_BREAKDOWN_ID] = MENDADAK_BREAKDOWN_NAMA
        nominal = Decimal(str(p.nominal or 0))
        cat_totals[cat_id] = cat_totals.get(cat_id, Decimal('0')) + nominal

    # 4. Bulanan expenses pro-rata for overlapping months
    current = start_date.replace(day=1)
    end_month = end_date.replace(day=1)

    while current <= end_month:
        y = current.year
        m = current.month
        m_last_day = calendar.monthrange(y, m)[1]
        m_start = date(y, m, 1)
        m_end = date(y, m, m_last_day)

        o_start = max(start_date, m_start)
        o_end = min(end_date, m_end)

        if o_start <= o_end:
            active_days = Decimal(str((o_end - o_start).days + 1))
            days_in_month = Decimal(str(m_last_day))

            bulanan_res = await db.execute(
                select(Pengeluaran).where(
                    and_(
                        Pengeluaran.tipe == "bulanan",
                        extract("year", Pengeluaran.bulan) == y,
                        extract("month", Pengeluaran.bulan) == m
                    )
                )
            )
            for p in bulanan_res.scalars().all():
                cat_id = p.kategori_id
                nominal = Decimal(str(p.nominal or 0))
                daily_prorata = nominal / days_in_month
                cat_totals[cat_id] = cat_totals.get(cat_id, Decimal('0')) + (daily_prorata * active_days)

        if m == 12:
            current = date(y + 1, 1, 1)
        else:
            current = date(y, m + 1, 1)

    # 5. Format breakdown list
    rounded_map = {cat_id: round(tot, 2) for cat_id, tot in cat_totals.items()}
    total_all = sum(rounded_map.values(), Decimal('0'))

    breakdown_items = []
    non_zero_items = []
    for cat_id, rounded_tot in rounded_map.items():
        pct = round((rounded_tot / total_all) * Decimal('100'), 2) if total_all > 0 else Decimal('0.00')
        item_obj = KategoriBreakdownItem(
            kategori_id=cat_id,
            nama_kategori=cat_name_map.get(cat_id, "Lainnya"),
            total_nominal=rounded_tot,
            persentase=pct,
        )
        breakdown_items.append(item_obj)
        if rounded_tot > 0:
            non_zero_items.append(item_obj)

    breakdown_items.sort(key=lambda x: x.total_nominal, reverse=True)
    non_zero_items.sort(key=lambda x: x.total_nominal, reverse=True)

    # 6. Belanja Stok Bahan Gudang pada rentang tanggal yang sama
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    bm_sum_res = await db.execute(
        select(func.sum(BarangMasukDetail.harga_total))
        .join(BarangMasuk, BarangMasukDetail.barang_masuk_id == BarangMasuk.id)
        .where(and_(BarangMasuk.waktu >= start_dt, BarangMasuk.waktu <= end_dt))
    )
    total_belanja_bahan = round(bm_sum_res.scalar() or Decimal('0'), 2)
    total_semua_pengeluaran = round(total_all + total_belanja_bahan, 2)

    combined_items = [
        KategoriBreakdownItem(
            kategori_id=it.kategori_id,
            nama_kategori=it.nama_kategori,
            total_nominal=it.total_nominal,
            persentase=(
                round((it.total_nominal / total_semua_pengeluaran) * Decimal('100'), 2)
                if total_semua_pengeluaran > 0
                else Decimal('0.00')
            ),
        )
        for it in non_zero_items
    ]
    if total_belanja_bahan > 0:
        combined_items.append(
            KategoriBreakdownItem(
                kategori_id="stok-gudang",
                nama_kategori="Belanja Stok Bahan (Gudang)",
                total_nominal=total_belanja_bahan,
                persentase=(
                    round((total_belanja_bahan / total_semua_pengeluaran) * Decimal('100'), 2)
                    if total_semua_pengeluaran > 0
                    else Decimal('0.00')
                ),
            )
        )
    combined_items.sort(key=lambda x: x.total_nominal, reverse=True)

    return PengeluaranBreakdownOut(
        filter=filter,
        periode_mulai=start_date,
        periode_selesai=end_date,
        total_pengeluaran=round(total_all, 2),
        total_belanja_bahan=total_belanja_bahan,
        total_semua_pengeluaran=total_semua_pengeluaran,
        breakdown=breakdown_items,
        items=non_zero_items,
        items_dengan_bahan=combined_items,
    )


def _resolve_pengeluaran_label(p: Pengeluaran, cat_map: dict[str, str]) -> str:
    if p.kategori_id:
        return cat_map.get(p.kategori_id, "Lainnya")
    nama = (p.nama_pengeluaran or "").strip()
    if nama:
        return nama
    ket = (p.keterangan or "").strip()
    if ket:
        return ket
    return "Pengeluaran Mendadak"


async def _serialize_pengeluaran(db: AsyncSession, items: List[Pengeluaran]) -> List[PengeluaranOut]:
    cat_res = await db.execute(select(KategoriPengeluaran))
    cat_map = {c.id: c.nama for c in cat_res.scalars().all()}
    out = []
    for p in items:
        pro_rata_harian: Optional[Decimal] = None
        jumlah_hari_bulan: Optional[int] = None
        if p.tipe == "bulanan" and p.bulan is not None:
            jumlah_hari_bulan = calendar.monthrange(p.bulan.year, p.bulan.month)[1]
            pro_rata_harian = (
                Decimal(str(p.nominal or 0)) / Decimal(jumlah_hari_bulan)
            ).quantize(Decimal("0.01"))
        out.append(
            PengeluaranOut(
                id=p.id,
                kategori_id=p.kategori_id,
                nama_pengeluaran=p.nama_pengeluaran,
                nama_kategori=_resolve_pengeluaran_label(p, cat_map),
                tipe=p.tipe,
                nominal=p.nominal,
                bulan=p.bulan,
                tanggal=p.tanggal,
                keterangan=p.keterangan,
                pro_rata_harian=pro_rata_harian,
                jumlah_hari_bulan=jumlah_hari_bulan,
                dicatat_oleh=p.dicatat_oleh,
                created_at=p.created_at,
            )
        )
    return out


@router.get("/pengeluaran", response_model=List[PengeluaranOut])
@router.get("/pengeluaran/", response_model=List[PengeluaranOut], include_in_schema=False)
async def list_pengeluaran(
    tipe: Optional[Literal['bulanan', 'mendadak', 'belanja_bahan']] = None,
    kategori_id: Optional[str] = None,
    include_barang_masuk: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    out: List[PengeluaranOut] = []

    if tipe != "belanja_bahan":
        stmt = select(Pengeluaran)
        if tipe:
            stmt = stmt.where(Pengeluaran.tipe == tipe)
        if kategori_id == MENDADAK_BREAKDOWN_ID:
            stmt = stmt.where(Pengeluaran.kategori_id.is_(None))
        elif kategori_id:
            stmt = stmt.where(Pengeluaran.kategori_id == kategori_id)
        stmt = stmt.order_by(Pengeluaran.created_at.desc())
        result = await db.execute(stmt)
        items = result.scalars().all()
        out.extend(await _serialize_pengeluaran(db, items))

    if (include_barang_masuk and not tipe and not kategori_id) or (tipe == "belanja_bahan" and not kategori_id):
        bm_rows = (
            await db.execute(
                select(BarangMasuk)
                .options(selectinload(BarangMasuk.details))
                .order_by(BarangMasuk.waktu.desc(), BarangMasuk.created_at.desc())
            )
        ).scalars().all()
        for bm in bm_rows:
            tot_bm = sum(
                (Decimal(str(d.harga_total or 0)) for d in bm.details),
                Decimal("0"),
            ).quantize(Decimal("0.01"))
            if tot_bm <= 0:
                continue
            note_txt = (bm.catatan or "Barang masuk gudang").strip()
            out.append(
                PengeluaranOut(
                    id=f"bm-{bm.id}",
                    kategori_id="stok-gudang",
                    nama_kategori="Belanja Stok Bahan (Gudang)",
                    tipe="belanja_bahan",
                    nominal=tot_bm,
                    bulan=None,
                    tanggal=bm.waktu.date() if bm.waktu else None,
                    keterangan=f"{note_txt} ({len(bm.details)} item bahan)",
                    pro_rata_harian=None,
                    jumlah_hari_bulan=None,
                    dicatat_oleh=bm.karyawan_id,
                    created_at=bm.waktu or bm.created_at,
                    sumber="barang_masuk",
                    jumlah_item=len(bm.details),
                    editable=False,
                )
            )

    out.sort(key=lambda x: x.created_at, reverse=True)
    return out


@router.post("/pengeluaran", response_model=PengeluaranOut)
@router.post("/pengeluaran/", response_model=PengeluaranOut, include_in_schema=False)
async def create_pengeluaran(
    data: PengeluaranCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    kat = None
    if data.kategori_id is not None:
        kat = await db.get(KategoriPengeluaran, data.kategori_id)
        if not kat:
            raise HTTPException(status_code=400, detail="Kategori pengeluaran tidak ditemukan")
    elif data.tipe == "bulanan":
        raise HTTPException(status_code=400, detail="Pengeluaran bulanan wajib memilih kategori pengeluaran")

    if data.tipe == "bulanan" and not data.bulan:
        raise HTTPException(status_code=400, detail="Pengeluaran tipe 'bulanan' wajib mengisi field bulan")
    if data.tipe == "mendadak" and not data.tanggal:
        raise HTTPException(status_code=400, detail="Pengeluaran tipe 'mendadak' wajib mengisi field tanggal")

    payload = data.model_dump() if hasattr(data, "model_dump") else data.dict()
    if data.tipe == "bulanan":
        current_month_start = now_local().date().replace(day=1)
        requested_month = data.bulan.replace(day=1)
        if (requested_month.year, requested_month.month) != (
            current_month_start.year,
            current_month_start.month,
        ):
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Pengeluaran bulanan hanya dapat dicatat untuk bulan berjalan "
                    f"({current_month_start.strftime('%Y-%m')})."
                ),
            )
        dup_res = await db.execute(
            select(Pengeluaran).where(
                and_(
                    Pengeluaran.tipe == "bulanan",
                    Pengeluaran.kategori_id == data.kategori_id,
                    extract("year", Pengeluaran.bulan) == current_month_start.year,
                    extract("month", Pengeluaran.bulan) == current_month_start.month,
                )
            )
        )
        if dup_res.scalars().first():
            kat_nama = kat.nama if kat else "kategori ini"
            raise HTTPException(
                status_code=409,
                detail=(
                    f"Pengeluaran bulanan '{kat_nama}' untuk bulan "
                    f"{current_month_start.strftime('%Y-%m')} sudah dicatat. "
                    f"Setiap kategori bulanan hanya dapat diinput 1 kali per bulan."
                ),
            )
        payload["bulan"] = current_month_start

    if payload.get("tipe") == "mendadak" and not payload.get("kategori_id"):
        if not payload.get("nama_pengeluaran"):
            payload["nama_pengeluaran"] = payload.get("keterangan")
    item = Pengeluaran(**payload, dicatat_oleh=current_user.id)
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return (await _serialize_pengeluaran(db, [item]))[0]


@router.put("/pengeluaran/{id}", response_model=PengeluaranOut)
async def update_pengeluaran(
    id: str,
    data: PengeluaranUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    item = await db.get(Pengeluaran, id)
    if not item:
        raise HTTPException(status_code=404, detail="Data pengeluaran tidak ditemukan")

    kat = None
    if data.kategori_id is not None:
        kat = await db.get(KategoriPengeluaran, data.kategori_id)
        if not kat:
            raise HTTPException(status_code=400, detail="Kategori pengeluaran tidak ditemukan")
        item.kategori_id = data.kategori_id
    elif item.kategori_id is not None:
        kat = await db.get(KategoriPengeluaran, item.kategori_id)

    if data.nama_pengeluaran is not None:
        item.nama_pengeluaran = data.nama_pengeluaran

    new_tipe = data.tipe or item.tipe
    new_bulan = data.bulan if data.bulan is not None else (item.bulan if new_tipe == 'bulanan' else None)
    new_tanggal = data.tanggal if data.tanggal is not None else (item.tanggal if new_tipe == 'mendadak' else None)

    if new_tipe == "bulanan":
        if not item.kategori_id:
            raise HTTPException(status_code=400, detail="Pengeluaran bulanan wajib memilih kategori pengeluaran")
        if not new_bulan:
            raise HTTPException(status_code=400, detail="Pengeluaran bulanan wajib mengisi bulan")
        normalized_bulan = new_bulan.replace(day=1)
        current_month_start = now_local().date().replace(day=1)
        changing_month = (
            item.tipe != "bulanan"
            or item.bulan is None
            or (normalized_bulan.year, normalized_bulan.month)
            != (item.bulan.year, item.bulan.month)
        )
        if changing_month and (normalized_bulan.year, normalized_bulan.month) != (
            current_month_start.year,
            current_month_start.month,
        ):
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Pengeluaran bulanan hanya dapat dicatat untuk bulan berjalan "
                    f"({current_month_start.strftime('%Y-%m')})."
                ),
            )
        dup_res = await db.execute(
            select(Pengeluaran).where(
                and_(
                    Pengeluaran.id != item.id,
                    Pengeluaran.tipe == "bulanan",
                    Pengeluaran.kategori_id == item.kategori_id,
                    extract("year", Pengeluaran.bulan) == normalized_bulan.year,
                    extract("month", Pengeluaran.bulan) == normalized_bulan.month,
                )
            )
        )
        if dup_res.scalars().first():
            kat_nama = kat.nama if kat else "kategori ini"
            raise HTTPException(
                status_code=409,
                detail=(
                    f"Pengeluaran bulanan '{kat_nama}' untuk bulan "
                    f"{normalized_bulan.strftime('%Y-%m')} sudah dicatat. "
                    f"Setiap kategori bulanan hanya dapat diinput 1 kali per bulan."
                ),
            )
        item.tipe = "bulanan"
        item.bulan = normalized_bulan
        item.tanggal = None
    else:
        if not new_tanggal:
            raise HTTPException(status_code=400, detail="Pengeluaran mendadak wajib mengisi tanggal")
        item.tipe = "mendadak"
        item.tanggal = new_tanggal
        item.bulan = None
        if not item.kategori_id and not (item.nama_pengeluaran or data.keterangan or item.keterangan):
            raise HTTPException(status_code=400, detail="Pengeluaran mendadak wajib mengisi nama/keperluan pengeluaran")

    if data.nominal is not None:
        item.nominal = data.nominal
    if data.keterangan is not None:
        item.keterangan = data.keterangan.strip() or None

    await db.commit()
    await db.refresh(item)
    return (await _serialize_pengeluaran(db, [item]))[0]


@router.delete("/pengeluaran/{id}")
async def delete_pengeluaran(
    id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    item = await db.get(Pengeluaran, id)
    if not item:
        raise HTTPException(status_code=404, detail="Data pengeluaran tidak ditemukan")
    await db.delete(item)
    await db.commit()
    return {"message": "Pengeluaran berhasil dihapus"}


@router.get("/hpp-menu", response_model=HppMenuReportOut)
async def get_hpp_menu_report(
    area: Optional[Literal['bar', 'kitchen']] = None,
    include_nonaktif: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"])),
):
    """
    Laporan HPP per cup/porsi vs Harga Jual menggunakan harga_rata_rata (AVG) bahan gudang terkini,
    disertai pemantauan harga beli masuk terakhir per bahan agar fluktuasi biaya dan profit terpantau.
    """
    menu_stmt = (
        select(Menu)
        .options(
            selectinload(Menu.kategori),
            selectinload(Menu.resep).selectinload(MenuResep.bahan),
        )
        .order_by(Menu.kode_menu.asc())
    )
    if not include_nonaktif:
        menu_stmt = menu_stmt.where(Menu.status_aktif == True)
    menus = (await db.execute(menu_stmt)).scalars().all()

    # Agregasi transaksi terjual (status='selesai') per menu_id
    sold_rows = (
        await db.execute(
            select(
                TransaksiDetail.menu_id,
                func.sum(TransaksiDetail.qty),
                func.sum(TransaksiDetail.qty * TransaksiDetail.hpp_satuan),
            )
            .join(Transaksi, TransaksiDetail.transaksi_id == Transaksi.id)
            .where(Transaksi.status == "selesai")
            .group_by(TransaksiDetail.menu_id)
        )
    ).all()
    sold_map = {}
    for m_id, tot_qty, tot_hpp in sold_rows:
        q = int(tot_qty or 0)
        avg_sold_hpp = (Decimal(str(tot_hpp or 0)) / Decimal(q)).quantize(Decimal("0.01")) if q > 0 else None
        sold_map[m_id] = (q, avg_sold_hpp)

    menu_items: List[MenuHppReportItemOut] = []
    bahan_menu_counts: dict[str, int] = {}

    for m in menus:
        kat_nama = m.kategori.nama if m.kategori else "Lainnya"
        area_prod = m.kategori.area_produksi if m.kategori else "bar"
        if area and area_prod != area:
            continue

        harga_jual = Decimal(str(m.harga or 0)).quantize(Decimal("0.01"))
        resep_list = list(m.resep or [])
        punya_resep = len(resep_list) > 0

        raw_subs = []
        hpp_raw = Decimal("0")
        for r in resep_list:
            b = r.bahan
            if not b:
                continue
            qty_pakai = Decimal(str(r.jumlah_terpakai or 0))
            avg_price = Decimal(str(b.harga_rata_rata or 0))
            sub_raw = qty_pakai * avg_price
            hpp_raw += sub_raw
            raw_subs.append((b, qty_pakai, avg_price, sub_raw))
            bahan_menu_counts[b.id] = bahan_menu_counts.get(b.id, 0) + 1

        resep_out: List[MenuHppBahanItemOut] = []
        for b, qty_pakai, avg_price, sub_raw in raw_subs:
            pct = (
                ((sub_raw / hpp_raw) * Decimal("100")).quantize(Decimal("0.01"))
                if hpp_raw > 0
                else Decimal("0.00")
            )
            resep_out.append(
                MenuHppBahanItemOut(
                    bahan_id=b.id,
                    nama_bahan=b.nama,
                    satuan=b.satuan,
                    area=getattr(b, "area", "semua") or "semua",
                    jumlah_terpakai=qty_pakai,
                    harga_rata_rata=avg_price.quantize(Decimal("0.01")),
                    subtotal_hpp=sub_raw.quantize(Decimal("0.01")),
                    persentase_kontribusi=pct,
                )
            )
        resep_out.sort(key=lambda x: x.subtotal_hpp, reverse=True)

        hpp_saat_ini = hpp_raw.quantize(Decimal("0.01"))
        laba_kotor = (harga_jual - hpp_saat_ini).quantize(Decimal("0.01"))
        margin_persen = (
            ((laba_kotor / harga_jual) * Decimal("100")).quantize(Decimal("0.01"))
            if harga_jual > 0
            else Decimal("0.00")
        )

        qty_terjual, hpp_sold = sold_map.get(m.id, (0, None))
        selisih_hpp = (
            (hpp_saat_ini - hpp_sold).quantize(Decimal("0.01"))
            if (hpp_sold is not None and punya_resep)
            else None
        )

        menu_items.append(
            MenuHppReportItemOut(
                menu_id=m.id,
                kode_menu=m.kode_menu,
                nama_menu=m.nama,
                kategori_nama=kat_nama,
                area_produksi=area_prod,
                status_aktif=bool(m.status_aktif),
                harga_jual=harga_jual,
                hpp_saat_ini=hpp_saat_ini,
                laba_kotor=laba_kotor,
                margin_persen=margin_persen,
                hpp_terjual_rata_rata=hpp_sold,
                selisih_hpp_vs_rata_terjual=selisih_hpp,
                qty_terjual=qty_terjual,
                punya_resep=punya_resep,
                resep_items=resep_out,
            )
        )

    # Monitor harga bahan baku: bandingkan harga_rata_rata (AVG) vs barang masuk terakhir
    bahan_stmt = select(Bahan).order_by(Bahan.nama.asc())
    if area:
        bahan_stmt = bahan_stmt.where(Bahan.area.in_([area, "semua"]))
    all_bahan = (await db.execute(bahan_stmt)).scalars().all()
    bahan_map = {b.id: b for b in all_bahan}

    bm_rows = (
        await db.execute(
            select(BarangMasukDetail, BarangMasuk.waktu)
            .join(BarangMasuk, BarangMasukDetail.barang_masuk_id == BarangMasuk.id)
            .order_by(BarangMasuk.waktu.desc(), BarangMasuk.created_at.desc())
        )
    ).all()
    latest_bm: dict[str, tuple[Decimal, datetime]] = {}
    for det, waktu in bm_rows:
        if det.bahan_id in latest_bm:
            continue
        b_obj = bahan_map.get(det.bahan_id)
        if not b_obj:
            continue
        isi = Decimal(str(b_obj.isi_per_kemasan or 1))
        total_kecil = Decimal(str(det.jumlah_kemasan_besar or 0)) * isi + Decimal(
            str(det.jumlah_satuan_kecil or 0)
        )
        if total_kecil > 0:
            unit_price = (Decimal(str(det.harga_total or 0)) / total_kecil).quantize(Decimal("0.01"))
            latest_bm[det.bahan_id] = (unit_price, waktu)

    bahan_monitor: List[BahanHargaMonitorOut] = []
    for b in all_bahan:
        avg_now = Decimal(str(b.harga_rata_rata or 0)).quantize(Decimal("0.01"))
        last_info = latest_bm.get(b.id)
        last_price = last_info[0] if last_info else None
        last_date = last_info[1] if last_info else None
        diff = (last_price - avg_now).quantize(Decimal("0.01")) if last_price is not None else None
        bahan_monitor.append(
            BahanHargaMonitorOut(
                bahan_id=b.id,
                nama_bahan=b.nama,
                satuan=b.satuan,
                area=getattr(b, "area", "semua") or "semua",
                harga_rata_rata=avg_now,
                harga_beli_terakhir=last_price,
                selisih_terakhir_vs_avg=diff,
                tanggal_beli_terakhir=last_date,
                jumlah_menu_terkait=bahan_menu_counts.get(b.id, 0),
            )
        )

    beresep = [item for item in menu_items if item.punya_resep]
    avg_margin = (
        (sum((i.margin_persen for i in beresep), Decimal("0")) / Decimal(len(beresep))).quantize(
            Decimal("0.01")
        )
        if beresep
        else Decimal("0.00")
    )
    margin_tipis_cnt = sum(1 for i in beresep if i.margin_persen < Decimal("30"))

    return HppMenuReportOut(
        total_menu=len(menu_items),
        total_menu_beresep=len(beresep),
        total_menu_tanpa_resep=len(menu_items) - len(beresep),
        rata_rata_margin_persen=avg_margin,
        jumlah_menu_margin_tipis=margin_tipis_cnt,
        items=menu_items,
        bahan_monitor=bahan_monitor,
    )
