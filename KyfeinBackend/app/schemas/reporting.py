from datetime import datetime, date
from typing import Optional, Literal, List
from decimal import Decimal
from pydantic import BaseModel, Field, model_validator

class PengeluaranCreate(BaseModel):
    kategori_id: str = Field(min_length=1)
    tipe: Literal['bulanan', 'mendadak']
    nominal: Decimal = Field(gt=0)
    bulan: Optional[date] = None # Wajib kalau tipe='bulanan'
    tanggal: Optional[date] = None # Wajib kalau tipe='mendadak'
    keterangan: Optional[str] = None

    @model_validator(mode='after')
    def validate_tipe_dates(self):
        if self.tipe == 'bulanan':
            if not self.bulan or self.tanggal is not None:
                raise ValueError("Pengeluaran bulanan wajib mengisi bulan dan tanggal harus kosong")
        elif self.tipe == 'mendadak':
            if not self.tanggal or self.bulan is not None:
                raise ValueError("Pengeluaran mendadak wajib mengisi tanggal dan bulan harus kosong")
        return self

class PengeluaranOut(BaseModel):
    id: str
    kategori_id: str
    tipe: Literal['bulanan', 'mendadak']
    nominal: Decimal
    bulan: Optional[date] = None
    tanggal: Optional[date] = None
    keterangan: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

class DailyProfitReportOut(BaseModel):
    tanggal: str
    total_penjualan: Decimal
    total_hpp_teoritis: Decimal
    pengeluaran_bulanan_pro_rata: Decimal
    pengeluaran_mendadak: Decimal
    net_profit_harian: Decimal
    menu_tanpa_resep: List[str] = []

class KategoriBreakdownItem(BaseModel):
    kategori_id: str
    nama_kategori: str
    total_nominal: Decimal

class PengeluaranBreakdownOut(BaseModel):
    filter: str
    periode_mulai: date
    periode_selesai: date
    total_pengeluaran: Decimal
    breakdown: List[KategoriBreakdownItem]
