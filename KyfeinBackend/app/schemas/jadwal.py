from datetime import datetime, date, time
from typing import Optional, Literal
from pydantic import BaseModel, Field

class ShiftTemplateCreate(BaseModel):
    nama: str = Field(..., min_length=1, max_length=100)
    shift: Optional[str] = Field(None, min_length=1, max_length=50)
    jam_mulai: time
    jam_selesai: time


class ShiftTemplateUpdate(BaseModel):
    nama: Optional[str] = Field(None, min_length=1, max_length=100)
    jam_mulai: time
    jam_selesai: time


class ShiftTemplateOut(BaseModel):
    id: str
    shift: str
    nama: str
    jam_mulai: time
    jam_selesai: time
    updated_at: datetime

    class Config:
        from_attributes = True


class JadwalShiftCreate(BaseModel):
    karyawan_id: str = Field(min_length=1)
    tanggal: date
    shift: str = Field(..., min_length=1, max_length=50)
    area_kerja: Literal['kasir', 'bar', 'kitchen']
    jam_mulai: Optional[time] = None
    jam_selesai: Optional[time] = None

class JadwalShiftOut(BaseModel):
    id: str
    karyawan_id: str
    tanggal: date
    shift: str
    area_kerja: Literal['kasir', 'bar', 'kitchen']
    shift_template_id: Optional[str] = None
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

class TukarShiftTargetKonfirmasi(BaseModel):
    status: Literal['disetujui', 'ditolak']

class TukarShiftOut(BaseModel):
    id: str
    shift_a_id: str
    shift_b_id: str
    karyawan_pengaju_id: str
    karyawan_target_id: str
    status: Literal['pending', 'disetujui', 'ditolak']
    status_target: Literal['pending', 'disetujui', 'ditolak'] = 'pending'
    dikonfirmasi_target_at: Optional[datetime] = None
    alasan: Optional[str] = None
    diajukan_at: datetime
    diproses_oleh: Optional[str] = None
    diproses_at: Optional[datetime] = None
    nama_pengaju: Optional[str] = None
    nama_target: Optional[str] = None
    tanggal_shift: Optional[date] = None
    info_shift_a: Optional[str] = None
    info_shift_b: Optional[str] = None

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
