from datetime import datetime
from sqlalchemy import Column, String, Date, Time, DateTime, Enum as SQLEnum, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.models.base import Base, generate_uuid

class ShiftTemplate(Base):
    __tablename__ = "shift_template"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    shift = Column(SQLEnum('shift_1', 'shift_2', name='enum_shift_type'), nullable=False, unique=True)
    jam_mulai = Column(Time, nullable=False)
    jam_selesai = Column(Time, nullable=False)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

class JadwalShift(Base):
    __tablename__ = "jadwal_shift"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    karyawan_id = Column(String(36), ForeignKey("karyawan.id"), nullable=False)
    tanggal = Column(Date, nullable=False)
    shift = Column(SQLEnum('shift_1', 'shift_2', name='enum_shift_type'), nullable=False)
    shift_template_id = Column(String(36), ForeignKey("shift_template.id"), nullable=True)
    jam_mulai = Column(Time, nullable=False)
    jam_selesai = Column(Time, nullable=False)
    dibuat_oleh = Column(String(36), ForeignKey("karyawan.id"), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    karyawan = relationship("Karyawan", foreign_keys=[karyawan_id])

class TukarShift(Base):
    __tablename__ = "tukar_shift"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    shift_a_id = Column(String(36), ForeignKey("jadwal_shift.id"), nullable=False)
    shift_b_id = Column(String(36), ForeignKey("jadwal_shift.id"), nullable=False)
    karyawan_pengaju_id = Column(String(36), ForeignKey("karyawan.id"), nullable=False)
    karyawan_target_id = Column(String(36), ForeignKey("karyawan.id"), nullable=False)
    status = Column(SQLEnum('pending', 'disetujui', 'ditolak', name='enum_tukar_shift_status'), nullable=False, default='pending')
    alasan = Column(Text, nullable=True)
    diajukan_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    diproses_oleh = Column(String(36), ForeignKey("karyawan.id"), nullable=True)
    diproses_at = Column(DateTime, nullable=True)

    shift_a = relationship("JadwalShift", foreign_keys=[shift_a_id])
    shift_b = relationship("JadwalShift", foreign_keys=[shift_b_id])
    pengaju = relationship("Karyawan", foreign_keys=[karyawan_pengaju_id])
    target = relationship("Karyawan", foreign_keys=[karyawan_target_id])

class RequestOff(Base):
    __tablename__ = "request_off"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    karyawan_id = Column(String(36), ForeignKey("karyawan.id"), nullable=False)
    tanggal = Column(Date, nullable=False)
    alasan = Column(Text, nullable=True)
    diajukan_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    karyawan = relationship("Karyawan")
