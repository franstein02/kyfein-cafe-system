from datetime import datetime
from typing import List
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.core.deps import get_db, get_current_user
from app.models.stok import (
    StokGudang, StokTitik, BarangKeluar, BarangKeluarDetail,
    StokOpname, StokOpnameDetail, MutasiStok
)
from app.models.jadwal import JadwalShift
from app.models.master_data import Bahan
from app.models.karyawan import Karyawan
from app.schemas.stok import (
    StokOpnameCreate, StokOpnameOut,
    BarangKeluarCreate, BarangKeluarOut
)

router = APIRouter()

@router.post("/opname", response_model=StokOpnameOut)
async def submit_stok_opname(
    data: StokOpnameCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    STOK OPNAME TWIN CHECKPOINT:
    - awal_shift & akhir_shift (keduanya blocking)
    - metode: carry_forward (same-day, 1 tap konfirmasi) vs hitung_manual (cross-day, hitung fisik)
    - overwrite stok_titik.jumlah untuk kombinasi (bahan_id, titik)
    """
    shift = await db.get(JadwalShift, data.jadwal_shift_id)
    if not shift:
        raise HTTPException(status_code=404, detail="Jadwal shift tidak ditemukan")

    # Cek apakah opname ini sudah pernah disubmit
    existing_opname = await db.execute(
        select(StokOpname).where(
            and_(
                StokOpname.jadwal_shift_id == data.jadwal_shift_id,
                StokOpname.titik == data.titik,
                StokOpname.tipe == data.tipe
            )
        )
    )
    if existing_opname.scalars().first():
        raise HTTPException(
            status_code=400,
            detail=f"Stok opname {data.tipe} untuk titik {data.titik} pada shift ini sudah pernah disubmit."
        )

    # 1. Buat Header Opname
    new_opname = StokOpname(
        jadwal_shift_id=data.jadwal_shift_id,
        titik=data.titik,
        tipe=data.tipe,
        metode=data.metode,
        karyawan_id=current_user.id,
        catatan=data.catatan
    )
    db.add(new_opname)
    await db.flush() # Ambil ID opname

    # 2. Process Items
    details_to_add = []
    for item in data.items:
        # Save raw physical count detail
        detail = StokOpnameDetail(
            stok_opname_id=new_opname.id,
            bahan_id=item.bahan_id,
            jumlah=item.jumlah
        )
        details_to_add.append(detail)

        # Overwrite stok_titik balance for (bahan_id, titik)
        stok_titik_res = await db.execute(
            select(StokTitik).where(
                and_(
                    StokTitik.bahan_id == item.bahan_id,
                    StokTitik.titik == data.titik
                )
            )
        )
        stok_titik_item = stok_titik_res.scalars().first()

        if stok_titik_item:
            stok_titik_item.jumlah = item.jumlah
        else:
            new_stok_titik = StokTitik(
                bahan_id=item.bahan_id,
                titik=data.titik,
                jumlah=item.jumlah
            )
            db.add(new_stok_titik)

    new_opname.details = details_to_add
    await db.commit()
    await db.refresh(new_opname)
    return new_opname

@router.post("/barang-keluar", response_model=BarangKeluarOut)
async def record_barang_keluar(
    data: BarangKeluarCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    TRANSFER GUDANG -> TITIK (BAR/KITCHEN):
    Mengurangi stok_gudang. Tidak menambah stok_titik secara langsung
    (karena stok_titik hanya diperbarui lewat stok_opname fisik).
    """
    new_bk = BarangKeluar(
        titik_tujuan=data.titik_tujuan,
        karyawan_id=current_user.id
    )
    db.add(new_bk)
    await db.flush()

    for item in data.items:
        detail = BarangKeluarDetail(
            barang_keluar_id=new_bk.id,
            bahan_id=item.bahan_id,
            jumlah=item.jumlah
        )
        db.add(detail)

        # Kurangi stok gudang
        sg_res = await db.execute(select(StokGudang).where(StokGudang.bahan_id == item.bahan_id))
        sg = sg_res.scalars().first()
        if sg:
            if sg.jumlah_satuan_kecil < item.jumlah:
                raise HTTPException(
                    status_code=400,
                    detail=f"Stok gudang untuk bahan ID {item.bahan_id} tidak mencukupi"
                )
            sg.jumlah_satuan_kecil -= item.jumlah

    await db.commit()
    await db.refresh(new_bk)
    return new_bk
