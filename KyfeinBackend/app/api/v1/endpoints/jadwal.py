from datetime import date, datetime, timedelta
from typing import List, Optional, Literal
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_

from app.core.deps import get_db, get_current_user, require_roles
from app.core.utils import now_local
from app.models.jadwal import JadwalShift, TukarShift, RequestOff
from app.models.absensi import Absensi, IzinTelat, IzinTidakMasuk
from app.models.karyawan import Karyawan
from app.schemas.jadwal import (
    JadwalShiftCreate, JadwalShiftOut,
    TukarShiftCreate, TukarShiftApproval, TukarShiftOut,
    RequestOffCreate, RequestOffOut
)

router = APIRouter()

@router.get("/", response_model=List[JadwalShiftOut])
async def list_jadwal(
    tanggal: Optional[date] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    A11: karyawan hanya melihat jadwalnya sendiri, admin/owner melihat semua.
    """
    query = select(JadwalShift)
    if current_user.role not in ["admin", "owner"]:
        query = query.where(JadwalShift.karyawan_id == current_user.id)
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
    - Tolak jika karyawan_id tidak ditemukan atau status_aktif = False (400)
    """
    karyawan = await db.get(Karyawan, data.karyawan_id)
    if not karyawan or not karyawan.status_aktif:
        raise HTTPException(
            status_code=400,
            detail="Karyawan tidak ditemukan atau status tidak aktif"
        )

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

@router.get("/tukar-shift", response_model=List[TukarShiftOut])
async def list_tukar_shift(
    status: Optional[Literal['pending', 'disetujui', 'ditolak']] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    query = select(TukarShift)
    if status:
        query = query.where(TukarShift.status == status)
    result = await db.execute(query.order_by(TukarShift.diajukan_at.desc()))
    return result.scalars().all()

@router.post("/tukar-shift", response_model=TukarShiftOut)
async def request_tukar_shift(
    data: TukarShiftCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Issue 7: Pengajuan tukar shift oleh karyawan.
    Validasi:
    - shift_a.karyawan_id == pengaju
    - shift_b.karyawan_id == karyawan_target_id
    - pengaju != target
    - shift_a.tanggal == shift_b.tanggal
    - shift_a.tanggal >= hari ini (400)
    - tolak (409) jika shift_a ATAU shift_b sudah ada di pengajuan pending lain
    """
    shift_a = await db.get(JadwalShift, data.shift_a_id)
    shift_b = await db.get(JadwalShift, data.shift_b_id)

    if not shift_a or not shift_b:
        raise HTTPException(status_code=404, detail="Jadwal shift A atau B tidak ditemukan")

    if shift_a.karyawan_id != current_user.id:
        raise HTTPException(status_code=400, detail="Shift A bukan milik pengaju")

    if shift_b.karyawan_id != data.karyawan_target_id:
        raise HTTPException(status_code=400, detail="Shift B bukan milik karyawan target")

    if current_user.id == data.karyawan_target_id or shift_a.karyawan_id == shift_b.karyawan_id:
        raise HTTPException(status_code=400, detail="Pengaju tidak boleh tukar shift dengan diri sendiri")

    if shift_a.tanggal != shift_b.tanggal:
        raise HTTPException(
            status_code=400,
            detail="Tukar shift hanya diizinkan untuk jadwal pada tanggal yang sama!"
        )

    today = now_local().date()
    if shift_a.tanggal < today:
        raise HTTPException(
            status_code=400,
            detail="Jadwal shift sudah berlalu (tidak boleh diajukan tukar)"
        )

    # Cek jika shift_a ATAU shift_b sudah ada di pengajuan pending lain
    pending_stmt = select(TukarShift).where(
        and_(
            TukarShift.status == "pending",
            or_(
                TukarShift.shift_a_id.in_([data.shift_a_id, data.shift_b_id]),
                TukarShift.shift_b_id.in_([data.shift_a_id, data.shift_b_id])
            )
        )
    )
    res_pending = await db.execute(pending_stmt)
    if res_pending.scalars().first():
        raise HTTPException(
            status_code=409,
            detail="Salah satu jadwal shift sudah ada di pengajuan tukar shift lain yang berstatus pending"
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

@router.put("/tukar-shift/{id}/approval", response_model=TukarShiftOut)
async def approval_tukar_shift(
    id: str,
    data: TukarShiftApproval,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    """
    Issue 7: Approval tukar shift dengan locking & re-validation menyeluruh:
    - Status wajib 'pending' (selain itu 409)
    - jika disetujui:
      - Validasi shift_a & shift_b kepemilikan
      - Validasi tanggal shift >= hari ini (409)
      - Validasi belum ada absensi di kedua shift (409)
      - Validasi tidak ada izin_telat atau izin_tidak_masuk (pending/disetujui) (409)
      - Menggunakan with_for_update() pada tukar_shift & jadwal_shift
      - Transaksi atomic lengkap
    """
    stmt_tukar = select(TukarShift).where(TukarShift.id == id).with_for_update()
    res_tukar = await db.execute(stmt_tukar)
    tukar = res_tukar.scalars().first()

    if not tukar:
        raise HTTPException(status_code=404, detail="Data pengajuan tukar shift tidak ditemukan")

    if tukar.status != "pending":
        raise HTTPException(status_code=409, detail="Pengajuan tukar shift ini sudah diproses (bukan pending)")

    if data.status == "disetujui":
        stmt_a = select(JadwalShift).where(JadwalShift.id == tukar.shift_a_id).with_for_update()
        shift_a = (await db.execute(stmt_a)).scalars().first()

        stmt_b = select(JadwalShift).where(JadwalShift.id == tukar.shift_b_id).with_for_update()
        shift_b = (await db.execute(stmt_b)).scalars().first()

        if not shift_a or not shift_b:
            raise HTTPException(status_code=404, detail="Salah satu jadwal shift terkait tidak ditemukan")

        # 1. Validasi kepemilikan shift belum berubah
        if shift_a.karyawan_id != tukar.karyawan_pengaju_id or shift_b.karyawan_id != tukar.karyawan_target_id:
            raise HTTPException(
                status_code=409,
                detail="Tukar shift gagal karena kepemilikan shift telah berubah"
            )

        # 2. Validasi tanggal shift >= hari ini
        today = now_local().date()
        if shift_a.tanggal < today or shift_b.tanggal < today:
            raise HTTPException(
                status_code=409,
                detail="Tukar shift ditolak karena jadwal shift sudah berlalu"
            )

        # 3. Validasi belum ada absensi di kedua shift
        abs_stmt = select(Absensi.id).where(Absensi.jadwal_shift_id.in_([shift_a.id, shift_b.id]))
        if (await db.execute(abs_stmt)).scalars().first():
            raise HTTPException(
                status_code=409,
                detail="Tukar shift ditolak karena salah satu shift sudah memiliki catatan absensi"
            )

        # 4. Validasi tidak ada izin_telat atau izin_tidak_masuk (pending/disetujui)
        iz_telat_stmt = select(IzinTelat.id).where(
            and_(
                IzinTelat.jadwal_shift_id.in_([shift_a.id, shift_b.id]),
                IzinTelat.status.in_(["pending", "disetujui"])
            )
        )
        if (await db.execute(iz_telat_stmt)).scalars().first():
            raise HTTPException(
                status_code=409,
                detail="Tukar shift ditolak karena salah satu shift memiliki pengajuan/izin telat"
            )

        iz_tm_stmt = select(IzinTidakMasuk.id).where(
            and_(
                IzinTidakMasuk.jadwal_shift_id.in_([shift_a.id, shift_b.id]),
                IzinTidakMasuk.status.in_(["pending", "disetujui"])
            )
        )
        if (await db.execute(iz_tm_stmt)).scalars().first():
            raise HTTPException(
                status_code=409,
                detail="Tukar shift ditolak karena salah satu shift memiliki pengajuan/izin tidak masuk"
            )

        # Swapping process
        try:
            original_tanggal = shift_a.tanggal
            temp_tanggal = original_tanggal + timedelta(days=10000)

            temp_karyawan_id = shift_a.karyawan_id
            target_karyawan_id = shift_b.karyawan_id

            shift_a.tanggal = temp_tanggal
            await db.flush()

            shift_b.karyawan_id = temp_karyawan_id
            await db.flush()

            shift_a.karyawan_id = target_karyawan_id
            shift_a.tanggal = original_tanggal
            await db.flush()

            tukar.status = data.status
            tukar.diproses_oleh = current_user.id
            tukar.diproses_at = now_local()

            await db.commit()
        except Exception:
            await db.rollback()
            raise HTTPException(
                status_code=409,
                detail="Gagal memproses persetujuan tukar shift akibat konflik data"
            )
    else:
        tukar.status = data.status
        tukar.diproses_oleh = current_user.id
        tukar.diproses_at = now_local()
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
    """
    Issue 7: Request Off validation:
    - Tolak tanggal di masa lalu (400)
    - Tolak duplikat (karyawan_id, tanggal) (409)
    """
    today = now_local().date()
    if data.tanggal < today:
        raise HTTPException(
            status_code=400,
            detail="Tanggal request off tidak boleh di masa lalu"
        )

    existing = await db.execute(
        select(RequestOff).where(
            and_(
                RequestOff.karyawan_id == current_user.id,
                RequestOff.tanggal == data.tanggal
            )
        )
    )
    if existing.scalars().first():
        raise HTTPException(
            status_code=409,
            detail="Anda sudah mengajukan request off pada tanggal tersebut"
        )

    item = RequestOff(
        karyawan_id=current_user.id,
        tanggal=data.tanggal,
        alasan=data.alasan
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item
