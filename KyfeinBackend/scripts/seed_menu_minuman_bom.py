"""Seed idempoten 14 bahan baku, 23 menu minuman, dan resep BOM ke db_kyfein."""

import asyncio
from decimal import Decimal
from pathlib import Path
import sys
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import delete, select

from app.core.database import AsyncSessionLocal
from app.models.karyawan import Karyawan
from app.models.master_data import Bahan, KategoriMenu, Menu, MenuResep
from app.models.stok import StokGudang, StokTitik


BAHAN_SPECS = [
    ("Cup", "pcs", Decimal("50.000"), Decimal("100.000")),
    ("Bean", "gr", Decimal("1000.000"), Decimal("50.000")),
    ("SKM", "gram", Decimal("1000.000"), Decimal("50.000")),
    ("UHT", "ml", Decimal("1000.000"), Decimal("50.000")),
    ("Pandan", "ml", Decimal("700.000"), Decimal("5.000")),
    ("Vanila", "ml", Decimal("760.000"), Decimal("50.000")),
    ("Coconut", "ml", Decimal("760.000"), Decimal("50.000")),
    ("Chocolate", "gram", Decimal("1000.000"), Decimal("10.000")),
    ("Matcha", "gram", Decimal("1000.000"), Decimal("10.000")),
    ("Creamer", "gram", Decimal("500.000"), Decimal("10.000")),
    ("Salted Caramel", "gram", Decimal("1000.000"), Decimal("10.000")),
    ("Butterscotch", "gram", Decimal("1000.000"), Decimal("10.000")),
    ("Strawberry", "gram", Decimal("2300.000"), Decimal("10.000")),
    ("Aren", "ml", Decimal("1000.000"), Decimal("10.000")),
]


MENU_MINUMAN_SPECS = [
    (
        "MNM01",
        "Coffee Latte",
        Decimal("11000.00"),
        [("Cup", 1), ("SKM", 20), ("UHT", 130), ("Bean", 18)],
    ),
    (
        "MNM02",
        "Kopi Susu Gula Aren",
        Decimal("13000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Aren", 15), ("Bean", 18)],
    ),
    (
        "MNM03",
        "Americano",
        Decimal("8000.00"),
        [("Cup", 1), ("Bean", 18)],
    ),
    (
        "MNM04",
        "Americano Gula Aren",
        Decimal("11000.00"),
        [("Cup", 1), ("Aren", 15), ("Bean", 18)],
    ),
    (
        "MNM05",
        "Coconut Aren Latte",
        Decimal("14000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Coconut", 15), ("Bean", 18)],
    ),
    (
        "MNM06",
        "Vanila Latte",
        Decimal("13000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Vanila", 15), ("Bean", 18)],
    ),
    (
        "MNM07",
        "Mochacino",
        Decimal("13000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Chocolate", 15), ("Bean", 18)],
    ),
    (
        "MNM08",
        "Kayuhan Creamy Latte",
        Decimal("13000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Creamer", 15), ("Bean", 18)],
    ),
    (
        "MNM09",
        "Salted Caramel Latte",
        Decimal("13000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Salted Caramel", 15), ("Bean", 18)],
    ),
    (
        "MNM10",
        "Pandan Latte",
        Decimal("13000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Pandan", 15), ("Bean", 18)],
    ),
    (
        "MNM11",
        "Alpenliebe Butterscotch",
        Decimal("14000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Butterscotch", 15), ("Bean", 18)],
    ),
    (
        "MNM12",
        "Kayuhan Signature",
        Decimal("16000.00"),
        [
            ("Cup", 1),
            ("SKM", 5),
            ("UHT", 130),
            ("Coconut", 5),
            ("Pandan", 10),
            ("Bean", 18),
        ],
    ),
    (
        "MNM13",
        "Chocolate",
        Decimal("12000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Chocolate", 15)],
    ),
    (
        "MNM14",
        "Choco Caramel",
        Decimal("14000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Chocolate", 15), ("Salted Caramel", 15)],
    ),
    (
        "MNM15",
        "Choco Vanila",
        Decimal("14000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Chocolate", 15), ("Vanila", 15)],
    ),
    (
        "MNM16",
        "Choco Butterscotch",
        Decimal("15000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Chocolate", 15), ("Butterscotch", 15)],
    ),
    (
        "MNM17",
        "Matcha Original",
        Decimal("15000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Matcha", 15)],
    ),
    (
        "MNM18",
        "Matcha Vanilla",
        Decimal("15000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Matcha", 15), ("Vanila", 15)],
    ),
    (
        "MNM19",
        "Matcha Caramel",
        Decimal("15000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Matcha", 15), ("Salted Caramel", 15)],
    ),
    (
        "MNM20",
        "Matcha Butterscotch",
        Decimal("16000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Matcha", 15), ("Butterscotch", 15)],
    ),
    (
        "MNM21",
        "Matcha Strawberry",
        Decimal("16000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Matcha", 15), ("Strawberry", 25)],
    ),
    (
        "MNM22",
        "Korean Strawberry Milk",
        Decimal("13000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Strawberry", 25)],
    ),
    (
        "MNM23",
        "Strawberry Vanilla",
        Decimal("16000.00"),
        [("Cup", 1), ("SKM", 15), ("UHT", 130), ("Strawberry", 25), ("Vanila", 10)],
    ),
]


async def _ensure_kategori_minuman(db) -> KategoriMenu:
    res = await db.execute(select(KategoriMenu).where(KategoriMenu.nama == "Minuman"))
    kat = res.scalars().first()
    if not kat:
        kat = KategoriMenu(
            id=str(uuid.uuid4()),
            nama="Minuman",
            area_produksi="bar",
            status_aktif=True,
        )
        db.add(kat)
        await db.flush()
    return kat


async def _ensure_stok_rows(db, bahan_id: str) -> None:
    sg_res = await db.execute(select(StokGudang).where(StokGudang.bahan_id == bahan_id))
    if not sg_res.scalars().first():
        db.add(
            StokGudang(
                id=str(uuid.uuid4()),
                bahan_id=bahan_id,
                jumlah_kemasan_besar=0,
                jumlah_satuan_kecil=Decimal("0.000"),
            )
        )
    for titik in ("bar", "kitchen"):
        st_res = await db.execute(
            select(StokTitik).where(StokTitik.bahan_id == bahan_id, StokTitik.titik == titik)
        )
        if not st_res.scalars().first():
            db.add(
                StokTitik(
                    id=str(uuid.uuid4()),
                    bahan_id=bahan_id,
                    titik=titik,
                    jumlah=Decimal("0.000"),
                )
            )


async def seed() -> None:
    async with AsyncSessionLocal() as db:
        kat_minuman = await _ensure_kategori_minuman(db)
        admin_res = await db.execute(select(Karyawan).where(Karyawan.role == "admin"))
        admin = admin_res.scalars().first()
        admin_id = admin.id if admin else None

        existing_bahan_res = await db.execute(select(Bahan))
        bahan_by_name = {b.nama.lower(): b for b in existing_bahan_res.scalars().all()}
        bahan_map = {}

        for nama, satuan, isi_kemasan, stok_min in BAHAN_SPECS:
            existing = bahan_by_name.get(nama.lower())
            if existing:
                existing.nama = nama
                existing.satuan = satuan
                existing.isi_per_kemasan = isi_kemasan
                existing.stok_minimum = stok_min
                if existing.harga_rata_rata is None:
                    existing.harga_rata_rata = Decimal("0.00")
                bahan_obj = existing
            else:
                bahan_obj = Bahan(
                    id=str(uuid.uuid5(uuid.NAMESPACE_DNS, f"kyfein.bahan.{nama.lower()}")),
                    nama=nama,
                    satuan=satuan,
                    isi_per_kemasan=isi_kemasan,
                    stok_minimum=stok_min,
                    harga_rata_rata=Decimal("0.00"),
                )
                db.add(bahan_obj)
                await db.flush()

            await _ensure_stok_rows(db, bahan_obj.id)
            bahan_map[nama] = bahan_obj

        existing_menu_res = await db.execute(select(Menu))
        menu_by_kode = {m.kode_menu: m for m in existing_menu_res.scalars().all()}

        created_count = 0
        updated_count = 0

        for kode, nama, harga, bom_items in MENU_MINUMAN_SPECS:
            menu = menu_by_kode.get(kode)
            if menu:
                menu.nama = nama
                menu.harga = harga
                menu.kategori_id = kat_minuman.id
                menu.status_aktif = True
                menu.diubah_oleh = admin_id
                updated_count += 1
            else:
                menu = Menu(
                    id=str(uuid.uuid5(uuid.NAMESPACE_DNS, f"kyfein.menu.{kode.lower()}")),
                    nama=nama,
                    kode_menu=kode,
                    harga=harga,
                    kategori_id=kat_minuman.id,
                    status_aktif=True,
                    dibuat_oleh=admin_id,
                )
                db.add(menu)
                await db.flush()
                created_count += 1

            await db.execute(delete(MenuResep).where(MenuResep.menu_id == menu.id))
            for bahan_nama, qty in bom_items:
                db.add(
                    MenuResep(
                        id=str(uuid.uuid4()),
                        menu_id=menu.id,
                        bahan_id=bahan_map[bahan_nama].id,
                        jumlah_terpakai=Decimal(str(qty)),
                    )
                )

        await db.commit()
        print(
            f"Seed selesai: {len(BAHAN_SPECS)} bahan baku, "
            f"{created_count} menu baru, {updated_count} menu diperbarui."
        )


if __name__ == "__main__":
    asyncio.run(seed())
