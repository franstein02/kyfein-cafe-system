from datetime import datetime
from sqlalchemy import Column, String, Date, DateTime, Numeric, Enum as SQLEnum, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.models.base import Base, generate_uuid

class Pengeluaran(Base):
    __tablename__ = "pengeluaran"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    kategori_id = Column(String(36), ForeignKey("kategori_pengeluaran.id", ondelete="RESTRICT"), nullable=False)
    tipe = Column(SQLEnum('bulanan', 'mendadak', name='enum_tipe_pengeluaran'), nullable=False)
    nominal = Column(Numeric(14, 2), nullable=False)
    bulan = Column(Date, nullable=True) # Wajib kalau tipe='bulanan'
    tanggal = Column(Date, nullable=True) # Wajib kalau tipe='mendadak'
    keterangan = Column(Text, nullable=True)
    dicatat_oleh = Column(String(36), ForeignKey("karyawan.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    kategori = relationship("KategoriPengeluaran")
    pencatat = relationship("Karyawan")
