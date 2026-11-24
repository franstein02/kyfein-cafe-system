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


def _normalize_optional_text(v: Optional[str]) -> Optional[str]:
    if v is None:
        return None
    s = str(v).strip()
    return s if s else None


class PengeluaranCreate(BaseModel):
    kategori_id: Optional[str] = None
    nama_pengeluaran: Optional[str] = Field(None, max_length=150)
    tipe: Literal['bulanan', 'mendadak']
    nominal: Decimal = Field(gt=0)
    bulan: Optional[date] = None  # Wajib kalau tipe='bulanan'
    tanggal: Optional[date] = None  # Wajib kalau tipe='mendadak'
    keterangan: Optional[str] = None

    @field_validator('kategori_id', 'nama_pengeluaran', 'keterangan', mode='before')
    @classmethod
    def clean_text_fields(cls, v):
        return _normalize_optional_text(v)

    @field_validator('bulan', mode='before')
    @classmethod
    def normalize_bulan(cls, v):
        return _parse_bulan_date(v)

    @model_validator(mode='after')
    def validate_tipe_dates(self):
        if self.tipe == 'bulanan':
            if not self.kategori_id:
                raise ValueError("Pengeluaran bulanan wajib memilih kategori pengeluaran")
            if not self.bulan or self.tanggal is not None:
                raise ValueError("Pengeluaran bulanan wajib mengisi bulan dan tanggal harus kosong")
        elif self.tipe == 'mendadak':
            if not self.tanggal or self.bulan is not None:
                raise ValueError("Pengeluaran mendadak wajib mengisi tanggal dan bulan harus kosong")
            if not self.kategori_id and not self.nama_pengeluaran and not self.keterangan:
                raise ValueError("Pengeluaran mendadak wajib mengisi nama/keperluan pengeluaran")
        return self

class PengeluaranUpdate(BaseModel):
    kategori_id: Optional[str] = None
    nama_pengeluaran: Optional[str] = Field(None, max_length=150)
    tipe: Optional[Literal['bulanan', 'mendadak']] = None
    nominal: Optional[Decimal] = Field(None, gt=0)
    bulan: Optional[date] = None
    tanggal: Optional[date] = None
    keterangan: Optional[str] = None

    @field_validator('kategori_id', 'nama_pengeluaran', mode='before')
    @classmethod
    def clean_text_fields(cls, v):
        return _normalize_optional_text(v)

    @field_validator('bulan', mode='before')
    @classmethod
    def normalize_bulan(cls, v):
        return _parse_bulan_date(v)

class PengeluaranOut(BaseModel):
    id: str
    kategori_id: Optional[str] = None
    nama_pengeluaran: Optional[str] = None
    nama_kategori: Optional[str] = None
    tipe: Literal['bulanan', 'mendadak', 'belanja_bahan']
    nominal: Decimal
    bulan: Optional[date] = None
    tanggal: Optional[date] = None
    keterangan: Optional[str] = None
    pro_rata_harian: Optional[Decimal] = None
    jumlah_hari_bulan: Optional[int] = None
    dicatat_oleh: Optional[str] = None
    created_at: datetime
    sumber: Literal['operasional', 'barang_masuk'] = 'operasional'
    jumlah_item: Optional[int] = None
    editable: bool = True

    class Config:
        from_attributes = True

class DailyProfitReportOut(BaseModel):
    tanggal: str
    jumlah_transaksi: int = 0
    total_penjualan: Decimal
    total_hpp_teoritis: Decimal
    laba_kotor: Decimal = Decimal("0.00")
    pengeluaran_bulanan_pro_rata: Decimal
    pengeluaran_mendadak: Decimal
    total_operasional: Decimal = Decimal("0.00")
    net_profit_harian: Decimal
    total_belanja_barang_masuk: Decimal = Decimal("0.00")
    total_pengeluaran_kas: Decimal = Decimal("0.00")
    arus_kas_bersih: Decimal = Decimal("0.00")
    nilai_aset_stok_saat_ini: Decimal = Decimal("0.00")
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
    laba_kotor: Decimal = Decimal("0.00")
    gross_margin_persen: Decimal = Decimal("0.00")
    pengeluaran_bulanan_pro_rata: Decimal
    pengeluaran_mendadak: Decimal
    total_operasional: Decimal = Decimal("0.00")
    net_profit: Decimal
    net_margin_persen: Decimal = Decimal("0.00")
    menu_tanpa_resep: List[str] = []
    # Arus Kas Riil & Valuasi Persediaan Stok Multi-Bulan
    total_belanja_barang_masuk: Decimal = Decimal("0.00")
    total_pengeluaran_kas: Decimal = Decimal("0.00")
    arus_kas_bersih: Decimal = Decimal("0.00")
    nilai_aset_stok_gudang: Decimal = Decimal("0.00")
    nilai_aset_stok_titik: Decimal = Decimal("0.00")
    nilai_aset_stok_saat_ini: Decimal = Decimal("0.00")
    # Ringkasan Stok Periode
    jumlah_barang_masuk: int = 0
    jumlah_barang_keluar: int = 0
    jumlah_sesi_opname: int = 0
    jumlah_stok_menipis: int = 0
    # Ringkasan Absensi Periode
    total_shift_terjadwal: int = 0
    total_hadir: int = 0
    total_tepat_waktu: int = 0
    total_terlambat: int = 0
    total_menit_telat: int = 0
    total_izin_telat: int = 0
    total_izin_tidak_masuk: int = 0
    total_tanpa_keterangan: int = 0
    total_lupa_absen_pulang: int = 0
    tingkat_ketepatan_persen: float = 100.0
    absensi_per_karyawan: List["EmployeeBehaviorItem"] = []

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
    total_belanja_bahan: Decimal = Decimal("0.00")
    total_semua_pengeluaran: Decimal = Decimal("0.00")
    breakdown: List[KategoriBreakdownItem]
    items: List[KategoriBreakdownItem] = []
    items_dengan_bahan: List[KategoriBreakdownItem] = []


class SalesChartPoint(BaseModel):
    label: str
    tanggal: str
    total_penjualan: Decimal = Decimal("0.00")
    total_hpp: Decimal = Decimal("0.00")
    total_pengeluaran: Decimal = Decimal("0.00")
    net_profit: Decimal = Decimal("0.00")
    jumlah_transaksi: int = 0


class AbsensiKaryawanLogItem(BaseModel):
    jadwal_shift_id: str
    tanggal: date
    shift: str
    area_kerja: str
    jam_mulai: str
    jam_selesai: str
    jam_masuk: Optional[datetime] = None
    jam_pulang: Optional[datetime] = None
    menit_telat: int = 0
    status_kehadiran: Literal[
        'tepat_waktu', 'terlambat', 'izin_tidak_masuk', 'alpha', 'belum_mulai'
    ]
    lupa_absen_pulang: bool = False
    keterangan: Optional[str] = None


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
    riwayat_shift: List[AbsensiKaryawanLogItem] = []


class MenuHppBahanItemOut(BaseModel):
    bahan_id: str
    nama_bahan: str
    satuan: str
    area: str = 'semua'
    jumlah_terpakai: Decimal
    harga_rata_rata: Decimal
    subtotal_hpp: Decimal
    persentase_kontribusi: Decimal = Decimal("0.00")


class MenuHppReportItemOut(BaseModel):
    menu_id: str
    kode_menu: str
    nama_menu: str
    kategori_nama: str
    area_produksi: Literal['bar', 'kitchen']
    status_aktif: bool
    harga_jual: Decimal
    hpp_saat_ini: Decimal
    laba_kotor: Decimal
    margin_persen: Decimal
    hpp_terjual_rata_rata: Optional[Decimal] = None
    selisih_hpp_vs_rata_terjual: Optional[Decimal] = None
    qty_terjual: int = 0
    punya_resep: bool
    resep_items: List[MenuHppBahanItemOut] = []


class BahanHargaMonitorOut(BaseModel):
    bahan_id: str
    nama_bahan: str
    satuan: str
    area: str = 'semua'
    harga_rata_rata: Decimal
    harga_beli_terakhir: Optional[Decimal] = None
    selisih_terakhir_vs_avg: Optional[Decimal] = None
    tanggal_beli_terakhir: Optional[datetime] = None
    jumlah_menu_terkait: int = 0


class HppMenuReportOut(BaseModel):
    total_menu: int = 0
    total_menu_beresep: int = 0
    total_menu_tanpa_resep: int = 0
    rata_rata_margin_persen: Decimal = Decimal("0.00")
    jumlah_menu_margin_tipis: int = 0
    items: List[MenuHppReportItemOut] = []
    bahan_monitor: List[BahanHargaMonitorOut] = []


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
    laba_kotor: Decimal = Decimal("0.00")
    pengeluaran_bulanan_pro_rata: Decimal = Decimal("0.00")
    pengeluaran_mendadak: Decimal = Decimal("0.00")
    total_pengeluaran: Decimal = Decimal("0.00")
    net_profit: Decimal = Decimal("0.00")
    margin_profit_persen: float = 0.0
    total_belanja_barang_masuk: Decimal = Decimal("0.00")
    total_pengeluaran_kas: Decimal = Decimal("0.00")
    arus_kas_bersih: Decimal = Decimal("0.00")
    nilai_aset_stok_saat_ini: Decimal = Decimal("0.00")
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


PeriodProfitReportOut.model_rebuild()
