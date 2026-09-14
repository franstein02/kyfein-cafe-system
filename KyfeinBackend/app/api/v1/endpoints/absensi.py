import math
from datetime import datetime, timedelta
from typing import List
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.deps import get_db, get_current_user
from app.models.absensi import Absensi, IzinTelat, IzinTidakMasuk
from app.models.jadwal import JadwalShift
from app.models.master_data import KonfigurasiLokasi
from app.models.karyawan import Karyawan
from app.schemas.absensi import (
    AbsenMasukInput, AbsenPulangInput, AbsensiOut,
    IzinTelatCreate, IzinTidakMasukCreate
)

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
    # 1. Cek Jadwal Shift
    shift = await db.get(JadwalShift, data.jadwal_shift_id)
    if not shift or shift.karyawan_id != current_user.id:
        raise HTTPException(status_code=400, detail="Jadwal shift tidak valid untuk karyawan ini")

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
    now = datetime.now()
    shift_start_dt = datetime.combine(shift.tanggal, shift.jam_mulai)
    menit_telat = 0
    if now > shift_start_dt:
        diff = now - shift_start_dt
        menit_telat = int(diff.total_seconds() // 60)

    # Check if there is an approved izin_telat
    izin_res = await db.execute(
        select(IzinTelat).where(
            IzinTelat.jadwal_shift_id == data.jadwal_shift_id,
            IzinTelat.status == "disetujui"
        )
    )
    approved_izin = izin_res.scalars().first()
    izin_telat_id = approved_izin.id if approved_izin else None

    new_absensi = Absensi(
        karyawan_id=current_user.id,
        jadwal_shift_id=data.jadwal_shift_id,
        jam_masuk=now,
        lat_masuk=data.lat_masuk,
        lng_masuk=data.lng_masuk,
        foto_masuk=data.foto_masuk,
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
    absensi = await db.get(Absensi, absensi_id)
    if not absensi or absensi.karyawan_id != current_user.id:
        raise HTTPException(status_code=404, detail="Data absensi tidak ditemukan")

    if absensi.jam_pulang:
        raise HTTPException(status_code=400, detail="Anda sudah melakukan absen pulang")

    now = datetime.now()
    absensi.jam_pulang = now
    absensi.lat_pulang = data.lat_pulang
    absensi.lng_pulang = data.lng_pulang
    absensi.foto_pulang = data.foto_pulang

    TOLERANSI_PULANG_MENIT = 15
    # Calculate status_pulang vs shift jam_selesai + toleransi
    shift = await db.get(JadwalShift, absensi.jadwal_shift_id)
    if shift:
        shift_end_dt = datetime.combine(shift.tanggal, shift.jam_selesai)
        max_end_dt = shift_end_dt + timedelta(minutes=TOLERANSI_PULANG_MENIT)
        if now > max_end_dt:
            absensi.status_pulang = "telat"  # Telat / lupa tap out hingga melewati batas toleransi
        else:
            # TODO: Pulang lebih awal (now < shift_end_dt) saat ini disimplifikasi sebagai "tepat_waktu"
            # karena ENUM status_pulang saat ini hanya memiliki ['tepat_waktu', 'telat', 'lupa_absen'].
            # Di versi mendatang, jika ditambahkan enum 'pulang_cepat', cabang ini perlu diperbarui.
            absensi.status_pulang = "tepat_waktu"
    else:
        absensi.status_pulang = "tepat_waktu"

    await db.commit()
    await db.refresh(absensi)
    return absensi
