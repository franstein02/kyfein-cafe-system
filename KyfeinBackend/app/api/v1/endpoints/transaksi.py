from datetime import datetime, date, time
from typing import List, Optional
from decimal import Decimal
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from sqlalchemy.orm import selectinload

from app.core.deps import get_db, get_current_user
from app.core.utils import now_local
from app.core.foto_helper import validate_and_claim_foto
from app.core.transaksi_helper import is_transaksi_locked, hitung_hpp_satuan
from app.core.firebase_config import send_push_notification
from app.models.transaksi import Transaksi, TransaksiDetail
from app.models.master_data import Menu, KategoriMenu
from app.models.jadwal import JadwalShift
from app.models.stok import StokOpname
from app.models.absensi import Absensi
from app.models.karyawan import Karyawan
from app.schemas.transaksi import TransaksiCreate, TransaksiOut, ActiveShiftSummaryOut
from app.api.v1.endpoints.kds import kds_manager
from app.services.jadwal_service import get_shift_berjalan

router = APIRouter()

@router.get("", response_model=List[TransaksiOut])
@router.get("/", response_model=List[TransaksiOut], include_in_schema=False)
async def list_transaksi(
    tanggal: Optional[date] = None,
    status: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    List riwayat transaksi POS.
    """
    query = (
        select(Transaksi)
        .options(
            selectinload(Transaksi.details).selectinload(TransaksiDetail.menu),
            selectinload(Transaksi.kasir)
        )
        .order_by(Transaksi.created_at.desc())
    )
    if tanggal:
        start_dt = datetime.combine(tanggal, time.min)
        end_dt = datetime.combine(tanggal, time.max)
        query = query.where(and_(Transaksi.waktu_transaksi >= start_dt, Transaksi.waktu_transaksi <= end_dt))
    if status:
        query = query.where(Transaksi.status == status)
    result = await db.execute(query)
    return result.scalars().all()

@router.post("", response_model=TransaksiOut)
@router.post("/", response_model=TransaksiOut, include_in_schema=False)
async def create_transaksi(
    data: TransaksiCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Input transaksi POS baru oleh kasir / admin (mendukung mode testing langsung):
    - Jika user belum masuk jadwal shift, otomatis gunakan / buatkan shift testing hari ini
    - Menyimpan transaksi dan detailnya ke database secara persisten
    """
    now = now_local()
    today = now.date()

    # 1. Cek shift aktif / testing shift
    shift = None
    if data.jadwal_shift_id:
        shift = await db.get(JadwalShift, data.jadwal_shift_id)

    if not shift:
        active_shift = await get_shift_berjalan(db, current_user.id, now)
        if active_shift:
            shift = active_shift

    if not shift:
        # Cari jadwal shift kasir hari ini
        shift_q = select(JadwalShift).where(
            and_(
                JadwalShift.tanggal == today,
                JadwalShift.area_kerja == 'kasir'
            )
        )
        shift_res = await db.execute(shift_q)
        shift = shift_res.scalars().first()

    if not shift:
        # Fallback 1: Shift milik user hari ini
        user_shift_q = select(JadwalShift).where(
            and_(
                JadwalShift.tanggal == today,
                JadwalShift.karyawan_id == current_user.id
            )
        )
        user_res = await db.execute(user_shift_q)
        shift = user_res.scalars().first()

    if not shift:
        # Fallback 2: Shift apapun hari ini
        any_shift_q = select(JadwalShift).where(JadwalShift.tanggal == today)
        any_res = await db.execute(any_shift_q)
        shift = any_res.scalars().first()

    if not shift:
        test_shift_id = f"shift-kasir-{today.strftime('%Y%m%d')}"
        shift = await db.get(JadwalShift, test_shift_id)
        if not shift:
            # Auto-create shift kasir untuk hari ini agar testing transaksi POS dapat langsung berjalan
            shift = JadwalShift(
                id=test_shift_id,
                karyawan_id=current_user.id,
                tanggal=today,
                shift='shift_1',
                area_kerja='kasir',
                jam_mulai=time(0, 0),
                jam_selesai=time(23, 59, 59),
                dibuat_oleh=current_user.id,
                created_at=now,
                updated_at=now
            )
            db.add(shift)
            await db.flush()

    # Cek apakah transaksi terkunci (hanya jika sudah opname akhir_shift selesai)
    if await is_transaksi_locked(db, shift.id):
        raise HTTPException(
            status_code=403,
            detail="Transaksi terkunci untuk shift ini (opname akhir_shift selesai / shift selesai)."
        )

    # 5. Generate nomor transaksi unik (TRX-YYYYMMDD-XXXX)
    date_str = now_local().strftime("%Y%m%d")
    random_code = str(uuid.uuid4().hex[:6]).upper()
    nomor_trx = f"TRX-{date_str}-{random_code}"

    # 6. Hitung detail & total
    total_harga = Decimal("0")
    details_to_add = []
    kds_items = []

    for item in data.details:
        menu_item = await db.get(Menu, item.menu_id)
        if not menu_item:
            raise HTTPException(status_code=404, detail=f"Menu ID {item.menu_id} tidak ditemukan")

        subtotal = menu_item.harga * item.qty
        total_harga += subtotal

        hpp_satuan = await hitung_hpp_satuan(db, item.menu_id)

        trx_detail = TransaksiDetail(
            menu_id=item.menu_id,
            qty=item.qty,
            harga_satuan=menu_item.harga,
            hpp_satuan=hpp_satuan,
            catatan=item.catatan,
            subtotal=subtotal,
            status_item="menunggu"
        )
        details_to_add.append(trx_detail)

        kat = await db.get(KategoriMenu, menu_item.kategori_id) if menu_item.kategori_id else None
        if kat and kat.area_produksi in ["kitchen", "bar"]:
            kds_items.append({
                "detail_id": trx_detail.id,
                "menu_id": menu_item.id,
                "nama_menu": menu_item.nama,
                "qty": item.qty,
                "catatan": item.catatan,
                "area_produksi": kat.area_produksi
            })

    # Validasi pembayaran cash vs qris
    kembalian = None
    if data.metode_bayar == "cash":
        if not data.uang_diterima or data.uang_diterima < total_harga:
            raise HTTPException(status_code=400, detail="Uang diterima kurang dari total harga")
        kembalian = data.uang_diterima - total_harga
    elif data.metode_bayar == "qris":
        await validate_and_claim_foto(db, data.foto_bukti_qris_id, current_user.id, "qris", required=True)

    new_trx = Transaksi(
        jadwal_shift_id=shift.id,
        kasir_id=current_user.id,
        nomor_transaksi=nomor_trx,
        metode_bayar=data.metode_bayar,
        total_harga=total_harga,
        uang_diterima=data.uang_diterima,
        kembalian=kembalian,
        foto_bukti_qris_id=data.foto_bukti_qris_id,
        status="selesai",
        details=details_to_add
    )

    db.add(new_trx)
    await db.commit()
    await db.refresh(new_trx)

    if current_user.fcm_token:
        import asyncio
        asyncio.create_task(
            asyncio.to_thread(
                send_push_notification,
                fcm_token=current_user.fcm_token,
                title="Transaksi Berhasil ☕",
                body=f"Transaksi {nomor_trx} senilai Rp{total_harga:,.0f} telah berhasil dicatat.",
                data={"transaksi_id": str(new_trx.id), "type": "transaksi"}
            )
        )

    # Broadcast KDS Realtime Event
    for kds in kds_items:
        message = {
            "transaksi_id": new_trx.id,
            "nomor_transaksi": new_trx.nomor_transaksi,
            "detail_id": kds["detail_id"],
            "menu_id": kds["menu_id"],
            "nama_menu": kds["nama_menu"],
            "qty": kds["qty"],
            "catatan": kds["catatan"],
            "status_item": "menunggu",
            "waktu": new_trx.created_at.isoformat()
        }
        await kds_manager.broadcast_order(kds["area_produksi"], message)

    res = await db.execute(
        select(Transaksi)
        .options(
            selectinload(Transaksi.details).selectinload(TransaksiDetail.menu),
            selectinload(Transaksi.kasir)
        )
        .where(Transaksi.id == new_trx.id)
    )
    return res.scalar_one()

@router.put("/{transaksi_id}/cancel", response_model=TransaksiOut)
@router.post("/{transaksi_id}/void", response_model=TransaksiOut)
async def cancel_transaksi(
    transaksi_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    CANCEL TRANSAKSI:
    - Kasir hanya boleh cancel transaksi buatan sendiri pada shift aktif miliknya SEBELUM terkunci.
    - Admin juga ditolak dengan status 403 setelah transaksi terkunci.
    - Menolak cancel transaksi kasir lain dengan status 403.
    """
    trx = await db.get(Transaksi, transaksi_id)
    if not trx:
        raise HTTPException(status_code=404, detail="Transaksi tidak ditemukan")

    shift = await db.get(JadwalShift, trx.jadwal_shift_id)
    if not shift:
        raise HTTPException(status_code=404, detail="Jadwal shift transaksi tidak ditemukan")

    # 1. Lock Check (Terkunci -> 403 untuk SEMUA role, termasuk admin)
    if await is_transaksi_locked(db, trx.jadwal_shift_id):
        raise HTTPException(
            status_code=403,
            detail="Transaksi tidak dapat dibatalkan karena shift sudah terkunci (opname akhir_shift selesai / shift selesai)."
        )

    # 2. Authorization Check (Kasir hanya boleh cancel transaksi buatan sendiri di shift miliknya)
    if current_user.role == "karyawan":
        now = now_local()
        active_shift = await get_shift_berjalan(db, current_user.id, now)
        if trx.kasir_id != current_user.id or not active_shift or shift.id != active_shift.id:
            raise HTTPException(
                status_code=403,
                detail="Anda hanya dapat membatalkan transaksi buatan sendiri pada shift aktif milik Anda."
            )

    if trx.status == "dibatalkan":
        raise HTTPException(status_code=400, detail="Transaksi ini sudah dibatalkan sebelumnya")

    trx.status = "dibatalkan"
    await db.commit()

    res = await db.execute(
        select(Transaksi)
        .options(
            selectinload(Transaksi.details).selectinload(TransaksiDetail.menu),
            selectinload(Transaksi.kasir)
        )
        .where(Transaksi.id == trx.id)
    )
    return res.scalar_one()

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

    now = now_local()
    active_shift = await get_shift_berjalan(db, shift.karyawan_id, now)
    
    if not active_shift or shift.id != active_shift.id:
        raise HTTPException(
            status_code=400,
            detail="Laporan shift aktif hanya untuk shift yang sedang berjalan"
        )

    if shift.karyawan_id != current_user.id and current_user.role == "karyawan":
        raise HTTPException(
            status_code=403,
            detail="Tidak dapat melihat laporan shift milik karyawan lain."
        )

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

    is_locked = await is_transaksi_locked(db, jadwal_shift_id)

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
