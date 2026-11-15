import calendar
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import List, Optional, Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, extract, and_

from app.core.deps import get_db, require_roles
from app.core.utils import now_local
from app.models.transaksi import Transaksi, TransaksiDetail
from app.models.master_data import Menu, MenuResep, Bahan, KategoriPengeluaran
from app.models.pengeluaran import Pengeluaran
from app.models.karyawan import Karyawan
from app.models.stok import BarangMasuk, BarangKeluar, StokOpname, StokGudang, StokTitik
from app.models.absensi import Absensi, IzinTelat, IzinTidakMasuk
from app.models.jadwal import JadwalShift
from app.schemas.reporting import (
    PengeluaranCreate, PengeluaranUpdate, PengeluaranOut,
    DailyProfitReportOut, PeriodProfitReportOut,
    KategoriBreakdownItem, PengeluaranBreakdownOut,
    DashboardOverviewOut,
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

    # 6. Net Profit
    net_profit = total_penjualan - total_hpp - pengeluaran_bulanan_pro_rata - pengeluaran_mendadak

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
        if (tot_gudang + tot_titik) <= Decimal(str(b.stok_minimum or 0)):
            jumlah_stok_menipis += 1

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
        "pengeluaran_bulanan_pro_rata": round(pengeluaran_bulanan_pro_rata, 2),
        "pengeluaran_mendadak": round(pengeluaran_mendadak, 2),
        "net_profit": round(net_profit, 2),
        "menu_tanpa_resep": menu_tanpa_resep,
        "jumlah_barang_masuk": jumlah_barang_masuk,
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
        pengeluaran_bulanan_pro_rata=res["pengeluaran_bulanan_pro_rata"],
        pengeluaran_mendadak=res["pengeluaran_mendadak"],
        net_profit_harian=res["net_profit"],
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
        pengeluaran_bulanan_pro_rata=res["pengeluaran_bulanan_pro_rata"],
        pengeluaran_mendadak=res["pengeluaran_mendadak"],
        net_profit=res["net_profit"],
        menu_tanpa_resep=res["menu_tanpa_resep"],
        jumlah_barang_masuk=res["jumlah_barang_masuk"],
        jumlah_barang_keluar=res["jumlah_barang_keluar"],
        jumlah_sesi_opname=res["jumlah_sesi_opname"],
        jumlah_stok_menipis=res["jumlah_stok_menipis"],
        total_hadir=res["total_hadir"],
        total_tepat_waktu=res["total_tepat_waktu"],
        total_terlambat=res["total_terlambat"],
        total_izin_telat=res["total_izin_telat"],
        total_izin_tidak_masuk=res["total_izin_tidak_masuk"],
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
        pengeluaran_bulanan_pro_rata=kpi["pengeluaran_bulanan_pro_rata"],
        pengeluaran_mendadak=kpi["pengeluaran_mendadak"],
        total_pengeluaran=total_pengeluaran,
        net_profit=net_profit,
        margin_profit_persen=margin_pct,
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

    # 3. Mendadak expenses within date range
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
        cat_id = p.kategori_id
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

    return PengeluaranBreakdownOut(
        filter=filter,
        periode_mulai=start_date,
        periode_selesai=end_date,
        total_pengeluaran=round(total_all, 2),
        breakdown=breakdown_items,
        items=non_zero_items,
    )


async def _serialize_pengeluaran(db: AsyncSession, items: List[Pengeluaran]) -> List[PengeluaranOut]:
    cat_res = await db.execute(select(KategoriPengeluaran))
    cat_map = {c.id: c.nama for c in cat_res.scalars().all()}
    out = []
    for p in items:
        out.append(
            PengeluaranOut(
                id=p.id,
                kategori_id=p.kategori_id,
                nama_kategori=cat_map.get(p.kategori_id, "Lainnya"),
                tipe=p.tipe,
                nominal=p.nominal,
                bulan=p.bulan,
                tanggal=p.tanggal,
                keterangan=p.keterangan,
                dicatat_oleh=p.dicatat_oleh,
                created_at=p.created_at,
            )
        )
    return out


@router.get("/pengeluaran", response_model=List[PengeluaranOut])
@router.get("/pengeluaran/", response_model=List[PengeluaranOut], include_in_schema=False)
async def list_pengeluaran(
    tipe: Optional[Literal['bulanan', 'mendadak']] = None,
    kategori_id: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    stmt = select(Pengeluaran)
    if tipe:
        stmt = stmt.where(Pengeluaran.tipe == tipe)
    if kategori_id:
        stmt = stmt.where(Pengeluaran.kategori_id == kategori_id)
    stmt = stmt.order_by(Pengeluaran.created_at.desc())
    result = await db.execute(stmt)
    items = result.scalars().all()
    return await _serialize_pengeluaran(db, items)


@router.post("/pengeluaran", response_model=PengeluaranOut)
@router.post("/pengeluaran/", response_model=PengeluaranOut, include_in_schema=False)
async def create_pengeluaran(
    data: PengeluaranCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    kat = await db.get(KategoriPengeluaran, data.kategori_id)
    if not kat:
        raise HTTPException(status_code=400, detail="Kategori pengeluaran tidak ditemukan")

    if data.tipe == "bulanan" and not data.bulan:
        raise HTTPException(status_code=400, detail="Pengeluaran tipe 'bulanan' wajib mengisi field bulan")
    if data.tipe == "mendadak" and not data.tanggal:
        raise HTTPException(status_code=400, detail="Pengeluaran tipe 'mendadak' wajib mengisi field tanggal")

    payload = data.model_dump() if hasattr(data, "model_dump") else data.dict()
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

    if data.kategori_id is not None:
        kat = await db.get(KategoriPengeluaran, data.kategori_id)
        if not kat:
            raise HTTPException(status_code=400, detail="Kategori pengeluaran tidak ditemukan")
        item.kategori_id = data.kategori_id

    new_tipe = data.tipe or item.tipe
    new_bulan = data.bulan if data.bulan is not None else (item.bulan if new_tipe == 'bulanan' else None)
    new_tanggal = data.tanggal if data.tanggal is not None else (item.tanggal if new_tipe == 'mendadak' else None)

    if new_tipe == "bulanan":
        if not new_bulan:
            raise HTTPException(status_code=400, detail="Pengeluaran bulanan wajib mengisi bulan")
        item.tipe = "bulanan"
        item.bulan = new_bulan
        item.tanggal = None
    else:
        if not new_tanggal:
            raise HTTPException(status_code=400, detail="Pengeluaran mendadak wajib mengisi tanggal")
        item.tipe = "mendadak"
        item.tanggal = new_tanggal
        item.bulan = None

    if data.nominal is not None:
        item.nominal = data.nominal
    if data.keterangan is not None:
        item.keterangan = data.keterangan

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
