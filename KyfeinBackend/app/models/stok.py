from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, Numeric, Enum as SQLEnum, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.models.base import Base, generate_uuid

class StokGudang(Base):
    __tablename__ = "stok_gudang"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    bahan_id = Column(String(36), ForeignKey("bahan.id"), nullable=False, unique=True)
    jumlah_kemasan_besar = Column(Integer, nullable=False, default=0)
    jumlah_satuan_kecil = Column(Numeric(10, 3), nullable=False, default=0)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    bahan = relationship("Bahan")

class StokTitik(Base):
    __tablename__ = "stok_titik"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    bahan_id = Column(String(36), ForeignKey("bahan.id"), nullable=False)
    titik = Column(SQLEnum('bar', 'kitchen', name='enum_titik_opname'), nullable=False)
    jumlah = Column(Numeric(10, 3), nullable=False, default=0)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    bahan = relationship("Bahan")

class BarangKeluar(Base):
    __tablename__ = "barang_keluar"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    titik_tujuan = Column(SQLEnum('bar', 'kitchen', name='enum_titik_opname'), nullable=False)
    karyawan_id = Column(String(36), ForeignKey("karyawan.id"), nullable=False)
    waktu = Column(DateTime, nullable=False, default=datetime.utcnow)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    karyawan = relationship("Karyawan")
    details = relationship("BarangKeluarDetail", back_populates="barang_keluar", cascade="all, delete-orphan")

class BarangKeluarDetail(Base):
    __tablename__ = "barang_keluar_detail"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    barang_keluar_id = Column(String(36), ForeignKey("barang_keluar.id", ondelete="CASCADE"), nullable=False)
    bahan_id = Column(String(36), ForeignKey("bahan.id"), nullable=False)
    jumlah = Column(Numeric(10, 3), nullable=False)

    barang_keluar = relationship("BarangKeluar", back_populates="details")
    bahan = relationship("Bahan")

class StokOpname(Base):
    __tablename__ = "stok_opname"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    jadwal_shift_id = Column(String(36), ForeignKey("jadwal_shift.id"), nullable=False)
    titik = Column(SQLEnum('bar', 'kitchen', name='enum_titik_opname'), nullable=False)
    tipe = Column(SQLEnum('awal_shift', 'akhir_shift', name='enum_tipe_opname'), nullable=False)
    metode = Column(SQLEnum('hitung_manual', 'carry_forward', name='enum_metode_opname'), nullable=False)
    karyawan_id = Column(String(36), ForeignKey("karyawan.id"), nullable=False)
    waktu_opname = Column(DateTime, nullable=False, default=datetime.utcnow)
    catatan = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    jadwal_shift = relationship("JadwalShift")
    karyawan = relationship("Karyawan")
    details = relationship("StokOpnameDetail", back_populates="stok_opname", cascade="all, delete-orphan")

class StokOpnameDetail(Base):
    __tablename__ = "stok_opname_detail"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    stok_opname_id = Column(String(36), ForeignKey("stok_opname.id", ondelete="CASCADE"), nullable=False)
    bahan_id = Column(String(36), ForeignKey("bahan.id"), nullable=False)
    jumlah = Column(Numeric(10, 3), nullable=False, default=0)

    stok_opname = relationship("StokOpname", back_populates="details")
    bahan = relationship("Bahan")

class MutasiStok(Base):
    __tablename__ = "mutasi_stok"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    bahan_id = Column(String(36), ForeignKey("bahan.id"), nullable=False)
    titik = Column(SQLEnum('bar', 'kitchen', name='enum_titik_opname'), nullable=True)
    jadwal_shift_id = Column(String(36), ForeignKey("jadwal_shift.id"), nullable=True)
    tipe = Column(String(50), nullable=False, default='selisih_handover')
    jumlah_selisih = Column(Numeric(10, 3), nullable=False)
    keterangan = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    bahan = relationship("Bahan")
