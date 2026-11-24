"""Seed idempoten bahan dapur (area='kitchen'), barang masuk awal, menu kitchen (MKN01-MKN08), dan BOM resep berdasarkan research harga grosir HORECA Indonesia."""

import asyncio
from decimal import Decimal
from pathlib import Path
import sys
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import delete, select

from app.api.v1.endpoints.stok import record_barang_masuk
from app.core.database import AsyncSessionLocal
from app.core.transaksi_helper import hitung_hpp_satuan
from app.models.karyawan import Karyawan
from app.models.master_data import Bahan, KategoriMenu, Menu, MenuResep
from app.models.stok import BarangMasuk, StokGudang, StokTitik
from app.schemas.stok import BarangMasukCreate, BarangMasukItemInput


CATATAN_BARANG_MASUK_KITCHEN = "Barang masuk awal stok dapur (15 bahan kitchen - research HORECA)"

# (nama, satuan_kecil, isi_per_kemasan_besar, stok_min_kemasan, kemasan_masuk, harga_total_masuk)
KITCHEN_BAHAN_SPECS = [
    ("Beras Putih", "gram", Decimal("5000.000"), Decimal("4.000"), 4, Decimal("290000.00")),
    ("Beras Basmati", "gram", Decimal("5000.000"), Decimal("2.000"), 2, Decimal("450000.00")),
    ("Ayam Fillet", "gram", Decimal("1000.000"), Decimal("5.000"), 5, Decimal("220000.00")),
    ("Daging Kambing", "gram", Decimal("1000.000"), Decimal("3.000"), 3, Decimal("390000.00")),
    ("Telur Ayam", "pcs", Decimal("15.000"), Decimal("4.000"), 4, Decimal("108000.00")),
    ("Minyak Goreng", "ml", Decimal("2000.000"), Decimal("5.000"), 5, Decimal("185000.00")),
    ("Kentang Frozen", "gram", Decimal("1000.000"), Decimal("6.000"), 6, Decimal("216000.00")),
    ("Sosis Sapi", "gram", Decimal("1000.000"), Decimal("4.000"), 4, Decimal("240000.00")),
    ("Chicken Nugget", "gram", Decimal("1000.000"), Decimal("4.000"), 4, Decimal("200000.00")),
    ("Tepung & Panir", "gram", Decimal("1000.000"), Decimal("3.000"), 3, Decimal("60000.00")),
    ("Bumbu Kebuli & Samin", "gram", Decimal("500.000"), Decimal("3.000"), 3, Decimal("150000.00")),
    ("Bumbu Nasi Goreng", "gram", Decimal("500.000"), Decimal("4.000"), 4, Decimal("100000.00")),
    ("Saus & Mayones", "gram", Decimal("1000.000"), Decimal("4.000"), 4, Decimal("120000.00")),
    ("Roti Tawar Tebal", "pcs", Decimal("10.000"), Decimal("4.000"), 4, Decimal("88000.00")),
    ("Keju & Mentega", "gram", Decimal("500.000"), Decimal("3.000"), 3, Decimal("120000.00")),
]

KITCHEN_MENU_SPECS = [
    (
        "MKN01",
        "Nasi Goreng",
        Decimal("25000.00"),
        [
            ("Beras Putih", Decimal("150")),
            ("Telur Ayam", Decimal("1")),
            ("Ayam Fillet", Decimal("45")),
            ("Bumbu Nasi Goreng", Decimal("25")),
            ("Minyak Goreng", Decimal("20")),
        ],
    ),
    (
        "MKN02",
        "Nasi Kebuli",
        Decimal("25000.00"),
        [
            ("Beras Basmati", Decimal("140")),
            ("Daging Kambing", Decimal("60")),
            ("Bumbu Kebuli & Samin", Decimal("20")),
        ],
    ),
    (
        "MKN03",
        "Chicken Katsu Rice Bowl",
        Decimal("28000.00"),
        [
            ("Beras Putih", Decimal("150")),
            ("Ayam Fillet", Decimal("120")),
            ("Tepung & Panir", Decimal("35")),
            ("Telur Ayam", Decimal("0.5")),
            ("Minyak Goreng", Decimal("35")),
            ("Saus & Mayones", Decimal("25")),
        ],
    ),
    (
        "MKN04",
        "Chicken Rice Bowl Telur",
        Decimal("26000.00"),
        [
            ("Beras Putih", Decimal("150")),
            ("Ayam Fillet", Decimal("100")),
            ("Telur Ayam", Decimal("1")),
            ("Minyak Goreng", Decimal("25")),
            ("Saus & Mayones", Decimal("25")),
        ],
    ),
    (
        "MKN05",
        "Kentang Goreng",
        Decimal("18000.00"),
        [
            ("Kentang Frozen", Decimal("180")),
            ("Minyak Goreng", Decimal("20")),
            ("Saus & Mayones", Decimal("25")),
        ],
    ),
    (
        "MKN06",
        "Mix Platter",
        Decimal("32000.00"),
        [
            ("Kentang Frozen", Decimal("100")),
            ("Sosis Sapi", Decimal("60")),
            ("Chicken Nugget", Decimal("80")),
            ("Minyak Goreng", Decimal("30")),
            ("Saus & Mayones", Decimal("35")),
        ],
    ),
    (
        "MKN07",
        "Sosis & Nugget Goreng",
        Decimal("20000.00"),
        [
            ("Sosis Sapi", Decimal("70")),
            ("Chicken Nugget", Decimal("70")),
            ("Minyak Goreng", Decimal("25")),
            ("Saus & Mayones", Decimal("25")),
        ],
    ),
    (
        "MKN08",
        "Roti Bakar Keju",
        Decimal("18000.00"),
        [
            ("Roti Tawar Tebal", Decimal("2")),
            ("Keju & Mentega", Decimal("35")),
        ],
    ),
]


async def _ensure_kategori_makanan(db) -> KategoriMenu:
    res = await db.execute(select(KategoriMenu).where(KategoriMenu.nama == "Makanan"))
    kat = res.scalars().first()
    if not kat:
        kat = KategoriMenu(
            id=str(uuid.uuid4()),
            nama="Makanan",
            area_produksi="kitchen",
            status_aktif=True,
        )
        db.add(kat)
        await db.flush()
    return kat


async def main() -> None:
    async with AsyncSessionLocal() as db:
        kat_makanan = await _ensure_kategori_makanan(db)
        admin = (await db.execute(select(Karyawan).where(Karyawan.role == "admin"))).scalars().first()
        admin_id = admin.id if admin else None

        existing_bahan = {b.nama.lower(): b for b in (await db.execute(select(Bahan))).scalars().all()}
        bahan_map: dict[str, Bahan] = {}

        # 1. Upsert 15 bahan dapur dengan area='kitchen'
        for nama, satuan, isi, stok_min, _, _ in KITCHEN_BAHAN_SPECS:
            b = existing_bahan.get(nama.lower())
            if b:
                b.nama = nama
                b.satuan = satuan
                b.area = "kitchen"
                b.isi_per_kemasan = isi
                b.stok_minimum = stok_min
            else:
                b = Bahan(
                    id=str(uuid.uuid5(uuid.NAMESPACE_DNS, f"kyfein.bahan.kitchen.{nama.lower()}")),
                    nama=nama,
                    satuan=satuan,
                    area="kitchen",
                    isi_per_kemasan=isi,
                    stok_minimum=stok_min,
                    harga_rata_rata=Decimal("0.00"),
                )
                db.add(b)
                await db.flush()

            # Pastikan StokGudang dan HANYA StokTitik(titik='kitchen')
            sg = (await db.execute(select(StokGudang).where(StokGudang.bahan_id == b.id))).scalars().first()
            if not sg:
                db.add(
                    StokGudang(
                        id=str(uuid.uuid4()),
                        bahan_id=b.id,
                        jumlah_kemasan_besar=0,
                        jumlah_satuan_kecil=Decimal("0.000"),
                    )
                )

            st_list = (await db.execute(select(StokTitik).where(StokTitik.bahan_id == b.id))).scalars().all()
            st_map = {st.titik: st for st in st_list}
            if "kitchen" not in st_map:
                db.add(
                    StokTitik(
                        id=str(uuid.uuid4()),
                        bahan_id=b.id,
                        titik="kitchen",
                        jumlah=Decimal("0.000"),
                    )
                )
            if "bar" in st_map and Decimal(str(st_map["bar"].jumlah or 0)) == 0:
                await db.delete(st_map["bar"])

            bahan_map[nama] = b

        await db.flush()

        # 2. Catat Barang Masuk awal dapur (idempoten)
        existing_bm = (
            await db.execute(select(BarangMasuk).where(BarangMasuk.catatan == CATATAN_BARANG_MASUK_KITCHEN))
        ).scalars().first()
        if not existing_bm and admin is not None:
            bm_items = [
                BarangMasukItemInput(
                    bahan_id=bahan_map[nama].id,
                    jumlah_kemasan_besar=kemasan_masuk,
                    jumlah_satuan_kecil=Decimal("0"),
                    harga_total=harga_total,
                )
                for nama, _, _, _, kemasan_masuk, harga_total in KITCHEN_BAHAN_SPECS
            ]
            await record_barang_masuk(
                data=BarangMasukCreate(catatan=CATATAN_BARANG_MASUK_KITCHEN, items=bm_items),
                db=db,
                current_user=admin,
            )
            print("Barang masuk dapur berhasil dicatat (15 item).")
        else:
            print("Barang masuk dapur sudah ada, dilewati.")

        # 3. Upsert 8 menu kitchen & BOM resep
        existing_menu = {m.kode_menu: m for m in (await db.execute(select(Menu))).scalars().all()}
        created_menu = 0
        updated_menu = 0

        for kode, nama, harga, bom in KITCHEN_MENU_SPECS:
            m = existing_menu.get(kode)
            if m:
                m.nama = nama
                m.harga = harga
                m.kategori_id = kat_makanan.id
                m.status_aktif = True
                m.diubah_oleh = admin_id
                updated_menu += 1
            else:
                m = Menu(
                    id=str(uuid.uuid5(uuid.NAMESPACE_DNS, f"kyfein.menu.{kode.lower()}")),
                    nama=nama,
                    kode_menu=kode,
                    harga=harga,
                    kategori_id=kat_makanan.id,
                    status_aktif=True,
                    dibuat_oleh=admin_id,
                )
                db.add(m)
                await db.flush()
                created_menu += 1

            await db.execute(delete(MenuResep).where(MenuResep.menu_id == m.id))
            for bahan_nama, qty in bom:
                db.add(
                    MenuResep(
                        id=str(uuid.uuid4()),
                        menu_id=m.id,
                        bahan_id=bahan_map[bahan_nama].id,
                        jumlah_terpakai=qty,
                    )
                )

        await db.commit()
        print(f"Kitchen seed selesai: {len(KITCHEN_BAHAN_SPECS)} bahan, {created_menu} menu baru, {updated_menu} menu diperbarui.")

        # Ringkasan verifikasi
        for kode, nama, _, _ in KITCHEN_MENU_SPECS:
            m = (await db.execute(select(Menu).where(Menu.kode_menu == kode))).scalars().first()
            hpp = await hitung_hpp_satuan(db, m.id)
            margin = ((Decimal(str(m.harga)) - hpp) / Decimal(str(m.harga)) * Decimal("100")).quantize(Decimal("0.01"))
            print(f" - {kode} {nama}: Jual Rp {m.harga} | HPP Rp {hpp} | Margin {margin}%")

        bar_st = (await db.execute(select(StokTitik, Bahan).join(Bahan, StokTitik.bahan_id == Bahan.id).where(StokTitik.titik == 'bar'))).all()
        kit_st = (await db.execute(select(StokTitik, Bahan).join(Bahan, StokTitik.bahan_id == Bahan.id).where(StokTitik.titik == 'kitchen'))).all()
        print(f"StokTitik check -> bar={len(bar_st)} ({ {b.area for _, b in bar_st} }), kitchen={len(kit_st)} ({ {b.area for _, b in kit_st} })")


if __name__ == "__main__":
    asyncio.run(main())

