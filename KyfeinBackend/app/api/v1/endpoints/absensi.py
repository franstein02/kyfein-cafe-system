import math
from datetime import datetime, timedelta
from typing import List, Optional, Literal
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.core.deps import get_db, get_current_user, require_roles
from app.core.utils import now_local
from app.core.foto_helper import validate_and_claim_foto
from app.models.absensi import Absensi, IzinTelat, IzinTidakMasuk
from app.models.jadwal import JadwalShift
from app.models.master_data import KonfigurasiLokasi
from app.models.karyawan import Karyawan
from app.schemas.absensi import (
    AbsenMasukInput, AbsenPulangInput, AbsensiOut,
    IzinTelatCreate, IzinTidakMasukCreate, IzinApproval,
    IzinTelatOut, IzinTidakMasukOut
)

from app.services.jadwal_service import get_shift_berjalan

router = APIRouter()

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Hitung jarak GPS antara dua koordinat dalam meter"""
    R = 6371000  # Radius bumi dalam meter
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

@router.post("/masuk", response_model=AbsensiOut)
async def absen_masuk(
    data: AbsenMasukInput,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Absen masuk karyawan dengan validasi radius GPS server-side
    """
    now = now_local()
    active_shift = await get_shift_berjalan(db, current_user.id, now)
    
    if not active_shift:
        raise HTTPException(status_code=400, detail="Tidak ada shift berjalan saat ini")
        
    if data.jadwal_shift_id != active_shift.id:
        raise HTTPException(status_code=400, detail="Absen masuk hanya dapat dilakukan pada shift yang sedang berjalan")
        
    shift = active_shift

    # Validasi & Claim foto_masuk
    await validate_and_claim_foto(db, data.foto_masuk_id, current_user.id, "absensi", required=True)

    # Validasi: ditolak jika ada izin_tidak_masuk disetujui untuk shift itu
    izin_tm_res = await db.execute(
        select(IzinTidakMasuk).where(
            and_(
                IzinTidakMasuk.jadwal_shift_id == data.jadwal_shift_id,
                IzinTidakMasuk.status == "disetujui"
            )
        )
    )
    if izin_tm_res.scalars().first():
        raise HTTPException(
            status_code=400,
            detail="Absen masuk ditolak karena terdapat izin tidak masuk yang telah disetujui untuk shift ini"
        )

    # 2. Cek apakah sudah pernah absen di shift ini
    existing = await db.execute(select(Absensi).where(Absensi.jadwal_shift_id == data.jadwal_shift_id))
    if existing.scalars().first():
        raise HTTPException(status_code=400, detail="Anda sudah melakukan absen masuk untuk shift ini")

    # 3. Validasi GPS Radius Server-side
    lokasi_res = await db.execute(select(KonfigurasiLokasi).limit(1))
    lokasi = lokasi_res.scalars().first()
    if not lokasi:
        raise HTTPException(
            status_code=400,
            detail="Konfigurasi lokasi cafe belum diatur oleh admin."
        )

    dist = haversine_distance(
        float(data.lat_masuk), float(data.lng_masuk),
        float(lokasi.latitude), float(lokasi.longitude)
    )
    if dist > float(lokasi.radius_meter):
        raise HTTPException(
            status_code=400,
            detail=f"Posisi Anda di luar radius lokasi cafe ({dist:.1f}m > {lokasi.radius_meter}m). Absen ditolak."
        )

    # 4. Hitung keterlambatan (menit) menggunakan local time
    shift_start_dt = datetime.combine(shift.tanggal, shift.jam_mulai)
    menit_telat = 0
    if now > shift_start_dt:
        diff = now - shift_start_dt
        menit_telat = int(diff.total_seconds() // 60)

    # Check if there is an approved izin_telat
    izin_res = await db.execute(
        select(IzinTelat).where(
            and_(
                IzinTelat.jadwal_shift_id == data.jadwal_shift_id,
                IzinTelat.status == "disetujui"
            )
        )
    )
    approved_izin = izin_res.scalars().first()
    izin_telat_id = approved_izin.id if approved_izin else None
    if approved_izin:
        menit_telat = 0

    new_absensi = Absensi(
        karyawan_id=current_user.id,
        jadwal_shift_id=data.jadwal_shift_id,
        jam_masuk=now,
        lat_masuk=data.lat_masuk,
        lng_masuk=data.lng_masuk,
        foto_masuk_id=data.foto_masuk_id,
        menit_telat=menit_telat,
        izin_telat_id=izin_telat_id
    )
    db.add(new_absensi)
    await db.commit()
    await db.refresh(new_absensi)
    return new_absensi

@router.post("/{absensi_id}/pulang", response_model=AbsensiOut)
async def absen_pulang(
    absensi_id: str,
    data: AbsenPulangInput,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Absen pulang karyawan dengan validasi radius GPS server-side
    """
    absensi = await db.get(Absensi, absensi_id)
    if not absensi or absensi.karyawan_id != current_user.id:
        raise HTTPException(status_code=404, detail="Data absensi tidak ditemukan")

    if absensi.jam_pulang:
        raise HTTPException(status_code=400, detail="Anda sudah melakukan absen pulang")

    # Validasi & claim foto_pulang if provided
    if data.foto_pulang_id:
        await validate_and_claim_foto(db, data.foto_pulang_id, current_user.id, "absensi", required=False)

    # A4: Validasi GPS radius server-side untuk absen pulang
    lokasi_res = await db.execute(select(KonfigurasiLokasi).limit(1))
    lokasi = lokasi_res.scalars().first()
    if not lokasi:
        raise HTTPException(
            status_code=400,
            detail="Konfigurasi lokasi cafe belum diatur oleh admin."
        )

    dist = haversine_distance(
        float(data.lat_pulang), float(data.lng_pulang),
        float(lokasi.latitude), float(lokasi.longitude)
    )
    if dist > float(lokasi.radius_meter):
        raise HTTPException(
            status_code=400,
            detail=f"Posisi Anda di luar radius lokasi cafe ({dist:.1f}m > {lokasi.radius_meter}m). Absen pulang ditolak."
        )

    now = now_local()
    absensi.jam_pulang = now
    absensi.lat_pulang = data.lat_pulang
    absensi.lng_pulang = data.lng_pulang
    absensi.foto_pulang_id = data.foto_pulang_id

    TOLERANSI_PULANG_MENIT = 15
    # Calculate status_pulang vs shift jam_selesai + toleransi
    shift = await db.get(JadwalShift, absensi.jadwal_shift_id)
    if shift:
        shift_end_dt = datetime.combine(shift.tanggal, shift.jam_selesai)
        max_end_dt = shift_end_dt + timedelta(minutes=TOLERANSI_PULANG_MENIT)
        if now > max_end_dt:
            absensi.status_pulang = "telat"
        else:
            absensi.status_pulang = "tepat_waktu"
    else:
        absensi.status_pulang = "tepat_waktu"

    await db.commit()
    await db.refresh(absensi)
    return absensi

# --- IZIN TELAT ---
@router.post("/izin-telat", response_model=IzinTelatOut)
async def create_izin_telat(
    data: IzinTelatCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Pengajuan izin telat oleh karyawan. Wajib dilakukan sebelum absen masuk.
    """
    shift = await db.get(JadwalShift, data.jadwal_shift_id)
    if not shift or shift.karyawan_id != current_user.id:
        raise HTTPException(status_code=400, detail="Jadwal shift tidak valid untuk Anda")

    # Validasi: belum ada Absensi row untuk shift itu
    existing_absensi = await db.execute(select(Absensi).where(Absensi.jadwal_shift_id == data.jadwal_shift_id))
    if existing_absensi.scalars().first():
        raise HTTPException(status_code=400, detail="Izin telat harus diajukan sebelum melakukan absen masuk")

    # Validasi: belum ada izin_telat pending untuk shift yang sama
    existing_izin = await db.execute(
        select(IzinTelat).where(
            and_(
                IzinTelat.jadwal_shift_id == data.jadwal_shift_id,
                IzinTelat.status == "pending"
            )
        )
    )
    if existing_izin.scalars().first():
        raise HTTPException(status_code=400, detail="Sudah ada pengajuan izin telat pending untuk shift ini")

    if data.foto_id:
        await validate_and_claim_foto(db, data.foto_id, current_user.id, "izin", required=False)

    item = IzinTelat(
        karyawan_id=current_user.id,
        jadwal_shift_id=data.jadwal_shift_id,
        alasan=data.alasan,
        foto_id=data.foto_id,
        status="pending"
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item

@router.get("/izin-telat", response_model=List[IzinTelatOut])
async def list_izin_telat(
    status: Optional[Literal['pending', 'disetujui', 'ditolak']] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    query = select(IzinTelat)
    if status:
        query = query.where(IzinTelat.status == status)
    result = await db.execute(query.order_by(IzinTelat.diajukan_at.desc()))
    return result.scalars().all()

@router.put("/izin-telat/{id}/approval", response_model=IzinTelatOut)
async def approval_izin_telat(
    id: str,
    data: IzinApproval,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    """
    A3 (approval): approval izin telat hanya boleh jika status == 'pending', selain itu 409.
    """
    item = await db.get(IzinTelat, id)
    if not item:
        raise HTTPException(status_code=404, detail="Data izin telat tidak ditemukan")

    if item.status != "pending":
        raise HTTPException(status_code=409, detail="Pengajuan izin telat ini sudah diproses (bukan pending)")

    item.status = data.status
    item.diproses_oleh = current_user.id
    item.diproses_at = now_local()

    await db.commit()
    await db.refresh(item)
    return item

# --- IZIN TIDAK MASUK ---
@router.post("/izin-tidak-masuk", response_model=IzinTidakMasukOut)
async def create_izin_tidak_masuk(
    data: IzinTidakMasukCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Pengajuan izin tidak masuk (sakit/musibah/dll) oleh karyawan. Foto bukti wajib.
    """
    shift = await db.get(JadwalShift, data.jadwal_shift_id)
    if not shift or shift.karyawan_id != current_user.id:
        raise HTTPException(status_code=400, detail="Jadwal shift tidak valid untuk Anda")

    await validate_and_claim_foto(db, data.foto_id, current_user.id, "izin", required=True)

    # Validasi: belum ada Absensi row untuk shift itu
    existing_absensi = await db.execute(select(Absensi).where(Absensi.jadwal_shift_id == data.jadwal_shift_id))
    if existing_absensi.scalars().first():
        raise HTTPException(status_code=400, detail="Karyawan sudah melakukan absen masuk pada shift ini")

    # Validasi: belum ada izin_tidak_masuk pending untuk shift yang sama
    existing_izin = await db.execute(
        select(IzinTidakMasuk).where(
            and_(
                IzinTidakMasuk.jadwal_shift_id == data.jadwal_shift_id,
                IzinTidakMasuk.status == "pending"
            )
        )
    )
    if existing_izin.scalars().first():
        raise HTTPException(status_code=400, detail="Sudah ada pengajuan izin tidak masuk pending untuk shift ini")

    item = IzinTidakMasuk(
        karyawan_id=current_user.id,
        jadwal_shift_id=data.jadwal_shift_id,
        alasan=data.alasan,
        foto_id=data.foto_id,
        status="pending"
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item

@router.get("/izin-tidak-masuk", response_model=List[IzinTidakMasukOut])
async def list_izin_tidak_masuk(
    status: Optional[Literal['pending', 'disetujui', 'ditolak']] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    query = select(IzinTidakMasuk)
    if status:
        query = query.where(IzinTidakMasuk.status == status)
    result = await db.execute(query.order_by(IzinTidakMasuk.diajukan_at.desc()))
    return result.scalars().all()

@router.put("/izin-tidak-masuk/{id}/approval", response_model=IzinTidakMasukOut)
async def approval_izin_tidak_masuk(
    id: str,
    data: IzinApproval,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    """
    A3 (approval): approval izin tidak masuk hanya boleh jika status == 'pending', selain itu 409.
    """
    item = await db.get(IzinTidakMasuk, id)
    if not item:
        raise HTTPException(status_code=404, detail="Data izin tidak masuk tidak ditemukan")

    if item.status != "pending":
        raise HTTPException(status_code=409, detail="Pengajuan izin tidak masuk ini sudah diproses (bukan pending)")

    item.status = data.status
    item.diproses_oleh = current_user.id
    item.diproses_at = now_local()

    await db.commit()
    await db.refresh(item)
    return item
