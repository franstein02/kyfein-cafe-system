from datetime import datetime
from typing import Optional, List, Literal
from decimal import Decimal
from pydantic import BaseModel, Field

class OpnameItemInput(BaseModel):
    bahan_id: str = Field(min_length=1)
    jumlah: Decimal = Field(ge=0) # Hasil hitung fisik raw

class StokOpnameCreate(BaseModel):
    jadwal_shift_id: Optional[str] = None
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
    susulan: bool = False
    diinput_oleh: Optional[str] = None
    waktu_opname: datetime
    catatan: Optional[str] = None
    stok_titik_diperbarui: Optional[bool] = None
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


class BarangMasukRekapDetailOut(BaseModel):
    id: str
    bahan_id: str
    nama_bahan: str
    satuan: str
    area: str = 'semua'
    isi_per_kemasan: Decimal = Decimal('1')
    jumlah_kemasan_besar: int = 0
    jumlah_satuan_kecil: Decimal = Decimal('0')
    total_satuan_kecil: Decimal = Decimal('0')
    harga_total: Decimal = Decimal('0')
    harga_per_satuan_kecil: Decimal = Decimal('0')
    harga_per_kemasan: Optional[Decimal] = None
    harga_rata_rata_saat_ini: Decimal = Decimal('0')
    selisih_vs_avg: Optional[Decimal] = None


class BarangMasukRekapItemOut(BaseModel):
    id: str
    waktu: datetime
    karyawan_id: str
    nama_karyawan: str
    catatan: Optional[str] = None
    jumlah_item: int = 0
    total_nilai: Decimal = Decimal('0')
    details: List[BarangMasukRekapDetailOut] = []


class BarangMasukRekapResponse(BaseModel):
    total_transaksi: int = 0
    total_item_masuk: int = 0
    total_nilai_pembelian: Decimal = Decimal('0')
    items: List[BarangMasukRekapItemOut] = []

# View Schemas
from app.schemas.master_data import BahanOut, BahanAdminOut

class StokGudangBomItemOut(BaseModel):
    menu_id: str
    kode_menu: str
    nama_menu: str
    area_produksi: Optional[str] = None
    jumlah_terpakai: Decimal
    biaya_per_porsi: Decimal = Decimal('0')
    estimasi_porsi: Optional[int] = None


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


class StokGudangAdminOut(StokGudangOut):
    bahan: Optional[BahanAdminOut] = None
    harga_rata_rata: Decimal = Decimal('0')
    harga_rata_rata_per_kemasan: Optional[Decimal] = None
    nilai_persediaan: Decimal = Decimal('0')
    bom_pemakaian: List[StokGudangBomItemOut] = []

class StokGudangUpdate(BaseModel):
    jumlah_kemasan_besar: Optional[int] = None
    jumlah_satuan_kecil: Optional[Decimal] = None
    stok_minimum: Optional[Decimal] = None
    isi_per_kemasan: Optional[Decimal] = None

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

class OpnameTertundaOut(BaseModel):
    jadwal_shift_id: str
    tanggal: str
    shift: str
    titik: str
    nama_karyawan: str
    belum_ada: List[str]  # ["awal_shift", "akhir_shift"]

    class Config:
        from_attributes = True

# --- OPNAME HARIAN & AUDIT SCHEMAS ---
class ShiftOpnameSnapshotOut(BaseModel):
    shift_key: str
    shift_label: str
    jadwal_shift_id: Optional[str] = None
    karyawan_nama: Optional[str] = None
    stok_awal: Optional[Decimal] = None
    transfer_masuk: Decimal = Decimal('0')
    pemakaian_bom: Decimal = Decimal('0')
    ekspektasi_stok: Optional[Decimal] = None
    stok_akhir: Optional[Decimal] = None
    pemakaian_aktual: Optional[Decimal] = None
    selisih_vs_bom: Optional[Decimal] = None
    status_audit: str = 'belum_lengkap'  # 'sesuai', 'lebih_boros', 'lebih_hemat', 'belum_lengkap'
    diagnosa: str = ''


class ShiftComparisonItemOut(BaseModel):
    bahan_id: str
    nama_bahan: str
    satuan: str
    titik: str
    shift_1: Optional[ShiftOpnameSnapshotOut] = None
    shift_2: Optional[ShiftOpnameSnapshotOut] = None
    selisih_akhir_s1_vs_awal_s2: Optional[Decimal] = None
    selisih_stok_akhir_s1_vs_s2: Optional[Decimal] = None
    selisih_pemakaian_s1_vs_s2: Optional[Decimal] = None
    selisih_varians_s1_vs_s2: Optional[Decimal] = None
    status_handover: str = 'belum_lengkap'  # 'sesuai', 'kurang', 'lebih', 'belum_lengkap'
    catatan_perbandingan: str = ''


class OpnameHarianItemOut(BaseModel):
    bahan_id: str
    nama_bahan: str
    satuan: str
    titik: str
    stok_awal: Optional[Decimal] = None
    transfer_masuk: Decimal = Decimal('0')
    pemakaian_bom: Decimal = Decimal('0')
    ekspektasi_stok: Optional[Decimal] = None
    stok_akhir: Optional[Decimal] = None
    selisih: Optional[Decimal] = None
    selisih_vs_bom: Optional[Decimal] = None
    diagnosa: Optional[str] = None
    status: str  # 'lengkap', 'hanya_awal', 'hanya_akhir', 'belum_opname'

class OpnameHarianSesiOut(BaseModel):
    id: str
    jadwal_shift_id: str
    shift_key: Optional[str] = None
    shift_label: Optional[str] = None
    titik: str
    tipe: str
    metode: str
    karyawan_nama: Optional[str] = None
    waktu_opname: datetime
    catatan: Optional[str] = None
    items_count: int

class OpnameHarianResponse(BaseModel):
    tanggal: str
    titik: Optional[str] = None
    items: List[OpnameHarianItemOut] = []
    sesi: List[OpnameHarianSesiOut] = []
    perbandingan_shift: List[ShiftComparisonItemOut] = []

class BOMItemDetailOut(BaseModel):
    menu_id: str
    nama_menu: str
    qty_terjual: int
    takaran: Decimal
    subtotal_bom: Decimal

class OpnameAuditItemOut(BaseModel):
    bahan_id: str
    nama_bahan: str
    satuan: str
    titik: str
    stok_awal: Optional[Decimal] = None
    transfer_masuk: Decimal = Decimal('0')
    stok_akhir: Optional[Decimal] = None
    pemakaian_fisik: Optional[Decimal] = None
    pemakaian_bom: Decimal = Decimal('0')
    ekspektasi_stok: Optional[Decimal] = None
    selisih_stok_akhir_vs_ekspektasi: Optional[Decimal] = None
    varians: Optional[Decimal] = None
    persentase_selisih: Optional[Decimal] = None
    status_audit: str  # 'sesuai', 'lebih_boros', 'lebih_hemat', 'belum_lengkap'
    diagnosa: str = ''
    penjelasan_diagnosa: str = ''
    detail_menu: List[BOMItemDetailOut] = []

class OpnameAuditSummaryOut(BaseModel):
    total_transaksi: int = 0
    total_item_terjual: int = 0
    total_bahan_diaudit: int = 0
    bahan_sesuai: int = 0
    bahan_selisih: int = 0
    bahan_belum_lengkap: int = 0
    bahan_indikasi_tumpah: int = 0
    bahan_surplus: int = 0
    total_shift_dibandingkan: int = 0
    handover_selisih_count: int = 0

class OpnameAuditResponse(BaseModel):
    tanggal: str
    titik: Optional[str] = None
    summary: OpnameAuditSummaryOut
    items: List[OpnameAuditItemOut] = []
    perbandingan_shift: List[ShiftComparisonItemOut] = []
