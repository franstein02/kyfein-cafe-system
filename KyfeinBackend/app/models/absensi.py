from datetime import datetime
from sqlalchemy import Column, String, DateTime, Numeric, Integer, Enum as SQLEnum, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.models.base import Base, generate_uuid
from app.core.utils import now_local

class IzinTelat(Base):
    __tablename__ = "izin_telat"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    karyawan_id = Column(String(36), ForeignKey("karyawan.id", ondelete="RESTRICT"), nullable=False)
    jadwal_shift_id = Column(String(36), ForeignKey("jadwal_shift.id", ondelete="RESTRICT"), nullable=False)
    alasan = Column(Text, nullable=False)
    foto_id = Column(String(36), ForeignKey("foto.id", ondelete="SET NULL"), nullable=True)
    status = Column(SQLEnum('pending', 'disetujui', 'ditolak', name='enum_izin_telat_status'), nullable=False, default='pending')
    diajukan_at = Column(DateTime, nullable=False, default=now_local)
    diproses_oleh = Column(String(36), ForeignKey("karyawan.id", ondelete="SET NULL"), nullable=True)
    diproses_at = Column(DateTime, nullable=True)

    karyawan = relationship("Karyawan", foreign_keys=[karyawan_id])
    jadwal_shift = relationship("JadwalShift")
    pemroses = relationship("Karyawan", foreign_keys=[diproses_oleh])
    foto = relationship("Foto", foreign_keys=[foto_id])

class IzinTidakMasuk(Base):
    __tablename__ = "izin_tidak_masuk"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    karyawan_id = Column(String(36), ForeignKey("karyawan.id", ondelete="RESTRICT"), nullable=False)
    jadwal_shift_id = Column(String(36), ForeignKey("jadwal_shift.id", ondelete="RESTRICT"), nullable=False)
    alasan = Column(Text, nullable=False)
    foto_id = Column(String(36), ForeignKey("foto.id", ondelete="RESTRICT"), nullable=False)
    status = Column(SQLEnum('pending', 'disetujui', 'ditolak', name='enum_izin_tidak_masuk_status'), nullable=False, default='pending')
    diajukan_at = Column(DateTime, nullable=False, default=now_local)
    diproses_oleh = Column(String(36), ForeignKey("karyawan.id", ondelete="SET NULL"), nullable=True)
    diproses_at = Column(DateTime, nullable=True)

    karyawan = relationship("Karyawan", foreign_keys=[karyawan_id])
    jadwal_shift = relationship("JadwalShift")
    pemroses = relationship("Karyawan", foreign_keys=[diproses_oleh])
    foto = relationship("Foto", foreign_keys=[foto_id])

class Absensi(Base):
    __tablename__ = "absensi"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    karyawan_id = Column(String(36), ForeignKey("karyawan.id", ondelete="RESTRICT"), nullable=False)
    jadwal_shift_id = Column(String(36), ForeignKey("jadwal_shift.id", ondelete="RESTRICT"), nullable=False, unique=True)
    jam_masuk = Column(DateTime, nullable=False, default=now_local)
    jam_pulang = Column(DateTime, nullable=True)
    lat_masuk = Column(Numeric(11, 8), nullable=False)
    lng_masuk = Column(Numeric(11, 8), nullable=False)
    lat_pulang = Column(Numeric(11, 8), nullable=True)
    lng_pulang = Column(Numeric(11, 8), nullable=True)
    foto_masuk_id = Column(String(36), ForeignKey("foto.id", ondelete="RESTRICT"), nullable=False)
    foto_pulang_id = Column(String(36), ForeignKey("foto.id", ondelete="SET NULL"), nullable=True)
    menit_telat = Column(Integer, nullable=False, default=0)
    izin_telat_id = Column(String(36), ForeignKey("izin_telat.id", ondelete="SET NULL"), nullable=True)
    status_pulang = Column(SQLEnum('tepat_waktu', 'telat', 'lupa_absen', name='enum_status_pulang'), nullable=True)
    created_at = Column(DateTime, nullable=False, default=now_local)

    karyawan = relationship("Karyawan")
    jadwal_shift = relationship("JadwalShift")
    izin_telat = relationship("IzinTelat")
    foto_masuk = relationship("Foto", foreign_keys=[foto_masuk_id])
    foto_pulang = relationship("Foto", foreign_keys=[foto_pulang_id])
