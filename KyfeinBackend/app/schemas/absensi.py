from datetime import datetime
from typing import Optional, Literal
from decimal import Decimal
from pydantic import BaseModel

class AbsenMasukInput(BaseModel):
    jadwal_shift_id: str
    lat_masuk: Decimal
    lng_masuk: Decimal
    foto_masuk: str

class AbsenPulangInput(BaseModel):
    lat_pulang: Decimal
    lng_pulang: Decimal
    foto_pulang: Optional[str] = None

class AbsensiOut(BaseModel):
    id: str
    karyawan_id: str
    jadwal_shift_id: str
    jam_masuk: datetime
    jam_pulang: Optional[datetime] = None
    lat_masuk: Decimal
    lng_masuk: Decimal
    foto_masuk: str
    foto_pulang: Optional[str] = None
    menit_telat: int
    status_pulang: Optional[Literal['tepat_waktu', 'telat', 'lupa_absen']] = None

    class Config:
        from_attributes = True

class IzinTelatCreate(BaseModel):
    jadwal_shift_id: str
    alasan: str
    foto_url: Optional[str] = None

class IzinTidakMasukCreate(BaseModel):
    jadwal_shift_id: str
    alasan: str
    foto_url: str

class IzinApproval(BaseModel):
    status: Literal['disetujui', 'ditolak']
