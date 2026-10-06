from datetime import datetime
from typing import Optional, Literal
from decimal import Decimal
from pydantic import BaseModel, Field

class AbsenMasukInput(BaseModel):
    jadwal_shift_id: str = Field(min_length=1)
    lat_masuk: Decimal
    lng_masuk: Decimal
    foto_masuk_id: str = Field(min_length=1)

class AbsenPulangInput(BaseModel):
    lat_pulang: Decimal
    lng_pulang: Decimal
    foto_pulang_id: Optional[str] = None

class AbsensiOut(BaseModel):
    id: str
    karyawan_id: str
    jadwal_shift_id: str
    jam_masuk: datetime
    jam_pulang: Optional[datetime] = None
    lat_masuk: Decimal
    lng_masuk: Decimal
    foto_masuk_id: str
    foto_pulang_id: Optional[str] = None
    menit_telat: int
    status_pulang: Optional[Literal['tepat_waktu', 'telat', 'lupa_absen']] = None

    class Config:
        from_attributes = True

class IzinTelatCreate(BaseModel):
    jadwal_shift_id: str = Field(min_length=1)
    alasan: str = Field(min_length=1)
    foto_id: Optional[str] = None

class IzinTidakMasukCreate(BaseModel):
    jadwal_shift_id: str = Field(min_length=1)
    alasan: str = Field(min_length=1)
    foto_id: str = Field(min_length=1)

class IzinApproval(BaseModel):
    status: Literal['disetujui', 'ditolak']

class IzinTelatOut(BaseModel):
    id: str
    karyawan_id: str
    jadwal_shift_id: str
    alasan: str
    foto_id: Optional[str] = None
    status: Literal['pending', 'disetujui', 'ditolak']
    diajukan_at: datetime
    diproses_oleh: Optional[str] = None
    diproses_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class IzinTidakMasukOut(BaseModel):
    id: str
    karyawan_id: str
    jadwal_shift_id: str
    alasan: str
    foto_id: str
    status: Literal['pending', 'disetujui', 'ditolak']
    diajukan_at: datetime
    diproses_oleh: Optional[str] = None
    diproses_at: Optional[datetime] = None

    class Config:
        from_attributes = True
