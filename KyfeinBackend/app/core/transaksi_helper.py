from decimal import Decimal
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.models.jadwal import JadwalShift
from app.models.stok import StokOpname
from app.models.absensi import Absensi
from app.models.master_data import MenuResep, Bahan

async def hitung_hpp_satuan(db: AsyncSession, menu_id: str) -> Decimal:
    """
    Hitung HPP per porsi untuk menu_id saat transaksi dibuat (snapshot):
    hpp_satuan = Σ(menu_resep.jumlah_terpakai × bahan.harga_rata_rata)
    Menu tanpa resep -> Decimal("0")
    """
    stmt = (
        select(MenuResep, Bahan)
        .join(Bahan, MenuResep.bahan_id == Bahan.id)
        .where(MenuResep.menu_id == menu_id)
    )
    res = await db.execute(stmt)
    rows = res.all()

    hpp = Decimal("0")
    for resep, bahan in rows:
        jumlah = Decimal(str(resep.jumlah_terpakai or 0))
        harga = Decimal(str(bahan.harga_rata_rata or 0))
        hpp += jumlah * harga

    return hpp.quantize(Decimal("0.01"))

async def is_transaksi_locked(db: AsyncSession, jadwal_shift_id: str) -> bool:
    """
    Hitung status penguncian transaksi untuk jadwal_shift_id:
    - Ambil semua jadwal_shift dengan tanggal + shift yang sama dan area_kerja IN ('bar', 'kitchen').
    - Jika ada minimal 1 shift bar/kitchen: Terkunci jika SEMUA shift bar/kitchen tersebut punya stok_opname akhir_shift di titiknya.
    - Fallback (0 titik): Jika tidak ada shift bar/kitchen sama sekali pada tanggal + shift tersebut, terkunci saat absensi.jam_pulang kasir terisi.
    """
    kasir_shift = await db.get(JadwalShift, jadwal_shift_id)
    if not kasir_shift:
        return True

    # Query semua shift bar & kitchen pada tanggal dan shift yang sama
    stmt_bk = select(JadwalShift).where(
        and_(
            JadwalShift.tanggal == kasir_shift.tanggal,
            JadwalShift.shift == kasir_shift.shift,
            JadwalShift.area_kerja.in_(["bar", "kitchen"])
        )
    )
    res_bk = await db.execute(stmt_bk)
    bk_shifts = res_bk.scalars().all()

    if bk_shifts:
        # Terkunci jika SEMUA shift bar/kitchen memiliki opname akhir_shift di titiknya
        for bk in bk_shifts:
            stmt_opname = select(StokOpname).where(
                and_(
                    StokOpname.jadwal_shift_id == bk.id,
                    StokOpname.tipe == "akhir_shift",
                    StokOpname.titik == bk.area_kerja
                )
            )
            res_op = await db.execute(stmt_opname)
            if not res_op.scalars().first():
                return False
        return True
    else:
        # Fallback (0 titik): Tidak ada shift bar/kitchen sama sekali pada shift ini
        # Terkunci jika absensi kasir sudah memiliki jam_pulang (absen pulang terisi)
        stmt_absensi = select(Absensi).where(Absensi.jadwal_shift_id == kasir_shift.id)
        res_abs = await db.execute(stmt_absensi)
        absensi = res_abs.scalars().first()
        if absensi and absensi.jam_pulang is not None:
            return True
        return False
