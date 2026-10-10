from datetime import datetime
from typing import Optional, List, Literal
from decimal import Decimal
from pydantic import BaseModel, Field

class TransaksiDetailCreate(BaseModel):
    menu_id: str = Field(min_length=1)
    qty: int = Field(gt=0)
    catatan: Optional[str] = None

class TransaksiDetailOut(BaseModel):
    id: str
    menu_id: str
    qty: int
    harga_satuan: Decimal
    hpp_satuan: Decimal = Decimal("0")
    catatan: Optional[str] = None
    subtotal: Decimal
    status_item: Literal['menunggu', 'diproses', 'selesai']

    class Config:
        from_attributes = True

class TransaksiCreate(BaseModel):
    jadwal_shift_id: Optional[str] = None
    metode_bayar: Literal['cash', 'qris']
    uang_diterima: Optional[Decimal] = None
    foto_bukti_qris_id: Optional[str] = None
    details: List[TransaksiDetailCreate]

class TransaksiOut(BaseModel):
    id: str
    jadwal_shift_id: str
    kasir_id: str
    nomor_transaksi: str
    metode_bayar: Literal['cash', 'qris']
    total_harga: Decimal
    uang_diterima: Optional[Decimal] = None
    kembalian: Optional[Decimal] = None
    foto_bukti_qris_id: Optional[str] = None
    status: Literal['selesai', 'dibatalkan']
    waktu_transaksi: datetime
    details: List[TransaksiDetailOut] = []

    class Config:
        from_attributes = True

class ActiveShiftSummaryOut(BaseModel):
    jadwal_shift_id: str
    karyawan_id: str
    tanggal: str
    shift: str
    total_transaksi: int
    total_penjualan: Decimal
    total_cash: Decimal
    total_qris: Decimal
    shift_locked_by_opname: bool
