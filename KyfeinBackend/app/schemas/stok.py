from datetime import datetime
from typing import Optional, List, Literal
from decimal import Decimal
from pydantic import BaseModel, Field

class OpnameItemInput(BaseModel):
    bahan_id: str = Field(min_length=1)
    jumlah: Decimal = Field(ge=0) # Hasil hitung fisik raw

class StokOpnameCreate(BaseModel):
    jadwal_shift_id: str = Field(min_length=1)
    titik: Literal['bar', 'kitchen']
    tipe: Literal['awal_shift', 'akhir_shift']
    metode: Literal['hitung_manual', 'carry_forward'] = 'hitung_manual'
    catatan: Optional[str] = None
    items: List[OpnameItemInput] = []

class StokOpnameDetailOut(BaseModel):
    id: str
    bahan_id: str
    jumlah: Decimal

    class Config:
        from_attributes = True

class StokOpnameOut(BaseModel):
    id: str
    jadwal_shift_id: str
    titik: Literal['bar', 'kitchen']
    tipe: Literal['awal_shift', 'akhir_shift']
    metode: Literal['hitung_manual', 'carry_forward']
    karyawan_id: str
    waktu_opname: datetime
    catatan: Optional[str] = None
    details: List[StokOpnameDetailOut] = []

    class Config:
        from_attributes = True

class BarangKeluarItemInput(BaseModel):
    bahan_id: str = Field(min_length=1)
    jumlah: Decimal = Field(gt=0)

class BarangKeluarCreate(BaseModel):
    titik_tujuan: Literal['bar', 'kitchen']
    items: List[BarangKeluarItemInput]

class BarangKeluarOut(BaseModel):
    id: str
    titik_tujuan: Literal['bar', 'kitchen']
    karyawan_id: str
    waktu: datetime

    class Config:
        from_attributes = True

# Barang Masuk
class BarangMasukItemInput(BaseModel):
    bahan_id: str = Field(min_length=1)
    jumlah_kemasan_besar: int = Field(0, ge=0)
    jumlah_satuan_kecil: Decimal = Field(Decimal('0'), ge=0)
    harga_total: Decimal = Field(gt=0)

class BarangMasukCreate(BaseModel):
    catatan: Optional[str] = None
    items: List[BarangMasukItemInput]

class BarangMasukDetailOut(BaseModel):
    id: str
    bahan_id: str
    jumlah_kemasan_besar: int
    jumlah_satuan_kecil: Decimal
    harga_total: Decimal

    class Config:
        from_attributes = True

class BarangMasukOut(BaseModel):
    id: str
    karyawan_id: str
    waktu: datetime
    catatan: Optional[str] = None
    details: List[BarangMasukDetailOut] = []

    class Config:
        from_attributes = True

# View Schemas
from app.schemas.master_data import BahanOut

class StokGudangOut(BaseModel):
    id: str
    bahan_id: str
    nama_bahan: Optional[str] = None
    jumlah_kemasan_besar: int
    jumlah_satuan_kecil: Decimal
    updated_at: datetime
    bahan: Optional[BahanOut] = None

    class Config:
        from_attributes = True

class StokTitikOut(BaseModel):
    id: str
    bahan_id: str
    nama_bahan: Optional[str] = None
    titik: Literal['bar', 'kitchen']
    jumlah: Decimal
    updated_at: datetime
    bahan: Optional[BahanOut] = None

    class Config:
        from_attributes = True

class MutasiStokOut(BaseModel):
    id: str
    bahan_id: str
    nama_bahan: Optional[str] = None
    titik: Optional[Literal['bar', 'kitchen']] = None
    jadwal_shift_id: Optional[str] = None
    tipe: str
    jumlah_selisih: Decimal
    keterangan: Optional[str] = None
    created_at: datetime
    bahan: Optional[BahanOut] = None

    class Config:
        from_attributes = True
