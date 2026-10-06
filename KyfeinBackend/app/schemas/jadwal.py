from datetime import datetime, date, time
from typing import Optional, Literal
from pydantic import BaseModel, Field

class JadwalShiftCreate(BaseModel):
    karyawan_id: str = Field(min_length=1)
    tanggal: date
    shift: Literal['shift_1', 'shift_2']
    area_kerja: Literal['kasir', 'bar', 'kitchen']
    jam_mulai: time
    jam_selesai: time

class JadwalShiftOut(BaseModel):
    id: str
    karyawan_id: str
    tanggal: date
    shift: Literal['shift_1', 'shift_2']
    area_kerja: Literal['kasir', 'bar', 'kitchen']
    jam_mulai: time
    jam_selesai: time
    created_at: datetime

    class Config:
        from_attributes = True

class TukarShiftCreate(BaseModel):
    shift_a_id: str = Field(min_length=1)
    shift_b_id: str = Field(min_length=1)
    karyawan_target_id: str = Field(min_length=1)
    alasan: Optional[str] = None

class TukarShiftApproval(BaseModel):
    status: Literal['disetujui', 'ditolak']

class TukarShiftOut(BaseModel):
    id: str
    shift_a_id: str
    shift_b_id: str
    karyawan_pengaju_id: str
    karyawan_target_id: str
    status: Literal['pending', 'disetujui', 'ditolak']
    alasan: Optional[str] = None
    diajukan_at: datetime
    diproses_oleh: Optional[str] = None
    diproses_at: Optional[datetime] = None

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
