from datetime import datetime
from typing import Optional, List, Literal
from decimal import Decimal
from pydantic import BaseModel

# Kategori Menu
class KategoriMenuBase(BaseModel):
    nama: str
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
    nama: str
    kode_menu: str
    harga: Decimal
    kategori_id: str
    foto: Optional[str] = None
    status_aktif: bool = True

class MenuCreate(MenuBase):
    pass

class MenuOut(MenuBase):
    id: str
    kategori: Optional[KategoriMenuOut] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# Bahan
class BahanBase(BaseModel):
    nama: str
    satuan: str
    isi_per_kemasan: Optional[Decimal] = None
    stok_minimum: Decimal = Decimal('0')

class BahanCreate(BahanBase):
    pass

class BahanOut(BahanBase):
    id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# Menu Resep
class MenuResepBase(BaseModel):
    menu_id: str
    bahan_id: str
    jumlah_terpakai: Decimal

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
    nama: str
    status_aktif: bool = True

class KategoriPengeluaranCreate(KategoriPengeluaranBase):
    pass

class KategoriPengeluaranOut(KategoriPengeluaranBase):
    id: str
    created_at: datetime

    class Config:
        from_attributes = True
