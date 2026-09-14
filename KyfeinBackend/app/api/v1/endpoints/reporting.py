import calendar
from datetime import date, datetime
from decimal import Decimal
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, extract, and_

from app.core.deps import get_db, require_roles
from app.models.transaksi import Transaksi, TransaksiDetail
from app.models.master_data import Menu, MenuResep, KategoriPengeluaran
from app.models.pengeluaran import Pengeluaran
from app.models.karyawan import Karyawan
from app.schemas.reporting import PengeluaranCreate, PengeluaranOut, DailyProfitReportOut

router = APIRouter()

@router.get("/profit-harian", response_model=DailyProfitReportOut)
async def get_daily_profit_report(
    tanggal: date = Query(default=date.today()),
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    """
    FORMULA PROFIT HARIAN (Rencana 3.6):
    Profit = Penjualan Hari Itu
           - HPP (on-demand resep x qty terjual)
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

    # 2. HPP Teoritis On-Demand: sum(menu_resep.jumlah_terpakai * harga_bahan) for items sold on that day
    # Untuk kesederhanaan baseline, jika harga bahan tidak disimpan di tabel bahan, HPP dihitung dari resep x snapshot/rasio
    # Query transaksi_detail pada hari ini
    details_res = await db.execute(
        select(TransaksiDetail, Menu)
        .join(Transaksi, TransaksiDetail.transaksi_id == Transaksi.id)
        .join(Menu, TransaksiDetail.menu_id == Menu.id)
        .where(
            and_(
                Transaksi.waktu_transaksi >= start_dt,
                Transaksi.waktu_transaksi <= end_dt,
                Transaksi.status == "selesai"
            )
        )
    )
    sold_items = details_res.all()

    total_hpp = Decimal("0")
    for detail, menu_item in sold_items:
        # Fetch resep
        resep_res = await db.execute(
            select(MenuResep).where(MenuResep.menu_id == menu_item.id)
        )
        reseps = resep_res.scalars().all()
        # Jika resep terdaftar, hitung estimasi HPP (default 40% dari harga menu jika harga bahan belum diset)
        menu_hpp = Decimal("0")
        for r in reseps:
            # Asumsi takaran resep x 1000 per unit (dihitung on-demand)
            menu_hpp += Decimal("1000.00") * r.jumlah_terpakai
        if not reseps:
            menu_hpp = menu_item.harga * Decimal("0.35") # Fallback HPP teoritis
        total_hpp += menu_hpp * detail.qty

    # 3. Pengeluaran Bulanan (Pro-Rata per hari)
    # Filter pengeluaran tipe='bulanan' untuk bulan & tahun tanggal terkait
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
        net_profit_harian=net_profit
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
