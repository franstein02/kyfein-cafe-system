from datetime import datetime, date
from typing import Optional, Literal, List
from decimal import Decimal
from pydantic import BaseModel, Field, field_validator, model_validator


def _parse_bulan_date(v):
    if v is None or v == "":
        return None
    if isinstance(v, str) and len(v.strip()) == 7 and "-" in v:
        return f"{v.strip()}-01"
    return v


class PengeluaranCreate(BaseModel):
    kategori_id: str = Field(min_length=1)
    tipe: Literal['bulanan', 'mendadak']
    nominal: Decimal = Field(gt=0)
    bulan: Optional[date] = None  # Wajib kalau tipe='bulanan'
    tanggal: Optional[date] = None  # Wajib kalau tipe='mendadak'
    keterangan: Optional[str] = None

    @field_validator('bulan', mode='before')
    @classmethod
    def normalize_bulan(cls, v):
        return _parse_bulan_date(v)

    @model_validator(mode='after')
    def validate_tipe_dates(self):
        if self.tipe == 'bulanan':
            if not self.bulan or self.tanggal is not None:
                raise ValueError("Pengeluaran bulanan wajib mengisi bulan dan tanggal harus kosong")
        elif self.tipe == 'mendadak':
            if not self.tanggal or self.bulan is not None:
                raise ValueError("Pengeluaran mendadak wajib mengisi tanggal dan bulan harus kosong")
        return self

class PengeluaranUpdate(BaseModel):
    kategori_id: Optional[str] = Field(None, min_length=1)
    tipe: Optional[Literal['bulanan', 'mendadak']] = None
    nominal: Optional[Decimal] = Field(None, gt=0)
    bulan: Optional[date] = None
    tanggal: Optional[date] = None
    keterangan: Optional[str] = None

    @field_validator('bulan', mode='before')
    @classmethod
    def normalize_bulan(cls, v):
        return _parse_bulan_date(v)

class PengeluaranOut(BaseModel):
    id: str
    kategori_id: str
    nama_kategori: Optional[str] = None
    tipe: Literal['bulanan', 'mendadak']
    nominal: Decimal
    bulan: Optional[date] = None
    tanggal: Optional[date] = None
    keterangan: Optional[str] = None
    dicatat_oleh: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

class DailyProfitReportOut(BaseModel):
    tanggal: str
    jumlah_transaksi: int = 0
    total_penjualan: Decimal
    total_hpp_teoritis: Decimal
    pengeluaran_bulanan_pro_rata: Decimal
    pengeluaran_mendadak: Decimal
    net_profit_harian: Decimal
    menu_tanpa_resep: List[str] = []

class PeriodProfitReportOut(BaseModel):
    filter: str
    periode_mulai: date
    periode_selesai: date
    jumlah_transaksi: int = 0
    jumlah_transaksi_dibatalkan: int = 0
    total_cash: Decimal = Decimal("0.00")
    total_qris: Decimal = Decimal("0.00")
    total_penjualan: Decimal
    total_hpp_teoritis: Decimal
    pengeluaran_bulanan_pro_rata: Decimal
    pengeluaran_mendadak: Decimal
    net_profit: Decimal
    menu_tanpa_resep: List[str] = []
    # Ringkasan Stok Periode
    jumlah_barang_masuk: int = 0
    jumlah_barang_keluar: int = 0
    jumlah_sesi_opname: int = 0
    jumlah_stok_menipis: int = 0
    # Ringkasan Absensi Periode
    total_hadir: int = 0
    total_tepat_waktu: int = 0
    total_terlambat: int = 0
    total_izin_telat: int = 0
    total_izin_tidak_masuk: int = 0

class KategoriBreakdownItem(BaseModel):
    kategori_id: str
    nama_kategori: str
    total_nominal: Decimal
    persentase: Decimal = Decimal("0.00")

class PengeluaranBreakdownOut(BaseModel):
    filter: str
    periode_mulai: date
    periode_selesai: date
    total_pengeluaran: Decimal
    breakdown: List[KategoriBreakdownItem]
    items: List[KategoriBreakdownItem] = []


class SalesChartPoint(BaseModel):
    label: str
    tanggal: str
    total_penjualan: Decimal = Decimal("0.00")
    total_hpp: Decimal = Decimal("0.00")
    total_pengeluaran: Decimal = Decimal("0.00")
    net_profit: Decimal = Decimal("0.00")
    jumlah_transaksi: int = 0


class EmployeeBehaviorItem(BaseModel):
    karyawan_id: str
    nama: str
    divisi: str
    total_shift_terjadwal: int = 0
    total_hadir: int = 0
    tepat_waktu_count: int = 0
    telat_count: int = 0
    total_menit_telat: int = 0
    rata_menit_telat: float = 0.0
    izin_telat_count: int = 0
    izin_tidak_masuk_count: int = 0
    lupa_absen_pulang_count: int = 0
    tanpa_keterangan_count: int = 0
    tukar_shift_count: int = 0
    tingkat_ketepatan_persen: float = 100.0
    kategori_perilaku: Literal['perlu_perhatian', 'waspada', 'disiplin', 'belum_ada_data']
    ringkasan_perilaku: str


class DashboardOverviewOut(BaseModel):
    filter: str
    periode_mulai: date
    periode_selesai: date
    chart_granularity: Literal['jam', 'hari', 'bulan']
    chart_periode_mulai: date
    chart_periode_selesai: date
    periode_perilaku_mulai: date
    periode_perilaku_selesai: date
    total_penjualan: Decimal = Decimal("0.00")
    total_hpp_teoritis: Decimal = Decimal("0.00")
    pengeluaran_bulanan_pro_rata: Decimal = Decimal("0.00")
    pengeluaran_mendadak: Decimal = Decimal("0.00")
    total_pengeluaran: Decimal = Decimal("0.00")
    net_profit: Decimal = Decimal("0.00")
    margin_profit_persen: float = 0.0
    jumlah_transaksi: int = 0
    jumlah_transaksi_dibatalkan: int = 0
    rata_rata_transaksi: Decimal = Decimal("0.00")
    total_cash: Decimal = Decimal("0.00")
    total_qris: Decimal = Decimal("0.00")
    perubahan_penjualan_persen: Optional[float] = None
    grafik_penjualan: List[SalesChartPoint] = []
    ringkasan_disiplin_total_hadir: int = 0
    ringkasan_disiplin_tepat_waktu: int = 0
    ringkasan_disiplin_telat: int = 0
    ringkasan_disiplin_alpha: int = 0
    tingkat_ketepatan_tim_persen: float = 100.0
    perilaku_karyawan: List[EmployeeBehaviorItem] = []
