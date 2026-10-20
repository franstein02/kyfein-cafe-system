import asyncio
from decimal import Decimal
from app.core.database import AsyncSessionLocal
from app.models.master_data import Bahan, MenuResep
from app.models.stok import StokGudang, StokTitik, StokOpnameDetail, BarangKeluarDetail, BarangMasukDetail, MutasiStok
from sqlalchemy import select, delete

# 14 Bahan Utama Kafe sesuai permintaan user:
# cup, uht, espresso/biji kopi, skm, pandan, vanilla, coconut, chocolate, matcha, creamer, salted caramel, butterscotch, strawberry jam, gula aren
BAHAN_UTAMA = [
    {
        "id": "b-cup",
        "nama": "Cup Plastik 16oz + Tutup",
        "satuan": "pcs",
        "isi_per_kemasan": Decimal("50.000"),
        "stok_minimum": Decimal("100.000"),
        "harga_rata_rata": Decimal("650.00")
    },
    {
        "id": "b-uht",
        "nama": "Susu UHT Fresh Milk",
        "satuan": "ml",
        "isi_per_kemasan": Decimal("1000.000"),
        "stok_minimum": Decimal("5000.000"),
        "harga_rata_rata": Decimal("18.50")
    },
    {
        "id": "b-kopi",
        "nama": "Biji Kopi House Blend (Espresso)",
        "satuan": "gram",
        "isi_per_kemasan": Decimal("1000.000"),
        "stok_minimum": Decimal("2000.000"),
        "harga_rata_rata": Decimal("220.00")
    },
    {
        "id": "b-skm",
        "nama": "Susu Kental Manis (SKM)",
        "satuan": "ml",
        "isi_per_kemasan": Decimal("500.000"),
        "stok_minimum": Decimal("1500.000"),
        "harga_rata_rata": Decimal("24.00")
    },
    {
        "id": "b-pandan",
        "nama": "Sirup Pandan",
        "satuan": "ml",
        "isi_per_kemasan": Decimal("750.000"),
        "stok_minimum": Decimal("1000.000"),
        "harga_rata_rata": Decimal("85.00")
    },
    {
        "id": "b-vanilla",
        "nama": "Sirup Vanilla",
        "satuan": "ml",
        "isi_per_kemasan": Decimal("750.000"),
        "stok_minimum": Decimal("1000.000"),
        "harga_rata_rata": Decimal("90.00")
    },
    {
        "id": "b-coconut",
        "nama": "Sirup / Susu Kelapa (Coconut)",
        "satuan": "ml",
        "isi_per_kemasan": Decimal("1000.000"),
        "stok_minimum": Decimal("1500.000"),
        "harga_rata_rata": Decimal("45.00")
    },
    {
        "id": "b-chocolate",
        "nama": "Bubuk Chocolate",
        "satuan": "gram",
        "isi_per_kemasan": Decimal("1000.000"),
        "stok_minimum": Decimal("2000.000"),
        "harga_rata_rata": Decimal("120.00")
    },
    {
        "id": "b-matcha",
        "nama": "Bubuk Matcha",
        "satuan": "gram",
        "isi_per_kemasan": Decimal("500.000"),
        "stok_minimum": Decimal("1000.000"),
        "harga_rata_rata": Decimal("210.00")
    },
    {
        "id": "b-creamer",
        "nama": "Bubuk Creamer",
        "satuan": "gram",
        "isi_per_kemasan": Decimal("1000.000"),
        "stok_minimum": Decimal("2000.000"),
        "harga_rata_rata": Decimal("55.00")
    },
    {
        "id": "b-salted-caramel",
        "nama": "Sirup Salted Caramel",
        "satuan": "ml",
        "isi_per_kemasan": Decimal("750.000"),
        "stok_minimum": Decimal("1000.000"),
        "harga_rata_rata": Decimal("95.00")
    },
    {
        "id": "b-butterscotch",
        "nama": "Sirup Butterscotch",
        "satuan": "ml",
        "isi_per_kemasan": Decimal("750.000"),
        "stok_minimum": Decimal("1000.000"),
        "harga_rata_rata": Decimal("95.00")
    },
    {
        "id": "b-strawberry-jam",
        "nama": "Strawberry Jam (Selai Stroberi)",
        "satuan": "gram",
        "isi_per_kemasan": Decimal("1000.000"),
        "stok_minimum": Decimal("1000.000"),
        "harga_rata_rata": Decimal("65.00")
    },
    {
        "id": "b-aren",
        "nama": "Sirup Gula Aren",
        "satuan": "ml",
        "isi_per_kemasan": Decimal("1000.000"),
        "stok_minimum": Decimal("2000.000"),
        "harga_rata_rata": Decimal("35.00")
    }
]

async def sync():
    async with AsyncSessionLocal() as db:
        print("1. Mengosongkan resep lama (sesuai permintaan: user isi BOM sendiri)...")
        await db.execute(delete(MenuResep))

        # ID target
        target_ids = {b["id"] for b in BAHAN_UTAMA}
        
        # Cek bahan lama di DB
        existing_res = await db.execute(select(Bahan))
        existing_bahans = {b.id: b for b in existing_res.scalars().all()}
        
        # Hapus bahan yang bukan 14 bahan utama
        for old_id, old_b in existing_bahans.items():
            if old_id not in target_ids and old_id not in ('b-cup16',):
                print(f"Menghapus data terkait bahan lama: {old_id} ({old_b.nama})")
                await db.execute(delete(StokGudang).where(StokGudang.bahan_id == old_id))
                await db.execute(delete(StokTitik).where(StokTitik.bahan_id == old_id))
                await db.execute(delete(StokOpnameDetail).where(StokOpnameDetail.bahan_id == old_id))
                await db.execute(delete(BarangKeluarDetail).where(BarangKeluarDetail.bahan_id == old_id))
                await db.execute(delete(BarangMasukDetail).where(BarangMasukDetail.bahan_id == old_id))
                await db.execute(delete(MutasiStok).where(MutasiStok.bahan_id == old_id))
                await db.execute(delete(Bahan).where(Bahan.id == old_id))

        # Khusus b-cup16 ganti jadi b-cup jika ada
        if 'b-cup16' in existing_bahans and 'b-cup' not in existing_bahans:
            print("Migrasi b-cup16 ke b-cup...")
            b16 = existing_bahans['b-cup16']
            await db.execute(delete(StokGudang).where(StokGudang.bahan_id == 'b-cup16'))
            await db.execute(delete(StokTitik).where(StokTitik.bahan_id == 'b-cup16'))
            await db.execute(delete(Bahan).where(Bahan.id == 'b-cup16'))

        await db.flush()

        print("2. Menyimpan 14 bahan utama...")
        for b_data in BAHAN_UTAMA:
            b = await db.get(Bahan, b_data["id"])
            if not b:
                b = Bahan(
                    id=b_data["id"],
                    nama=b_data["nama"],
                    satuan=b_data["satuan"],
                    isi_per_kemasan=b_data["isi_per_kemasan"],
                    stok_minimum=b_data["stok_minimum"],
                    harga_rata_rata=b_data["harga_rata_rata"]
                )
                db.add(b)
            else:
                b.nama = b_data["nama"]
                b.satuan = b_data["satuan"]
                b.isi_per_kemasan = b_data["isi_per_kemasan"]
                b.stok_minimum = b_data["stok_minimum"]
                b.harga_rata_rata = b_data["harga_rata_rata"]

            await db.flush()

            # Pastikan Stok Gudang ada
            sg_res = await db.execute(select(StokGudang).where(StokGudang.bahan_id == b_data["id"]))
            sg = sg_res.scalars().first()
            if not sg:
                sg = StokGudang(
                    bahan_id=b_data["id"],
                    jumlah_kemasan_besar=10,
                    jumlah_satuan_kecil=Decimal("0.0")
                )
                db.add(sg)
            else:
                if sg.jumlah_kemasan_besar <= 0 and sg.jumlah_satuan_kecil <= 0:
                    sg.jumlah_kemasan_besar = 10

            # Pastikan Stok Titik Bar ada
            st_res = await db.execute(select(StokTitik).where(StokTitik.bahan_id == b_data["id"], StokTitik.titik == "bar"))
            st = st_res.scalars().first()
            if not st:
                # Inisialisasi awal di bar (misal 1 kemasan terbuka)
                st = StokTitik(
                    bahan_id=b_data["id"],
                    titik="bar",
                    jumlah=b_data["isi_per_kemasan"]
                )
                db.add(st)

        await db.commit()
        print("Sinkronisasi 14 bahan utama BERHASIL!")

if __name__ == "__main__":
    asyncio.run(sync())
