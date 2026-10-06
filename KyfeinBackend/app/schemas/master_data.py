from datetime import datetime
from typing import Optional, List, Literal
from decimal import Decimal
from pydantic import BaseModel, Field

# Kategori Menu
class KategoriMenuBase(BaseModel):
    nama: str = Field(min_length=1)
    area_produksi: Literal['bar', 'kitchen']
    status_aktif: bool = True

class KategoriMenuCreate(KategoriMenuBase):
    pass

class KategoriMenuOut(KategoriMenuBase):
    id: str
    created_at: datetime

    class Config:
        from_attributes = True

# Menu
class MenuBase(BaseModel):
    nama: str = Field(min_length=1)
    kode_menu: str = Field(min_length=1)
    harga: Decimal = Field(gt=0)
    kategori_id: str = Field(min_length=1)
    foto_id: Optional[str] = None
    status_aktif: bool = True

class MenuCreate(MenuBase):
    pass

class MenuUpdate(BaseModel):
    nama: Optional[str] = Field(None, min_length=1)
    harga: Optional[Decimal] = Field(None, gt=0)
    kategori_id: Optional[str] = Field(None, min_length=1)
    foto_id: Optional[str] = None
    status_aktif: Optional[bool] = None

class MenuOut(MenuBase):
    id: str
    kategori: Optional[KategoriMenuOut] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# Bahan
class BahanBase(BaseModel):
    nama: str = Field(min_length=1)
    satuan: str = Field(min_length=1)
    isi_per_kemasan: Optional[Decimal] = Field(None, gt=0)
    stok_minimum: Decimal = Field(Decimal('0'), ge=0)

class BahanCreate(BahanBase):
    harga_rata_rata: Decimal = Field(Decimal('0'), ge=0)

class BahanOut(BahanBase):
    id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class BahanAdminOut(BahanOut):
    harga_rata_rata: Decimal = Decimal('0')

class BahanStokMenipisOut(BahanAdminOut):
    total_stok: Decimal


# Menu Resep
class MenuResepBase(BaseModel):
    menu_id: str = Field(min_length=1)
    bahan_id: str = Field(min_length=1)
    jumlah_terpakai: Decimal = Field(gt=0)

class MenuResepCreate(MenuResepBase):
    pass

class MenuResepOut(MenuResepBase):
    id: str
    menu: Optional[MenuOut] = None
    bahan: Optional[BahanOut] = None

    class Config:
        from_attributes = True

# Kategori Pengeluaran
class KategoriPengeluaranBase(BaseModel):
    nama: str = Field(min_length=1)
    status_aktif: bool = True

class KategoriPengeluaranCreate(KategoriPengeluaranBase):
    pass

class KategoriPengeluaranOut(KategoriPengeluaranBase):
    id: str
    created_at: datetime

    class Config:
        from_attributes = True

# Konfigurasi Lokasi
class KonfigurasiLokasiUpdate(BaseModel):
    latitude: Optional[Decimal] = None
    longitude: Optional[Decimal] = None
    radius_meter: Optional[Decimal] = Field(None, gt=0)

class KonfigurasiLokasiOut(BaseModel):
    id: str
    latitude: Decimal
    longitude: Decimal
    radius_meter: Decimal
    updated_by: Optional[str] = None
    updated_at: datetime

    class Config:
        from_attributes = True
