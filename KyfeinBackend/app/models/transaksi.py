from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, Numeric, Enum as SQLEnum, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.models.base import Base, generate_uuid

class Transaksi(Base):
    __tablename__ = "transaksi"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    jadwal_shift_id = Column(String(36), ForeignKey("jadwal_shift.id"), nullable=False)
    kasir_id = Column(String(36), ForeignKey("karyawan.id"), nullable=False)
    nomor_transaksi = Column(String(30), nullable=False, unique=True)
    metode_bayar = Column(SQLEnum('cash', 'qris', name='enum_metode_bayar'), nullable=False)
    total_harga = Column(Numeric(14, 2), nullable=False, default=0)
    uang_diterima = Column(Numeric(14, 2), nullable=True)
    kembalian = Column(Numeric(14, 2), nullable=True)
    foto_bukti_qris = Column(String(500), nullable=True)
    status = Column(SQLEnum('selesai', 'dibatalkan', name='enum_status_transaksi'), nullable=False, default='selesai')
    waktu_transaksi = Column(DateTime, nullable=False, default=datetime.utcnow)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    jadwal_shift = relationship("JadwalShift")
    kasir = relationship("Karyawan")
    details = relationship("TransaksiDetail", back_populates="transaksi", cascade="all, delete-orphan")

class TransaksiDetail(Base):
    __tablename__ = "transaksi_detail"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    transaksi_id = Column(String(36), ForeignKey("transaksi.id", ondelete="CASCADE"), nullable=False)
    menu_id = Column(String(36), ForeignKey("menu.id"), nullable=False)
    qty = Column(Integer, nullable=False, default=1)
    harga_satuan = Column(Numeric(14, 2), nullable=False)
    catatan = Column(Text, nullable=True)
    subtotal = Column(Numeric(14, 2), nullable=False)
    status_item = Column(SQLEnum('menunggu', 'diproses', 'selesai', name='enum_status_item'), nullable=False, default='menunggu')

    transaksi = relationship("Transaksi", back_populates="details")
    menu = relationship("Menu")
