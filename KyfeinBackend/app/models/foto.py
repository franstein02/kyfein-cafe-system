from sqlalchemy import Column, String, Boolean, DateTime, Enum as SQLEnum, ForeignKey, Index
from sqlalchemy.orm import relationship
from app.models.base import Base, generate_uuid
from app.core.utils import now_local

class Foto(Base):
    __tablename__ = "foto"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    jenis = Column(SQLEnum('absensi', 'izin', 'qris', 'menu', 'profil', name='enum_foto_jenis'), nullable=False)
    path = Column(String(500), nullable=False)
    uploader_id = Column(String(36), ForeignKey("karyawan.id", ondelete="RESTRICT"), nullable=False)
    dipakai = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, nullable=False, default=now_local)

    uploader = relationship("Karyawan", foreign_keys=[uploader_id])

    __table_args__ = (
        Index("idx_foto_dipakai_created", "dipakai", "created_at"),
    )
