from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.core.deps import get_db, get_current_user, require_roles
from app.models.jadwal import JadwalShift, TukarShift, RequestOff
from app.models.karyawan import Karyawan
from app.schemas.jadwal import (
    JadwalShiftCreate, JadwalShiftOut,
    TukarShiftCreate, TukarShiftOut,
    RequestOffCreate, RequestOffOut
)

router = APIRouter()

@router.get("/", response_model=List[JadwalShiftOut])
async def list_jadwal(
    tanggal: Optional[date] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    query = select(JadwalShift)
    if tanggal:
        query = query.where(JadwalShift.tanggal == tanggal)
    result = await db.execute(query.order_by(JadwalShift.tanggal, JadwalShift.jam_mulai))
    return result.scalars().all()

@router.post("/", response_model=JadwalShiftOut)
async def create_jadwal(
    data: JadwalShiftCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    """
    Buat jadwal shift baru dengan penugasan area_kerja ('kasir', 'bar', 'kitchen')
    """
    # Cek constraint 1 karyawan tidak boleh 2 shift di tanggal sama
    existing = await db.execute(
        select(JadwalShift).where(
            and_(
                JadwalShift.karyawan_id == data.karyawan_id,
                JadwalShift.tanggal == data.tanggal
            )
        )
    )
    if existing.scalars().first():
        raise HTTPException(status_code=400, detail="Karyawan ini sudah memiliki jadwal shift pada tanggal tersebut")

    item = JadwalShift(**data.dict(), dibuat_oleh=current_user.id)
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item

@router.get("/tukar-shift/jadwal-tersedia", response_model=List[JadwalShiftOut])
async def list_jadwal_untuk_tukar(
    tanggal: date,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    VISIBILITAS EKSEPSI JADWAL:
    Karyawan dapat melihat jadwal milik karyawan LAIN pada tanggal yang sama
    untuk memilih target tukar shift.
    """
    result = await db.execute(
        select(JadwalShift).where(
            and_(
                JadwalShift.tanggal == tanggal,
                JadwalShift.karyawan_id != current_user.id
            )
        )
    )
    return result.scalars().all()

@router.post("/tukar-shift", response_model=TukarShiftOut)
async def request_tukar_shift(
    data: TukarShiftCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Pengajuan tukar shift oleh karyawan. Validasi otomatis: HANYA untuk tanggal yang sama.
    """
    shift_a = await db.get(JadwalShift, data.shift_a_id)
    shift_b = await db.get(JadwalShift, data.shift_b_id)

    if not shift_a or not shift_b:
        raise HTTPException(status_code=404, detail="Jadwal shift A atau B tidak ditemukan")

    if shift_a.tanggal != shift_b.tanggal:
        raise HTTPException(
            status_code=400,
            detail="Tukar shift hanya diizinkan untuk jadwal pada tanggal yang sama!"
        )

    tukar = TukarShift(
        shift_a_id=data.shift_a_id,
        shift_b_id=data.shift_b_id,
        karyawan_pengaju_id=current_user.id,
        karyawan_target_id=data.karyawan_target_id,
        alasan=data.alasan,
        status="pending"
    )
    db.add(tukar)
    await db.commit()
    await db.refresh(tukar)
    return tukar

@router.get("/request-off", response_model=List[RequestOffOut])
async def list_request_off(
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    VISIBILITAS EKSEPSI REQUEST OFF:
    Semua karyawan bisa melihat SEMUA pengajuan request off karyawan lain
    agar tidak bentrok mengajukan libur di tanggal yang sama.
    """
    result = await db.execute(select(RequestOff).order_by(RequestOff.tanggal.desc()))
    return result.scalars().all()

@router.post("/request-off", response_model=RequestOffOut)
async def create_request_off(
    data: RequestOffCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    item = RequestOff(
        karyawan_id=current_user.id,
        tanggal=data.tanggal,
        alasan=data.alasan
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item
