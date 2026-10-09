from typing import Optional
from datetime import datetime, timedelta, time
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.jadwal import JadwalShift
from app.models.absensi import Absensi
from app.core.config import settings

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
        
    yesterday_row = next((r for r in valid_shifts if r[0].tanggal == yesterday), None)
    today_row = next((r for r in valid_shifts if r[0].tanggal == today), None)
    
    if yesterday_row and today_row:
        yesterday_shift, yesterday_absensi = yesterday_row
        if yesterday_absensi and yesterday_absensi.jam_pulang:
            return today_row[0]
        else:
            return yesterday_shift
            
    return valid_shifts[0][0]
