from datetime import datetime
from typing import Optional, Literal
from pydantic import BaseModel, EmailStr

class KaryawanBase(BaseModel):
    nama: str
    email: EmailStr
    nomor_hp: Optional[str] = None
    role: Literal['karyawan', 'admin']
    divisi: Optional[Literal['kasir', 'bar', 'kitchen']] = 'kasir'
    foto_profile_id: Optional[str] = None
    status_aktif: bool = True

class KaryawanCreate(KaryawanBase):
    password: str

class KaryawanUpdate(BaseModel):
    nama: Optional[str] = None
    email: Optional[EmailStr] = None
    nomor_hp: Optional[str] = None
    divisi: Optional[Literal['kasir', 'bar', 'kitchen']] = None
    password: Optional[str] = None
    foto_profile_id: Optional[str] = None
    status_aktif: Optional[bool] = None

class KaryawanOut(KaryawanBase):
    id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
