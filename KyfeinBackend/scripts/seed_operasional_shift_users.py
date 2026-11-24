"""Seed idempoten akun karyawan (5 akun baru + set password admin), shift template/jadwal tgl 18-19 Nov 2026, request off kasir, dan biaya operasional bulanan cafe (Listrik & Air)."""

from __future__ import annotations

import asyncio
from datetime import date, time
from decimal import Decimal
from pathlib import Path
import sys
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import and_, delete, select

from app.core.database import AsyncSessionLocal
from app.core.security import get_password_hash
from app.models.jadwal import JadwalShift, RequestOff, ShiftTemplate
from app.models.karyawan import Karyawan
from app.models.master_data import KategoriPengeluaran
from app.models.pengeluaran import Pengeluaran

ADMIN_EMAIL = "fransciesco.steinlie@gmail.com"
ADMIN_PASS = "admin123"

NEW_STAFF_ACCOUNTS = [
    ("Kasir 2", "kasir2@kyfein.com", "kasir", "081200000102", "kasir123"),
    ("Bar 1", "bar1@kyfein.com", "bar", "081200000201", "bar123"),
    ("Bar 2", "bar2@kyfein.com", "bar", "081200000202", "bar123"),
    ("Kitchen 1", "kitchen1@kyfein.com", "kitchen", "081200000301", "kitchen123"),
    ("Kitchen 2", "kitchen2@kyfein.com", "kitchen", "081200000302", "kitchen123"),
]

SHIFT_TEMPLATE_SPECS = [
    ("shift_1", "Shift 1", time(7, 0), time(15, 0)),
    ("shift_2", "Shift 2", time(15, 0), time(23, 0)),
    ("middle", "Middle", time(8, 0), time(23, 0)),
]

TGL_TODAY = date(2026, 11, 18)
TGL_TOMORROW = date(2026, 11, 19)
BULAN_OPEX = date(2026, 11, 1)

OPEX_SPECS = [
    (
        "Listrik Cafe",
        Decimal("300000.00"),
        "Tagihan listrik cafe November 2026 (pro-rata Rp 10.000/hari)",
    ),
    (
        "Air Cafe",
        Decimal("150000.00"),
        "Tagihan air PDAM cafe November 2026 (pro-rata Rp 5.000/hari)",
    ),
]


async def upsert_shift_schedule(
    db,
    karyawan_id: str,
    tanggal: date,
    template: ShiftTemplate,
    area_kerja: str,
    admin_id: str,
) -> JadwalShift:
    existing = (
        await db.execute(
            select(JadwalShift).where(
                and_(
                    JadwalShift.karyawan_id == karyawan_id,
                    JadwalShift.tanggal == tanggal,
                )
            )
        )
    ).scalars().first()
    if existing:
        existing.shift = template.shift
        existing.area_kerja = area_kerja
        existing.shift_template_id = template.id
        existing.jam_mulai = template.jam_mulai
        existing.jam_selesai = template.jam_selesai
        return existing

    item = JadwalShift(
        id=str(uuid.uuid4()),
        karyawan_id=karyawan_id,
        tanggal=tanggal,
        shift=template.shift,
        area_kerja=area_kerja,
        shift_template_id=template.id,
        jam_mulai=template.jam_mulai,
        jam_selesai=template.jam_selesai,
        dibuat_oleh=admin_id,
    )
    db.add(item)
    return item


async def main() -> None:
    async with AsyncSessionLocal() as db:
        # 1. Admin account password
        admin = (
            await db.execute(select(Karyawan).where(Karyawan.email == ADMIN_EMAIL))
        ).scalars().first()
        if not admin:
            raise RuntimeError(f"Admin {ADMIN_EMAIL} tidak ditemukan di db_kyfein")
        admin.password = get_password_hash(ADMIN_PASS)
        admin.status_aktif = True

        # Existing Kasir 1 (Dila / fransciescos@gmail.com)
        kasir_existing = (
            await db.execute(
                select(Karyawan)
                .where(Karyawan.role == "karyawan", Karyawan.divisi == "kasir")
                .order_by(Karyawan.created_at.asc())
            )
        ).scalars().first()
        if not kasir_existing:
            raise RuntimeError("Akun kasir awal tidak ditemukan")

        # 2. Upsert 5 new staff accounts
        staff_by_email: dict[str, Karyawan] = {}
        for nama, email, divisi, hp, raw_pw in NEW_STAFF_ACCOUNTS:
            user = (
                await db.execute(select(Karyawan).where(Karyawan.email == email))
            ).scalars().first()
            if user:
                user.nama = nama
                user.divisi = divisi
                user.role = "karyawan"
                user.status_aktif = True
                user.password = get_password_hash(raw_pw)
            else:
                # Ensure unique phone
                hp_use = hp
                hp_exists = (
                    await db.execute(select(Karyawan).where(Karyawan.nomor_hp == hp_use))
                ).scalars().first()
                if hp_exists:
                    hp_use = None
                user = Karyawan(
                    id=str(uuid.uuid4()),
                    nama=nama,
                    email=email,
                    nomor_hp=hp_use,
                    role="karyawan",
                    divisi=divisi,
                    password=get_password_hash(raw_pw),
                    status_aktif=True,
                )
                db.add(user)
                await db.flush()
            staff_by_email[email] = user

        # 3. Upsert Shift Templates
        tpl_by_key: dict[str, ShiftTemplate] = {}
        for key, nama, mulai, selesai in SHIFT_TEMPLATE_SPECS:
            tpl = (
                await db.execute(select(ShiftTemplate).where(ShiftTemplate.shift == key))
            ).scalars().first()
            if tpl:
                tpl.nama = nama
                tpl.jam_mulai = mulai
                tpl.jam_selesai = selesai
            else:
                tpl = ShiftTemplate(
                    id=str(uuid.uuid4()),
                    shift=key,
                    nama=nama,
                    jam_mulai=mulai,
                    jam_selesai=selesai,
                )
                db.add(tpl)
                await db.flush()
            tpl_by_key[key] = tpl

        s1 = tpl_by_key["shift_1"]
        s2 = tpl_by_key["shift_2"]
        sm = tpl_by_key["middle"]

        kasir1 = kasir_existing
        kasir2 = staff_by_email["kasir2@kyfein.com"]
        bar1 = staff_by_email["bar1@kyfein.com"]
        bar2 = staff_by_email["bar2@kyfein.com"]
        kitchen1 = staff_by_email["kitchen1@kyfein.com"]
        kitchen2 = staff_by_email["kitchen2@kyfein.com"]

        # 4. Jadwal Shift tgl 18 Nov 2026 (2 shift per Kasir, Bar, Kitchen)
        await db.execute(
            delete(RequestOff).where(
                and_(
                    RequestOff.karyawan_id.in_(
                        [kasir1.id, kasir2.id, bar1.id, bar2.id, kitchen1.id, kitchen2.id]
                    ),
                    RequestOff.tanggal == TGL_TODAY,
                )
            )
        )
        for kary, tpl, area in [
            (kasir1, s1, "kasir"),
            (kasir2, s2, "kasir"),
            (bar1, s1, "bar"),
            (bar2, s2, "bar"),
            (kitchen1, s1, "kitchen"),
            (kitchen2, s2, "kitchen"),
        ]:
            await upsert_shift_schedule(db, kary.id, TGL_TODAY, tpl, area, admin.id)

        # 5. Hari besok 19 Nov 2026:
        # Kasir 1 (Dila) Request Off -> hapus jadwal tgl 19 jika ada, buat RequestOff
        await db.execute(
            delete(JadwalShift).where(
                and_(
                    JadwalShift.karyawan_id == kasir1.id,
                    JadwalShift.tanggal == TGL_TOMORROW,
                )
            )
        )
        req_off = (
            await db.execute(
                select(RequestOff).where(
                    and_(
                        RequestOff.karyawan_id == kasir1.id,
                        RequestOff.tanggal == TGL_TOMORROW,
                    )
                )
            )
        ).scalars().first()
        if req_off:
            req_off.alasan = "Request libur kasir"
        else:
            db.add(
                RequestOff(
                    id=str(uuid.uuid4()),
                    karyawan_id=kasir1.id,
                    tanggal=TGL_TOMORROW,
                    alasan="Request libur kasir",
                )
            )

        # Kasir 2 kerja Middle 08:00-23:00; Bar & Kitchen tetap 2 shift
        for kary, tpl, area in [
            (kasir2, sm, "kasir"),
            (bar1, s1, "bar"),
            (bar2, s2, "bar"),
            (kitchen1, s1, "kitchen"),
            (kitchen2, s2, "kitchen"),
        ]:
            await db.execute(
                delete(RequestOff).where(
                    and_(
                        RequestOff.karyawan_id == kary.id,
                        RequestOff.tanggal == TGL_TOMORROW,
                    )
                )
            )
            await upsert_shift_schedule(db, kary.id, TGL_TOMORROW, tpl, area, admin.id)

        # 6. Kategori & Biaya Operasional Bulanan (Listrik Cafe 300k & Air Cafe 150k -> Nov 2026)
        for kat_nama, nominal, ket in OPEX_SPECS:
            kat = (
                await db.execute(
                    select(KategoriPengeluaran).where(KategoriPengeluaran.nama == kat_nama)
                )
            ).scalars().first()
            if kat:
                kat.status_aktif = True
            else:
                kat = KategoriPengeluaran(
                    id=str(uuid.uuid4()),
                    nama=kat_nama,
                    status_aktif=True,
                )
                db.add(kat)
                await db.flush()

            peng = (
                await db.execute(
                    select(Pengeluaran).where(
                        and_(
                            Pengeluaran.kategori_id == kat.id,
                            Pengeluaran.tipe == "bulanan",
                            Pengeluaran.bulan == BULAN_OPEX,
                        )
                    )
                )
            ).scalars().first()
            if peng:
                peng.nominal = nominal
                peng.keterangan = ket
                peng.dicatat_oleh = admin.id
            else:
                db.add(
                    Pengeluaran(
                        id=str(uuid.uuid4()),
                        kategori_id=kat.id,
                        tipe="bulanan",
                        nominal=nominal,
                        bulan=BULAN_OPEX,
                        tanggal=None,
                        keterangan=ket,
                        dicatat_oleh=admin.id,
                    )
                )

        await db.commit()
        print("SEED SUKSES: Akun, Shift Template, Jadwal 18-19 Nov, Request Off, & Opex Listrik+Air berhasil disimpan.")


if __name__ == "__main__":
    asyncio.run(main())

