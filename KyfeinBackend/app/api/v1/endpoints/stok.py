from datetime import datetime, date
from typing import List
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from sqlalchemy.orm import selectinload

from app.core.deps import get_db, get_current_user
from app.models.stok import (
    StokGudang, StokTitik, BarangKeluar, BarangKeluarDetail,
    BarangMasuk, BarangMasukDetail, StokOpname, StokOpnameDetail, MutasiStok
)
from app.models.jadwal import JadwalShift
from app.models.master_data import Bahan
from app.models.karyawan import Karyawan
from app.schemas.stok import (
    StokOpnameCreate, StokOpnameOut,
    BarangKeluarCreate, BarangKeluarOut,
    BarangMasukCreate, BarangMasukOut
)

router = APIRouter()

@router.post("/barang-masuk", response_model=BarangMasukOut)
async def record_barang_masuk(
    data: BarangMasukCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    RECEIVING GOODS AT WAREHOUSE (BARANG MASUK):
    - Input list items (bahan_id, jumlah_kemasan_besar, jumlah_satuan_kecil, harga_total)
    - Updates stok_gudang (jumlah_kemasan_besar & jumlah_satuan_kecil)
    - Recalculates bahan.harga_rata_rata using Moving Weighted Average based on stock BEFORE addition
    """
    if not data.items:
        raise HTTPException(status_code=400, detail="List items barang masuk tidak boleh kosong")

    new_bm = BarangMasuk(
        karyawan_id=current_user.id,
        catatan=data.catatan
    )
    db.add(new_bm)
    await db.flush()

    for item in data.items:
        bahan = await db.get(Bahan, item.bahan_id)
        if not bahan:
            raise HTTPException(status_code=404, detail=f"Bahan ID {item.bahan_id} tidak ditemukan")

        isi_per_kemasan = Decimal(str(bahan.isi_per_kemasan or 1))
        total_satuan_kecil_masuk = Decimal(str(item.jumlah_kemasan_besar)) * isi_per_kemasan + Decimal(str(item.jumlah_satuan_kecil))

        if total_satuan_kecil_masuk <= 0:
            raise HTTPException(status_code=400, detail=f"Jumlah barang masuk untuk bahan '{bahan.nama}' harus > 0")

        # Fetch or create StokGudang
        sg_res = await db.execute(select(StokGudang).where(StokGudang.bahan_id == item.bahan_id))
        sg = sg_res.scalars().first()
        if not sg:
            sg = StokGudang(
                bahan_id=item.bahan_id,
                jumlah_kemasan_besar=0,
                jumlah_satuan_kecil=Decimal('0')
            )
            db.add(sg)
            await db.flush()

        # Stock before addition
        total_satuan_kecil_lama = Decimal(str(sg.jumlah_kemasan_besar)) * isi_per_kemasan + Decimal(str(sg.jumlah_satuan_kecil))
        harga_rata_rata_lama = Decimal(str(bahan.harga_rata_rata or 0))
        harga_total_masuk = Decimal(str(item.harga_total))

        if total_satuan_kecil_lama <= 0:
            harga_satuan_masuk = harga_total_masuk / total_satuan_kecil_masuk if total_satuan_kecil_masuk > 0 else Decimal('0')
            harga_rata_rata_baru = harga_satuan_masuk
        else:
            harga_rata_rata_baru = (total_satuan_kecil_lama * harga_rata_rata_lama + harga_total_masuk) / (total_satuan_kecil_lama + total_satuan_kecil_masuk)

        bahan.harga_rata_rata = harga_rata_rata_baru

        # Update StokGudang
        sg.jumlah_kemasan_besar += item.jumlah_kemasan_besar
        sg.jumlah_satuan_kecil = Decimal(str(sg.jumlah_satuan_kecil)) + Decimal(str(item.jumlah_satuan_kecil))

        detail = BarangMasukDetail(
            barang_masuk_id=new_bm.id,
            bahan_id=item.bahan_id,
            jumlah_kemasan_besar=item.jumlah_kemasan_besar,
            jumlah_satuan_kecil=item.jumlah_satuan_kecil,
            harga_total=item.harga_total
        )
        db.add(detail)

    await db.commit()
    bm_res = await db.execute(
        select(BarangMasuk)
        .options(selectinload(BarangMasuk.details))
        .where(BarangMasuk.id == new_bm.id)
    )
    return bm_res.scalars().first()

@router.post("/opname", response_model=StokOpnameOut)
async def submit_stok_opname(
    data: StokOpnameCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    STOK OPNAME TWIN CHECKPOINT:
    - Validasi kepemilikan shift (shift.karyawan_id == current_user.id)
    - Validasi area_kerja (titik opname == shift.area_kerja)
    - awal_shift: carry_forward (same-day only) vs hitung_manual
    - Perhitungan & pencatatan selisih_handover jika baseline ada
    - Overwrite stok_titik balance
    """
    shift = await db.get(JadwalShift, data.jadwal_shift_id)
    if not shift:
        raise HTTPException(status_code=404, detail="Jadwal shift tidak ditemukan")

    # Ownership check
    if shift.karyawan_id != current_user.id and current_user.role not in ["admin", "owner"]:
        raise HTTPException(
            status_code=403,
            detail="Tidak dapat mengisi opname untuk shift milik karyawan lain."
        )

    # Area kerja check
    if shift.area_kerja != data.titik:
        raise HTTPException(
            status_code=400,
            detail=f"Titik opname ('{data.titik}') tidak sesuai dengan area_kerja shift aktif karyawan ('{shift.area_kerja}')."
        )

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

    opname_items = []
    if data.tipe == 'awal_shift':
        # Query last opname akhir_shift at the same titik
        last_opname_query = await db.execute(
            select(StokOpname)
            .where(
                and_(
                    StokOpname.titik == data.titik,
                    StokOpname.tipe == 'akhir_shift'
                )
            )
            .order_by(StokOpname.waktu_opname.desc())
        )
        last_opname = last_opname_query.scalars().first()

        if data.metode == 'carry_forward':
            if not last_opname:
                raise HTTPException(
                    status_code=400,
                    detail="Belum ada data opname sebelumnya, gunakan hitung_manual"
                )

            last_shift = await db.get(JadwalShift, last_opname.jadwal_shift_id)
            if not last_shift or last_shift.tanggal != shift.tanggal:
                raise HTTPException(
                    status_code=400,
                    detail="Handover melewati hari berbeda, wajib hitung manual"
                )

            # Map previous details
            prev_details_query = await db.execute(
                select(StokOpnameDetail).where(StokOpnameDetail.stok_opname_id == last_opname.id)
            )
            prev_details = prev_details_query.scalars().all()
            stok_map = {d.bahan_id: Decimal(str(d.jumlah)) for d in prev_details}

            # Add barang_keluar since last opname
            bk_query = await db.execute(
                select(BarangKeluarDetail.bahan_id, BarangKeluarDetail.jumlah)
                .join(BarangKeluar, BarangKeluarDetail.barang_keluar_id == BarangKeluar.id)
                .where(
                    and_(
                        BarangKeluar.titik_tujuan == data.titik,
                        BarangKeluar.waktu >= last_opname.waktu_opname
                    )
                )
            )
            for b_id, b_jml in bk_query.all():
                stok_map[b_id] = stok_map.get(b_id, Decimal('0')) + Decimal(str(b_jml))

            for b_id, b_jml in stok_map.items():
                opname_items.append({"bahan_id": b_id, "jumlah": b_jml})

        else: # hitung_manual for awal_shift
            if not data.items:
                raise HTTPException(
                    status_code=400,
                    detail="Items opname fisik wajib diisi untuk hitung_manual."
                )
            for item in data.items:
                opname_items.append({"bahan_id": item.bahan_id, "jumlah": item.jumlah})

            # Check selisih_handover if baseline exists
            if last_opname:
                prev_details_query = await db.execute(
                    select(StokOpnameDetail).where(StokOpnameDetail.stok_opname_id == last_opname.id)
                )
                prev_details = prev_details_query.scalars().all()
                exp_map = {d.bahan_id: Decimal(str(d.jumlah)) for d in prev_details}

                bk_query = await db.execute(
                    select(BarangKeluarDetail.bahan_id, BarangKeluarDetail.jumlah)
                    .join(BarangKeluar, BarangKeluarDetail.barang_keluar_id == BarangKeluar.id)
                    .where(
                        and_(
                            BarangKeluar.titik_tujuan == data.titik,
                            BarangKeluar.waktu >= last_opname.waktu_opname
                        )
                    )
                )
                for b_id, b_jml in bk_query.all():
                    exp_map[b_id] = exp_map.get(b_id, Decimal('0')) + Decimal(str(b_jml))

                for item in data.items:
                    exp_val = exp_map.get(item.bahan_id, Decimal('0'))
                    phys_val = Decimal(str(item.jumlah))
                    if phys_val != exp_val:
                        mutasi = MutasiStok(
                            bahan_id=item.bahan_id,
                            titik=data.titik,
                            jadwal_shift_id=data.jadwal_shift_id,
                            tipe='selisih_handover',
                            jumlah_selisih=phys_val - exp_val,
                            keterangan=f"Selisih handover awal shift {data.titik} (fisik={phys_val}, ekspektasi={exp_val})"
                        )
                        db.add(mutasi)

    else: # akhir_shift
        if not data.items:
            raise HTTPException(
                status_code=400,
                detail="Items opname fisik wajib diisi untuk akhir_shift."
            )
        for item in data.items:
            opname_items.append({"bahan_id": item.bahan_id, "jumlah": item.jumlah})

    # Header
    new_opname = StokOpname(
        jadwal_shift_id=data.jadwal_shift_id,
        titik=data.titik,
        tipe=data.tipe,
        metode=data.metode,
        karyawan_id=current_user.id,
        catatan=data.catatan
    )
    db.add(new_opname)
    await db.flush()

    # Save Details & Overwrite stok_titik
    details_to_add = []
    for item in opname_items:
        detail = StokOpnameDetail(
            stok_opname_id=new_opname.id,
            bahan_id=item["bahan_id"],
            jumlah=item["jumlah"]
        )
        db.add(detail)

        stok_titik_res = await db.execute(
            select(StokTitik).where(
                and_(
                    StokTitik.bahan_id == item["bahan_id"],
                    StokTitik.titik == data.titik
                )
            )
        )
        stok_titik_item = stok_titik_res.scalars().first()

        if stok_titik_item:
            stok_titik_item.jumlah = item["jumlah"]
        else:
            new_stok_titik = StokTitik(
                bahan_id=item["bahan_id"],
                titik=data.titik,
                jumlah=item["jumlah"]
            )
            db.add(new_stok_titik)

    await db.commit()
    op_res = await db.execute(
        select(StokOpname)
        .options(selectinload(StokOpname.details))
        .where(StokOpname.id == new_opname.id)
    )
    return op_res.scalars().first()

@router.post("/barang-keluar", response_model=BarangKeluarOut)
async def record_barang_keluar(
    data: BarangKeluarCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    TRANSFER GUDANG -> TITIK (BAR/KITCHEN):
    - Validasi area_kerja: titik_tujuan harus sesuai dengan area_kerja shift aktif karyawan saat itu
    - Mengurangi stok_gudang. Tidak menambah stok_titik secara langsung.
    """
    today = date.today()
    shift_res = await db.execute(
        select(JadwalShift).where(
            and_(
                JadwalShift.karyawan_id == current_user.id,
                JadwalShift.tanggal == today
            )
        )
    )
    active_shift = shift_res.scalars().first()

    if active_shift and active_shift.area_kerja != data.titik_tujuan:
        raise HTTPException(
            status_code=400,
            detail=f"Titik tujuan barang keluar ('{data.titik_tujuan}') harus sesuai dengan area_kerja shift aktif Anda ('{active_shift.area_kerja}')."
        )

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
    bk_res = await db.execute(
        select(BarangKeluar)
        .options(selectinload(BarangKeluar.details))
        .where(BarangKeluar.id == new_bk.id)
    )
    return bk_res.scalars().first()
