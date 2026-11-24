"""Input barang masuk simulasi fluktuasi harga (naik/turun/stabil tipis) & sisa stok menipis hanya UHT dan SKM."""

import asyncio
from decimal import Decimal
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select

from app.api.v1.endpoints.stok import record_barang_masuk
from app.core.database import AsyncSessionLocal
from app.models.karyawan import Karyawan
from app.models.master_data import Bahan, hitung_batas_minimum_kecil
from app.models.stok import BarangMasuk, StokGudang, StokTitik
from app.schemas.stok import BarangMasukCreate, BarangMasukItemInput


CATATAN_BAR = "Restock bahan Bar (simulasi fluktuasi harga & pemenuhan stok)"
CATATAN_KITCHEN = "Restock bahan Kitchen (simulasi fluktuasi harga & pemenuhan stok)"

# (nama_bahan, jumlah_kemasan_besar, jumlah_satuan_kecil, harga_total)
# Simulasi harga: 10 bahan naik tipis (+3.7% s/d +5.4%), 10 turun tipis (-3.3% s/d -5.6%), 9 stabil.
BARANG_MASUK_BAR = [
    ("UHT", 10, Decimal("0"), Decimal("252000.00")),             # total 22 <= 50 (MENIPIS), +4.3%
    ("SKM", 8, Decimal("0"), Decimal("312000.00")),              # total 24 <= 50 (MENIPIS), -4.0%
    ("Aren", 12, Decimal("0"), Decimal("576000.00")),            # total 13 > 10 (AMAN), -4.0%
    ("Bean", 52, Decimal("0"), Decimal("10816000.00")),          # total 52.5 kem > 50 (AMAN), +4.0%
    ("Butterscotch", 6, Decimal("0"), Decimal("906000.00")),     # total 12 > 10 (AMAN), +3.8%
    ("Chocolate", 11, Decimal("0"), Decimal("1100000.00")),      # total 12 > 10 (AMAN), stabil
    ("Coconut", 46, Decimal("0"), Decimal("5313000.00")),        # total 52 > 50 (AMAN), stabil
    ("Creamer", 10, Decimal("0"), Decimal("180000.00")),         # total 60 > 10 (AMAN), stabil
    ("Cup", 80, Decimal("0"), Decimal("1080000.00")),            # total 105 > 100 (AMAN), -3.6%
    ("Matcha", 11, Decimal("0"), Decimal("1265000.00")),         # total 12 > 10 (AMAN), +4.5%
    ("Pandan", 6, Decimal("0"), Decimal("882000.00")),           # total 12 > 5 (AMAN), stabil
    ("Salted Caramel", 6, Decimal("0"), Decimal("840000.00")),   # total 12 > 10 (AMAN), -3.8%
    ("Strawberry", 6, Decimal("0"), Decimal("1452000.00")),      # total 12 > 10 (AMAN), +4.1%
    ("Vanila", 46, Decimal("0"), Decimal("5198000.00")),         # total 52 > 50 (AMAN), -3.8%
]

BARANG_MASUK_KITCHEN = [
    ("Ayam Fillet", 4, Decimal("0"), Decimal("184000.00")),          # total 9 > 5 (AMAN), +4.5%
    ("Beras Basmati", 2, Decimal("0"), Decimal("430000.00")),        # total 4 > 2 (AMAN), -4.4%
    ("Beras Putih", 3, Decimal("0"), Decimal("217500.00")),          # total 7 > 4 (AMAN), stabil
    ("Bumbu Kebuli & Samin", 2, Decimal("0"), Decimal("100000.00")), # total 5 > 3 (AMAN), stabil
    ("Bumbu Nasi Goreng", 2, Decimal("0"), Decimal("50000.00")),     # total 6 > 4 (AMAN), stabil
    ("Chicken Nugget", 3, Decimal("0"), Decimal("144000.00")),       # total 7 > 4 (AMAN), -4.0%
    ("Daging Kambing", 2, Decimal("0"), Decimal("270000.00")),       # total 5 > 3 (AMAN), +3.8%
    ("Keju & Mentega", 2, Decimal("0"), Decimal("84000.00")),        # total 5 > 3 (AMAN), +5.0%
    ("Kentang Frozen", 4, Decimal("0"), Decimal("136000.00")),       # total 10 > 6 (AMAN), -5.6%
    ("Minyak Goreng", 3, Decimal("0"), Decimal("117000.00")),        # total 8 > 5 (AMAN), +5.4%
    ("Roti Tawar Tebal", 3, Decimal("0"), Decimal("63000.00")),      # total 7 > 4 (AMAN), -4.5%
    ("Saus & Mayones", 2, Decimal("0"), Decimal("60000.00")),        # total 6 > 4 (AMAN), stabil
    ("Sosis Sapi", 3, Decimal("0"), Decimal("174000.00")),           # total 7 > 4 (AMAN), -3.3%
    ("Telur Ayam", 3, Decimal("0"), Decimal("84000.00")),            # total 7 > 4 (AMAN), +3.7%
    ("Tepung & Panir", 2, Decimal("0"), Decimal("40000.00")),        # total 5 > 3 (AMAN), stabil
]


async def _insert_batch(db, admin: Karyawan, bahan_by_name: dict[str, Bahan], catatan: str, specs: list) -> None:
    existing = (
        await db.execute(select(BarangMasuk).where(BarangMasuk.catatan == catatan))
    ).scalars().first()
    if existing:
        print(f"Batch '{catatan}' sudah ada (id={existing.id}). Dilewati.")
        return

    items = []
    for nama, kemasan, satuan_kecil, harga_total in specs:
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

    out = await record_barang_masuk(
        data=BarangMasukCreate(catatan=catatan, items=items),
        db=db,
        current_user=admin,
    )
    print(f"Berhasil simpan batch '{catatan}': id={out.id}, total_item={len(out.details)}")


async def run() -> None:
    async with AsyncSessionLocal() as db:
        admin = (
            await db.execute(select(Karyawan).where(Karyawan.role == "admin"))
        ).scalars().first()
        if not admin:
            raise RuntimeError("Akun admin tidak ditemukan di tabel karyawan.")

        all_bahan = (await db.execute(select(Bahan))).scalars().all()
        bahan_by_name = {b.nama.lower(): b for b in all_bahan}

        await _insert_batch(db, admin, bahan_by_name, CATATAN_BAR, BARANG_MASUK_BAR)
        await _insert_batch(db, admin, bahan_by_name, CATATAN_KITCHEN, BARANG_MASUK_KITCHEN)


async def verify() -> None:
    async with AsyncSessionLocal() as db:
        bahans = (await db.execute(select(Bahan).order_by(Bahan.area, Bahan.nama))).scalars().all()
        sg_map = {s.bahan_id: s for s in (await db.execute(select(StokGudang))).scalars().all()}
        st_list = (await db.execute(select(StokTitik))).scalars().all()

        menipis_names = []
        for b in bahans:
            sg = sg_map.get(b.id)
            isi = Decimal(str(b.isi_per_kemasan or 1))
            tot_g = (
                Decimal(str(sg.jumlah_kemasan_besar)) * isi + Decimal(str(sg.jumlah_satuan_kecil))
                if sg else Decimal("0")
            )
            tot_t = sum((Decimal(str(st.jumlah)) for st in st_list if st.bahan_id == b.id), Decimal("0"))
            batas = hitung_batas_minimum_kecil(b)
            is_menipis = batas > 0 and (tot_g + tot_t) <= batas
            if is_menipis:
                menipis_names.append(b.nama)
            status = "MENIPIS" if is_menipis else "AMAN"
            print(
                f" - [{b.area}] {b.nama}: {sg.jumlah_kemasan_besar if sg else 0} kem + "
                f"{sg.jumlah_satuan_kecil if sg else 0} {b.satuan} "
                f"(tot={tot_g}, min={batas}) | AVG=Rp {b.harga_rata_rata}/{b.satuan} | {status}"
            )
        print(f"=== STOK MENIPIS ({len(menipis_names)}): {menipis_names} ===")


async def main() -> None:
    await run()
    await verify()


if __name__ == "__main__":
    asyncio.run(main())

