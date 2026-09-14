from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Enum as SQLEnum
from app.models.base import Base, generate_uuid

class Karyawan(Base):
    __tablename__ = "karyawan"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    role = Column(SQLEnum('karyawan', 'admin', 'owner', name='enum_karyawan_role'), nullable=False)
    nama = Column(String(150), nullable=False)
    email = Column(String(150), nullable=False, unique=True, index=True)
    nomor_hp = Column(String(20), nullable=False, unique=True)
    password = Column(String(255), nullable=False)
    foto_profile = Column(String(500), nullable=True)
    status_aktif = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
