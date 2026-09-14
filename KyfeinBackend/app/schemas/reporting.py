from datetime import datetime, date
from typing import Optional, Literal
from decimal import Decimal
from pydantic import BaseModel

class PengeluaranCreate(BaseModel):
    kategori_id: str
    tipe: Literal['bulanan', 'mendadak']
    nominal: Decimal
    bulan: Optional[date] = None # Wajib kalau tipe='bulanan'
    tanggal: Optional[date] = None # Wajib kalau tipe='mendadak'
    keterangan: Optional[str] = None

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
