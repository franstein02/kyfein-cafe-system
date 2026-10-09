from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Enum as SQLEnum, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import Base, generate_uuid
from app.core.utils import now_local

class Karyawan(Base):
    __tablename__ = "karyawan"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    role = Column(SQLEnum('karyawan', 'admin', name='enum_karyawan_role'), nullable=False)
    nama = Column(String(150), nullable=False)
    email = Column(String(150), nullable=False, unique=True, index=True)
    nomor_hp = Column(String(20), nullable=False, unique=True)
    password = Column(String(255), nullable=False)
    foto_profile_id = Column(String(36), ForeignKey("foto.id", ondelete="SET NULL", use_alter=True, name="fk_karyawan_foto_profile"), nullable=True)
    status_aktif = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=now_local)
    updated_at = Column(DateTime, nullable=False, default=now_local, onupdate=now_local)

    foto_profile = relationship("Foto", foreign_keys=[foto_profile_id], post_update=True)
