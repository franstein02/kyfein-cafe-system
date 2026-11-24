import re
from typing import Dict, List, Optional, Sequence
from datetime import datetime, timedelta, time
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.models.jadwal import JadwalShift, ShiftTemplate
from app.models.absensi import Absensi
from app.models.karyawan import Karyawan
from app.core.config import settings
from app.core.utils import now_local

DEFAULT_SHIFT_TEMPLATES: dict[str, tuple[str, time, time]] = {
    "shift_1": ("Shift 1", time(8, 0), time(16, 0)),
    "shift_2": ("Shift 2", time(16, 0), time(23, 0)),
}


def slugify_shift_key(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", text.strip().lower()).strip("_")
    return (slug or "shift")[:50]


async def ensure_shift_templates(db: AsyncSession) -> Dict[str, ShiftTemplate]:
    """Pastikan tabel shift_template minimal berisi default Shift 1 & Shift 2 saat kosong."""
    res = await db.execute(
        select(ShiftTemplate).order_by(ShiftTemplate.jam_mulai.asc(), ShiftTemplate.shift.asc())
    )
    rows: List[ShiftTemplate] = list(res.scalars().all())
    existing = {t.shift: t for t in rows}

    if not rows:
        for shift_key, (nama, mulai, selesai) in DEFAULT_SHIFT_TEMPLATES.items():
            tpl = ShiftTemplate(
                shift=shift_key,
                nama=nama,
                jam_mulai=mulai,
                jam_selesai=selesai,
            )
            db.add(tpl)
            existing[shift_key] = tpl

        await db.commit()
        for shift_key in DEFAULT_SHIFT_TEMPLATES:
            await db.refresh(existing[shift_key])

    return existing

async def get_shift_berjalan(db: AsyncSession, karyawan_id: str, now: datetime) -> Optional[JadwalShift]:
    toleransi = getattr(settings, 'SHIFT_TOLERANSI_JAM', 3)
    
    today = now.date()
    yesterday = today - timedelta(days=1)
    
    stmt = (
        select(JadwalShift, Absensi)
        .outerjoin(Absensi, JadwalShift.id == Absensi.jadwal_shift_id)
        .where(
            JadwalShift.karyawan_id == karyawan_id,
            JadwalShift.tanggal.in_([yesterday, today])
        )
    )
    result = await db.execute(stmt)
    kandidat_rows = result.all()
    
    valid_shifts = []
    
    for shift, absensi in kandidat_rows:
        shift_date = shift.tanggal
        
        if isinstance(shift.jam_selesai, time):
            end_time = datetime.combine(shift_date, shift.jam_selesai)
        else:
            end_time = datetime.combine(shift_date, datetime.strptime(str(shift.jam_selesai), "%H:%M:%S").time())
            
        end_time_with_tolerance = end_time + timedelta(hours=toleransi)
        start_time_window = datetime.combine(shift_date, time.min)
        
        if start_time_window <= now <= end_time_with_tolerance:
            valid_shifts.append((shift, absensi))
            
    if not valid_shifts:
        return None
        
    if len(valid_shifts) == 1:
        return valid_shifts[0][0]
        
    yesterday_rows = [r for r in valid_shifts if r[0].tanggal == yesterday]
    today_rows = [r for r in valid_shifts if r[0].tanggal == today]

    if yesterday_rows and today_rows:
        yesterday_shift, yesterday_absensi = yesterday_rows[0]
        if not (yesterday_absensi and yesterday_absensi.jam_pulang):
            return yesterday_shift

    candidates = today_rows if today_rows else valid_shifts
    if len(candidates) == 1:
        return candidates[0][0]

    def _to_time(val) -> time:
        if isinstance(val, time):
            return val
        return datetime.strptime(str(val), "%H:%M:%S").time()

    def _rank(row):
        shift_obj, abs_obj = row
        s_start = datetime.combine(shift_obj.tanggal, _to_time(shift_obj.jam_mulai))
        s_end = datetime.combine(shift_obj.tanggal, _to_time(shift_obj.jam_selesai))
        if s_end < s_start:
            s_end += timedelta(days=1)
        is_clocked_out = bool(abs_obj and abs_obj.jam_pulang is not None)
        is_clocked_in_open = bool(abs_obj and abs_obj.jam_pulang is None)
        in_core_window = s_start <= now <= s_end
        return (
            1 if is_clocked_out else 0,
            0 if in_core_window else 1,
            0 if is_clocked_in_open else 1,
            s_start,
        )

    candidates.sort(key=_rank)
    return candidates[0][0]


async def require_on_duty_karyawan(
    db: AsyncSession,
    current_user: Karyawan,
    now: Optional[datetime] = None,
    allowed_areas: Optional[Sequence[str]] = None,
) -> Optional[JadwalShift]:
    """
    Kunci akses fitur operasional bagi role 'karyawan':
    1. Wajib memiliki jadwal shift berjalan pada saat ini (tidak off-shift / libur).
    2. Wajib sudah melakukan Absen Masuk dan belum Absen Pulang pada shift tersebut.
    3. Jika `allowed_areas` diberikan, area_kerja shift wajib sesuai.
    Admin/Owner selalu diizinkan (return None).
    """
    if current_user.role in ["admin", "owner"]:
        return None

    check_now = now or now_local()
    active_shift = await get_shift_berjalan(db, current_user.id, check_now)
    if not active_shift:
        raise HTTPException(
            status_code=403,
            detail="Akses ditolak: Anda sedang off-shift / libur (tidak memiliki jadwal shift aktif saat ini).",
        )

    abs_res = await db.execute(
        select(Absensi).where(
            and_(
                Absensi.jadwal_shift_id == active_shift.id,
                Absensi.karyawan_id == current_user.id,
            )
        )
    )
    absensi = abs_res.scalars().first()
    if not absensi:
        raise HTTPException(
            status_code=403,
            detail="Akses ditolak: Anda wajib melakukan Absen Masuk terlebih dahulu sebelum mengakses fitur operasional.",
        )
    if absensi.jam_pulang is not None:
        raise HTTPException(
            status_code=403,
            detail="Akses ditolak: Anda sudah melakukan Absen Pulang pada shift ini.",
        )

    if allowed_areas and active_shift.area_kerja not in allowed_areas:
        allowed_label = "/".join(a.upper() for a in allowed_areas)
        raise HTTPException(
            status_code=403,
            detail=f"Akses ditolak: Fitur ini hanya untuk shift area {allowed_label} (shift aktif Anda: {active_shift.area_kerja.upper()}).",
        )

    return active_shift
