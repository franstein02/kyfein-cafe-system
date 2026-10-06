import calendar
from datetime import date, datetime
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
from app.schemas.reporting import (
    PengeluaranCreate, PengeluaranOut, DailyProfitReportOut,
    KategoriBreakdownItem, PengeluaranBreakdownOut
)

router = APIRouter()

@router.get("/profit-harian", response_model=DailyProfitReportOut)
async def get_daily_profit_report(
    tanggal: Optional[date] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    if not tanggal:
        tanggal = now_local().date()
    """
    FORMULA PROFIT HARIAN:
    Profit = Penjualan Hari Itu
           - HPP (on-demand sum(menu_resep.jumlah_terpakai * bahan.harga_rata_rata) * qty terjual)
           - Sum(Pengeluaran Bulanan / jumlah_hari_di_bulan_itu)
           - Sum(Pengeluaran Mendadak pada tanggal_itu)
    """
    # 1. Total Penjualan Hari Itu (Transaksi status='selesai')
    start_dt = datetime.combine(tanggal, datetime.min.time())
    end_dt = datetime.combine(tanggal, datetime.max.time())

    trx_res = await db.execute(
        select(func.sum(Transaksi.total_harga)).where(
            and_(
                Transaksi.waktu_transaksi >= start_dt,
                Transaksi.waktu_transaksi <= end_dt,
                Transaksi.status == "selesai"
            )
        )
    )
    total_penjualan = trx_res.scalar() or Decimal("0")

    # 2. HPP Snapshot: sum(hpp_satuan * qty) for completed transactions on that day
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

    # Distinct menu items sold on that day to check menu_tanpa_resep
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

    # 3. Pengeluaran Bulanan (Pro-Rata per hari)
    year = tanggal.year
    month = tanggal.month
    days_in_month = calendar.monthrange(year, month)[1]

    bulanan_res = await db.execute(
        select(func.sum(Pengeluaran.nominal)).where(
            and_(
                Pengeluaran.tipe == "bulanan",
                extract("year", Pengeluaran.bulan) == year,
                extract("month", Pengeluaran.bulan) == month
            )
        )
    )
    total_bulanan_month = bulanan_res.scalar() or Decimal("0")
    pengeluaran_bulanan_harian = total_bulanan_month / Decimal(str(days_in_month))

    # 4. Pengeluaran Mendadak (Exact Date)
    mendadak_res = await db.execute(
        select(func.sum(Pengeluaran.nominal)).where(
            and_(
                Pengeluaran.tipe == "mendadak",
                Pengeluaran.tanggal == tanggal
            )
        )
    )
    pengeluaran_mendadak = mendadak_res.scalar() or Decimal("0")

    # 5. Net Profit Harian
    net_profit = total_penjualan - total_hpp - pengeluaran_bulanan_harian - pengeluaran_mendadak

    return DailyProfitReportOut(
        tanggal=tanggal.isoformat(),
        total_penjualan=total_penjualan,
        total_hpp_teoritis=total_hpp,
        pengeluaran_bulanan_pro_rata=pengeluaran_bulanan_harian,
        pengeluaran_mendadak=pengeluaran_mendadak,
        net_profit_harian=net_profit,
        menu_tanpa_resep=menu_tanpa_resep
    )

@router.get("/pengeluaran/breakdown", response_model=PengeluaranBreakdownOut)
async def get_pengeluaran_breakdown(
    filter: Literal['harian', 'range', 'bulanan', 'tahunan'],
    tanggal: Optional[date] = None,
    tanggal_mulai: Optional[date] = None,
    tanggal_selesai: Optional[date] = None,
    bulan: Optional[int] = Query(None, ge=1, le=12),
    tahun: Optional[int] = Query(None, ge=2000, le=2100),
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    """
    Breakdown pengeluaran (mendadak + pro-rata bulanan) per kategori untuk periode yang diminta.
    """
    # 1. Determine date range
    if filter == 'harian':
        if not tanggal:
            raise HTTPException(status_code=400, detail="Tanggal wajib diisi untuk filter harian")
        start_date = tanggal
        end_date = tanggal
    elif filter == 'range':
        if not tanggal_mulai or not tanggal_selesai:
            raise HTTPException(status_code=400, detail="Tanggal mulai dan tanggal selesai wajib diisi untuk filter range")
        if tanggal_mulai > tanggal_selesai:
            raise HTTPException(status_code=400, detail="Tanggal mulai tidak boleh setelah tanggal selesai")
        start_date = tanggal_mulai
        end_date = tanggal_selesai
    elif filter == 'bulanan':
        if not bulan or not tahun:
            raise HTTPException(status_code=400, detail="Bulan dan tahun wajib diisi untuk filter bulanan")
        start_date = date(tahun, bulan, 1)
        last_day = calendar.monthrange(tahun, bulan)[1]
        end_date = date(tahun, bulan, last_day)
    elif filter == 'tahunan':
        if not tahun:
            raise HTTPException(status_code=400, detail="Tahun wajib diisi untuk filter tahunan")
        start_date = date(tahun, 1, 1)
        end_date = date(tahun, 12, 31)

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
    breakdown_items = []
    total_all = Decimal('0')
    for cat_id, tot in cat_totals.items():
        rounded_tot = round(tot, 2)
        total_all += rounded_tot
        breakdown_items.append(
            KategoriBreakdownItem(
                kategori_id=cat_id,
                nama_kategori=cat_name_map.get(cat_id, "Lainnya"),
                total_nominal=rounded_tot
            )
        )

    breakdown_items.sort(key=lambda x: x.total_nominal, reverse=True)

    return PengeluaranBreakdownOut(
        filter=filter,
        periode_mulai=start_date,
        periode_selesai=end_date,
        total_pengeluaran=round(total_all, 2),
        breakdown=breakdown_items
    )

@router.get("/pengeluaran", response_model=List[PengeluaranOut])
async def list_pengeluaran(
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    result = await db.execute(select(Pengeluaran).order_by(Pengeluaran.created_at.desc()))
    return result.scalars().all()

@router.post("/pengeluaran", response_model=PengeluaranOut)
async def create_pengeluaran(
    data: PengeluaranCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    if data.tipe == "bulanan" and not data.bulan:
        raise HTTPException(status_code=400, detail="Pengeluaran tipe 'bulanan' wajib mengisi field bulan")
    if data.tipe == "mendadak" and not data.tanggal:
        raise HTTPException(status_code=400, detail="Pengeluaran tipe 'mendadak' wajib mengisi field tanggal")

    item = Pengeluaran(**data.dict(), dicatat_oleh=current_user.id)
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item

