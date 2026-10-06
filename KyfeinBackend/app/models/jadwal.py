from datetime import datetime
from sqlalchemy import Column, String, Date, Time, DateTime, Enum as SQLEnum, ForeignKey, Text, UniqueConstraint
from sqlalchemy.orm import relationship
from app.models.base import Base, generate_uuid
from app.core.utils import now_local

class ShiftTemplate(Base):
    __tablename__ = "shift_template"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    shift = Column(SQLEnum('shift_1', 'shift_2', name='enum_shift_type'), nullable=False, unique=True)
    jam_mulai = Column(Time, nullable=False)
    jam_selesai = Column(Time, nullable=False)
    updated_at = Column(DateTime, nullable=False, default=now_local, onupdate=now_local)

class JadwalShift(Base):
    __tablename__ = "jadwal_shift"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    karyawan_id = Column(String(36), ForeignKey("karyawan.id", ondelete="RESTRICT"), nullable=False)
    tanggal = Column(Date, nullable=False)
    shift = Column(SQLEnum('shift_1', 'shift_2', name='enum_shift_type'), nullable=False)
    area_kerja = Column(SQLEnum('kasir', 'bar', 'kitchen', name='enum_area_kerja'), nullable=False) # [FIX-2]
    shift_template_id = Column(String(36), ForeignKey("shift_template.id", ondelete="SET NULL"), nullable=True)
    jam_mulai = Column(Time, nullable=False)
    jam_selesai = Column(Time, nullable=False)
    dibuat_oleh = Column(String(36), ForeignKey("karyawan.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, nullable=False, default=now_local)
    updated_at = Column(DateTime, nullable=False, default=now_local, onupdate=now_local)

    karyawan = relationship("Karyawan", foreign_keys=[karyawan_id])
    pembuat = relationship("Karyawan", foreign_keys=[dibuat_oleh])
    shift_template = relationship("ShiftTemplate")

class TukarShift(Base):
    __tablename__ = "tukar_shift"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    shift_a_id = Column(String(36), ForeignKey("jadwal_shift.id", ondelete="RESTRICT"), nullable=False)
    shift_b_id = Column(String(36), ForeignKey("jadwal_shift.id", ondelete="RESTRICT"), nullable=False)
    karyawan_pengaju_id = Column(String(36), ForeignKey("karyawan.id", ondelete="RESTRICT"), nullable=False)
    karyawan_target_id = Column(String(36), ForeignKey("karyawan.id", ondelete="RESTRICT"), nullable=False)
    status = Column(SQLEnum('pending', 'disetujui', 'ditolak', name='enum_tukar_shift_status'), nullable=False, default='pending')
    alasan = Column(Text, nullable=True)
    diajukan_at = Column(DateTime, nullable=False, default=now_local)
    diproses_oleh = Column(String(36), ForeignKey("karyawan.id", ondelete="SET NULL"), nullable=True)
    diproses_at = Column(DateTime, nullable=True)

    shift_a = relationship("JadwalShift", foreign_keys=[shift_a_id])
    shift_b = relationship("JadwalShift", foreign_keys=[shift_b_id])
    pengaju = relationship("Karyawan", foreign_keys=[karyawan_pengaju_id])
    target = relationship("Karyawan", foreign_keys=[karyawan_target_id])
    pemroses = relationship("Karyawan", foreign_keys=[diproses_oleh])

class RequestOff(Base):
    __tablename__ = "request_off"
    __table_args__ = (
        UniqueConstraint("karyawan_id", "tanggal", name="uq_request_off_karyawan_tanggal"),
    )

    id = Column(String(36), primary_key=True, default=generate_uuid)
    karyawan_id = Column(String(36), ForeignKey("karyawan.id", ondelete="RESTRICT"), nullable=False)
    tanggal = Column(Date, nullable=False)
    alasan = Column(Text, nullable=True)
    diajukan_at = Column(DateTime, nullable=False, default=now_local)

    karyawan = relationship("Karyawan")
