from datetime import datetime
from typing import List
from decimal import Decimal
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.core.deps import get_db, get_current_user
from app.models.transaksi import Transaksi, TransaksiDetail
from app.models.master_data import Menu
from app.models.jadwal import JadwalShift
from app.models.stok import StokOpname
from app.models.karyawan import Karyawan
from app.schemas.transaksi import TransaksiCreate, TransaksiOut, ActiveShiftSummaryOut

router = APIRouter()

@router.post("/", response_model=TransaksiOut)
async def create_transaksi(
    data: TransaksiCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Input transaksi POS baru oleh kasir
    Validasi area_kerja: kasir_id / shift WAJIB memilik area_kerja='kasir' (FIX-2)
    """
    # 1. Cek jadwal shift aktif & validasi area_kerja
    shift = await db.get(JadwalShift, data.jadwal_shift_id)
    if not shift:
        raise HTTPException(status_code=404, detail="Jadwal shift tidak ditemukan")

    if shift.area_kerja != "kasir":
        raise HTTPException(
            status_code=400,
            detail=f"Transaksi POS hanya dapat diinput pada shift dengan area_kerja 'kasir' (area_kerja shift saat ini: '{shift.area_kerja}')."
        )

    # 2. Cek apakah shift ini sudah ditutup dengan stok opname akhir_shift
    opname_end = await db.execute(
        select(StokOpname).where(
            and_(
                StokOpname.jadwal_shift_id == data.jadwal_shift_id,
                StokOpname.tipe == "akhir_shift"
            )
        )
    )
    if opname_end.scalars().first():
        raise HTTPException(
            status_code=400,
            detail="Shift ini sudah ditutup (opname akhir shift telah disubmit). Tidak dapat membuat transaksi baru."
        )

    # 3. Generate nomor transaksi unik (misal: TRX-YYYYMMDD-XXXX)
    date_str = datetime.utcnow().strftime("%Y%m%d")
    random_code = str(uuid.uuid4().hex[:6]).upper()
    nomor_trx = f"TRX-{date_str}-{random_code}"

    # 4. Hitung detail & total
    total_harga = Decimal("0")
    details_to_add = []

    for item in data.details:
        menu_item = await db.get(Menu, item.menu_id)
        if not menu_item:
            raise HTTPException(status_code=404, detail=f"Menu ID {item.menu_id} tidak ditemukan")

        subtotal = menu_item.harga * item.qty
        total_harga += subtotal

        trx_detail = TransaksiDetail(
            menu_id=item.menu_id,
            qty=item.qty,
            harga_satuan=menu_item.harga,
            catatan=item.catatan,
            subtotal=subtotal,
            status_item="menunggu"
        )
        details_to_add.append(trx_detail)

    # Validasi pembayaran cash vs qris
    kembalian = None
    if data.metode_bayar == "cash":
        if not data.uang_diterima or data.uang_diterima < total_harga:
            raise HTTPException(status_code=400, detail="Uang diterima kurang dari total harga")
        kembalian = data.uang_diterima - total_harga
    elif data.metode_bayar == "qris":
        if not data.foto_bukti_qris:
            raise HTTPException(status_code=400, detail="Foto bukti pembayaran QRIS wajib diunggah")

    new_trx = Transaksi(
        jadwal_shift_id=data.jadwal_shift_id,
        kasir_id=current_user.id,
        nomor_transaksi=nomor_trx,
        metode_bayar=data.metode_bayar,
        total_harga=total_harga,
        uang_diterima=data.uang_diterima,
        kembalian=kembalian,
        foto_bukti_qris=data.foto_bukti_qris,
        status="selesai",
        details=details_to_add
    )

    db.add(new_trx)
    await db.commit()
    await db.refresh(new_trx)
    return new_trx

@router.post("/{transaksi_id}/void", response_model=TransaksiOut)
async def void_transaksi(
    transaksi_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    ENFORCEMENT VOID TRANSAKSI:
    Kasir hanya boleh membatalkan transaksi pada shift aktif miliknya SEBELUM
    stok_opname akhir_shift untuk shift terkait disubmit.
    Validasi ini di-enforce secara ketat di level API.
    """
    trx = await db.get(Transaksi, transaksi_id)
    if not trx:
        raise HTTPException(status_code=404, detail="Transaksi tidak ditemukan")

    if trx.status == "dibatalkan":
        raise HTTPException(status_code=400, detail="Transaksi ini sudah dibatalkan sebelumnya")

    # Syarat 1: Hanya kasir pembuat transaksi atau Admin/Owner yang boleh cancel
    if current_user.role == "karyawan" and trx.kasir_id != current_user.id:
        raise HTTPException(status_code=403, detail="Anda hanya dapat membatalkan transaksi buatan sendiri")

    # Syarat 2: VALIDASI BLOCKING API - Cek Stok Opname akhir_shift
    opname_end = await db.execute(
        select(StokOpname).where(
            and_(
                StokOpname.jadwal_shift_id == trx.jadwal_shift_id,
                StokOpname.tipe == "akhir_shift"
            )
        )
    )
    if opname_end.scalars().first():
        raise HTTPException(
            status_code=400,
            detail="Transaksi tidak dapat dibatalkan karena stok opname akhir shift terkait telah disubmit (shift telah terkunci)."
        )

    trx.status = "dibatalkan"
    await db.commit()
    await db.refresh(trx)
    return trx

@router.get("/shift-aktif/laporan", response_model=ActiveShiftSummaryOut)
async def get_active_shift_report(
    jadwal_shift_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    LAPORAN SHIFT AKTIF KARYAWAN:
    Read-only query on-demand dari tabel transaksi & detail WHERE jadwal_shift_id = shift aktif
    untuk sanity check mandiri kasir sebelum submit opname akhir shift.
    """
    shift = await db.get(JadwalShift, jadwal_shift_id)
    if not shift:
        raise HTTPException(status_code=404, detail="Jadwal shift tidak ditemukan")

    # Ambil transaksi berstatus selesai pada shift ini
    result = await db.execute(
        select(Transaksi).where(
            and_(
                Transaksi.jadwal_shift_id == jadwal_shift_id,
                Transaksi.status == "selesai"
            )
        )
    )
    transactions = result.scalars().all()

    total_trx = len(transactions)
    total_penjualan = Decimal("0")
    total_cash = Decimal("0")
    total_qris = Decimal("0")

    for t in transactions:
        total_penjualan += t.total_harga
        if t.metode_bayar == "cash":
            total_cash += t.total_harga
        elif t.metode_bayar == "qris":
            total_qris += t.total_harga

    # Cek apakah shift sudah terkunci opname akhir
    opname_end = await db.execute(
        select(StokOpname).where(
            and_(
                StokOpname.jadwal_shift_id == jadwal_shift_id,
                StokOpname.tipe == "akhir_shift"
            )
        )
    )
    is_locked = bool(opname_end.scalars().first())

    return ActiveShiftSummaryOut(
        jadwal_shift_id=shift.id,
        karyawan_id=shift.karyawan_id,
        tanggal=shift.tanggal.isoformat(),
        shift=shift.shift,
        total_transaksi=total_trx,
        total_penjualan=total_penjualan,
        total_cash=total_cash,
        total_qris=total_qris,
        shift_locked_by_opname=is_locked
    )
