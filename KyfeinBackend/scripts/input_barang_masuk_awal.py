"""Input barang masuk awal 14 bahan baku sesuai rincian pembelian ke db_kyfein."""

import asyncio
from decimal import Decimal
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select

from app.api.v1.endpoints.stok import record_barang_masuk
from app.core.database import AsyncSessionLocal
from app.models.karyawan import Karyawan
from app.models.master_data import Bahan
from app.models.stok import BarangMasuk, StokGudang
from app.schemas.stok import BarangMasukCreate, BarangMasukItemInput


CATATAN_TRANSAKSI = "Barang masuk awal stok gudang (14 bahan utama)"

# Penyesuaian isi_per_kemasan agar cocok dengan ukuran kemasan pembelian riil
ISI_KEMASAN_UPDATES = {
    "Pandan": Decimal("700.000"),
    "Vanila": Decimal("760.000"),
    "Coconut": Decimal("760.000"),
    "Strawberry": Decimal("2300.000"),
}

# (nama_bahan, jumlah_kemasan_besar, jumlah_satuan_kecil, harga_total)
BARANG_MASUK_SPECS = [
    ("Cup", 25, Decimal("0"), Decimal("350000.00")),
    ("Bean", 0, Decimal("500"), Decimal("100000.00")),
    ("SKM", 16, Decimal("0"), Decimal("650000.00")),
    ("UHT", 12, Decimal("0"), Decimal("290000.00")),
    ("Pandan", 6, Decimal("0"), Decimal("882000.00")),
    ("Vanila", 6, Decimal("0"), Decimal("705000.00")),
    ("Coconut", 6, Decimal("0"), Decimal("693000.00")),
    ("Chocolate", 1, Decimal("0"), Decimal("100000.00")),
    ("Matcha", 1, Decimal("0"), Decimal("110000.00")),
    ("Creamer", 50, Decimal("0"), Decimal("900000.00")),
    ("Salted Caramel", 6, Decimal("0"), Decimal("873000.00")),
    ("Butterscotch", 6, Decimal("0"), Decimal("873000.00")),
    ("Strawberry", 6, Decimal("0"), Decimal("1395000.00")),
    ("Aren", 1, Decimal("0"), Decimal("50000.00")),
]


async def run() -> None:
    async with AsyncSessionLocal() as db:
        existing_bm = (
            await db.execute(
                select(BarangMasuk).where(BarangMasuk.catatan == CATATAN_TRANSAKSI)
            )
        ).scalars().first()
        if existing_bm:
            print(f"Barang masuk '{CATATAN_TRANSAKSI}' sudah tercatat (id={existing_bm.id}). Dilewati.")
            return

        admin = (
            await db.execute(select(Karyawan).where(Karyawan.role == "admin"))
        ).scalars().first()
        if not admin:
            raise RuntimeError("Akun admin tidak ditemukan di tabel karyawan.")

        all_bahan = (await db.execute(select(Bahan))).scalars().all()
        bahan_by_name = {b.nama.lower(): b for b in all_bahan}

        for nama, isi_baru in ISI_KEMASAN_UPDATES.items():
            b = bahan_by_name.get(nama.lower())
            if not b:
                raise RuntimeError(f"Bahan '{nama}' tidak ditemukan di database.")
            b.isi_per_kemasan = isi_baru
        await db.flush()

        items = []
        for nama, kemasan, satuan_kecil, harga_total in BARANG_MASUK_SPECS:
            b = bahan_by_name.get(nama.lower())
            if not b:
                raise RuntimeError(f"Bahan '{nama}' tidak ditemukan di database.")
            items.append(
                BarangMasukItemInput(
                    bahan_id=b.id,
                    jumlah_kemasan_besar=kemasan,
                    jumlah_satuan_kecil=satuan_kecil,
                    harga_total=harga_total,
                )
            )

        bm_out = await record_barang_masuk(
            data=BarangMasukCreate(catatan=CATATAN_TRANSAKSI, items=items),
            db=db,
            current_user=admin,
        )
        print(
            f"Barang masuk berhasil disimpan: id={bm_out.id}, "
            f"total_item={len(bm_out.details)}"
        )


async def verify() -> None:
    async with AsyncSessionLocal() as db:
        rows = (
            await db.execute(
                select(Bahan, StokGudang)
                .join(StokGudang, StokGudang.bahan_id == Bahan.id)
                .order_by(Bahan.nama)
            )
        ).all()
        for b, sg in rows:
            isi = Decimal(str(b.isi_per_kemasan or 1))
            total_kecil = Decimal(str(sg.jumlah_kemasan_besar)) * isi + Decimal(str(sg.jumlah_satuan_kecil))
            print(
                f" - {b.nama}: {sg.jumlah_kemasan_besar} kemasan + {sg.jumlah_satuan_kecil} {b.satuan} "
                f"(isi={b.isi_per_kemasan} {b.satuan}, total={total_kecil} {b.satuan}) "
                f"| HPP avg=Rp {b.harga_rata_rata}/{b.satuan}"
            )


async def main() -> None:
    await run()
    await verify()


if __name__ == "__main__":
    asyncio.run(main())
