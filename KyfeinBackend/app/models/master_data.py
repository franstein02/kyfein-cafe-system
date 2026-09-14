from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Numeric, Enum as SQLEnum, ForeignKey, JSON
from sqlalchemy.orm import relationship
from app.models.base import Base, generate_uuid

class KonfigurasiLokasi(Base):
    __tablename__ = "konfigurasi_lokasi"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    latitude = Column(Numeric(11, 8), nullable=False)
    longitude = Column(Numeric(11, 8), nullable=False)
    radius_meter = Column(Numeric(10, 2), nullable=False, default=50)
    updated_by = Column(String(36), ForeignKey("karyawan.id", ondelete="SET NULL"), nullable=True)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    updater = relationship("Karyawan", foreign_keys=[updated_by])

class KategoriMenu(Base):
    __tablename__ = "kategori_menu"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    nama = Column(String(50), nullable=False, unique=True)
    area_produksi = Column(SQLEnum('bar', 'kitchen', name='enum_area_produksi'), nullable=False)
    status_aktif = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

class Menu(Base):
    __tablename__ = "menu"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    nama = Column(String(100), nullable=False)
    kode_menu = Column(String(20), nullable=False, unique=True)
    harga = Column(Numeric(14, 2), nullable=False, default=0)
    kategori_id = Column(String(36), ForeignKey("kategori_menu.id", ondelete="RESTRICT"), nullable=False)
    foto = Column(String(500), nullable=True)
    status_aktif = Column(Boolean, nullable=False, default=True)
    dibuat_oleh = Column(String(36), ForeignKey("karyawan.id", ondelete="SET NULL"), nullable=True)
    diubah_oleh = Column(String(36), ForeignKey("karyawan.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    kategori = relationship("KategoriMenu")
    pembuat = relationship("Karyawan", foreign_keys=[dibuat_oleh])
    pengubah = relationship("Karyawan", foreign_keys=[diubah_oleh])

class Bahan(Base):
    __tablename__ = "bahan"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    nama = Column(String(100), nullable=False)
    satuan = Column(String(20), nullable=False)
    isi_per_kemasan = Column(Numeric(10, 3), nullable=True)
    harga_rata_rata = Column(Numeric(14, 2), nullable=False, default=0)
    stok_minimum = Column(Numeric(10, 3), nullable=False, default=0)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

class MenuResep(Base):
    __tablename__ = "menu_resep"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    menu_id = Column(String(36), ForeignKey("menu.id", ondelete="CASCADE"), nullable=False)
    bahan_id = Column(String(36), ForeignKey("bahan.id", ondelete="RESTRICT"), nullable=False)
    jumlah_terpakai = Column(Numeric(10, 3), nullable=False)

    menu = relationship("Menu")
    bahan = relationship("Bahan")

class KategoriPengeluaran(Base):
    __tablename__ = "kategori_pengeluaran"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    nama = Column(String(50), nullable=False, unique=True)
    status_aktif = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

class AuditLogKonfigurasi(Base):
    __tablename__ = "audit_log_konfigurasi"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    tabel = Column(String(50), nullable=False)
    row_id = Column(String(36), nullable=False)
    data_lama = Column(JSON, nullable=True)
    data_baru = Column(JSON, nullable=True)
    diubah_oleh = Column(String(36), ForeignKey("karyawan.id", ondelete="SET NULL"), nullable=True)
    diubah_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    pengubah = relationship("Karyawan", foreign_keys=[diubah_oleh])
