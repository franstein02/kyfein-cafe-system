from datetime import datetime, date, time
from typing import Optional, Literal
from pydantic import BaseModel

class JadwalShiftCreate(BaseModel):
    karyawan_id: str
    tanggal: date
    shift: Literal['shift_1', 'shift_2']
    jam_mulai: time
    jam_selesai: time

class JadwalShiftOut(BaseModel):
    id: str
    karyawan_id: str
    tanggal: date
    shift: Literal['shift_1', 'shift_2']
    jam_mulai: time
    jam_selesai: time
    created_at: datetime

    class Config:
        from_attributes = True

class TukarShiftCreate(BaseModel):
    shift_a_id: str
    shift_b_id: str
    karyawan_target_id: str
    alasan: Optional[str] = None

class TukarShiftOut(BaseModel):
    id: str
    shift_a_id: str
    shift_b_id: str
    karyawan_pengaju_id: str
    karyawan_target_id: str
    status: Literal['pending', 'disetujui', 'ditolak']
    alasan: Optional[str] = None
    diajukan_at: datetime

    class Config:
        from_attributes = True

class RequestOffCreate(BaseModel):
    tanggal: date
    alasan: Optional[str] = None

class RequestOffOut(BaseModel):
    id: str
    karyawan_id: str
    tanggal: date
    alasan: Optional[str] = None
    diajukan_at: datetime

    class Config:
        from_attributes = True
