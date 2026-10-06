from datetime import datetime, date
from typing import List, Optional, Literal
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from sqlalchemy.orm import selectinload

from app.core.deps import get_db, get_current_user, require_roles
from app.core.utils import now_local
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
    BarangMasukCreate, BarangMasukOut,
    StokGudangOut, StokTitikOut, MutasiStokOut
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
    A6 (opname):
    - jumlahkan items yang bahan_id-nya sama sebelum menyimpan dan membandingkan
    - metode ditentukan server (akhir_shift selalu hitung_manual, awal_shift otomatis carry_forward jika shift sebelumnya di titik sama dan tanggal sama, selain itu hitung_manual), dan field metode dari client diabaikan
    - awal_shift harus ada sebelum akhir_shift di shift yang sama
    - jadwal_shift.tanggal harus hari ini
    - karyawan_id opname selalu karyawan yang di-assign di shift, bukan admin yang submit
    - shift yang area_kerja-nya kasir ditolak
    """
    shift = await db.get(JadwalShift, data.jadwal_shift_id)
    if not shift:
        raise HTTPException(status_code=404, detail="Jadwal shift tidak ditemukan")

    # Validasi: jadwal_shift.tanggal harus hari ini
    today = now_local().date()
    if shift.tanggal != today:
        raise HTTPException(
            status_code=400,
            detail="Stok opname hanya dapat dilakukan untuk shift hari ini"
        )

    # Validasi: shift area_kerja kasir ditolak
    if shift.area_kerja == 'kasir':
        raise HTTPException(
            status_code=400,
            detail="Shift dengan area kerja kasir tidak memerlukan stok opname"
        )

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

    # Cek apakah opname tipe ini untuk titik pada shift ini sudah pernah disubmit
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

    # Menentukan metode server-side (field data.metode dari client diabaikan)
    # 1. akhir_shift selalu hitung_manual
    # 2. awal_shift: cek opname akhir_shift terakhir di titik yang sama
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

    if data.tipe == 'akhir_shift':
        # Validasi: awal_shift harus ada sebelum akhir_shift di shift yang sama
        awal_opname = await db.execute(
            select(StokOpname).where(
                and_(
                    StokOpname.jadwal_shift_id == data.jadwal_shift_id,
                    StokOpname.titik == data.titik,
                    StokOpname.tipe == 'awal_shift'
                )
            )
        )
        if not awal_opname.scalars().first():
            raise HTTPException(
                status_code=400,
                detail="Opname awal_shift harus ada sebelum opname akhir_shift pada shift yang sama"
            )
        metode = 'hitung_manual'
    else: # awal_shift
        if last_opname:
            last_shift = await db.get(JadwalShift, last_opname.jadwal_shift_id)
            if last_shift and last_shift.tanggal == shift.tanggal:
                metode = 'carry_forward'
            else:
                metode = 'hitung_manual'
        else:
            metode = 'hitung_manual'

    # Aggregasi/Jumlahkan items dengan bahan_id yang sama dari payload client
    aggregated_client_items = {}
    if data.items:
        for it in data.items:
            aggregated_client_items[it.bahan_id] = aggregated_client_items.get(it.bahan_id, Decimal('0')) + Decimal(str(it.jumlah))

    opname_items = []
    if metode == 'carry_forward':
        # Map previous details from last_opname
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

    else: # hitung_manual
        if not aggregated_client_items:
            raise HTTPException(
                status_code=400,
                detail="Items opname fisik wajib diisi untuk hitung_manual."
            )
        for b_id, b_jml in aggregated_client_items.items():
            opname_items.append({"bahan_id": b_id, "jumlah": b_jml})

        # Check selisih_handover jika baseline ada (untuk awal_shift hitung_manual)
        if data.tipe == 'awal_shift' and last_opname:
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

            for b_id, phys_val in aggregated_client_items.items():
                exp_val = exp_map.get(b_id, Decimal('0'))
                if phys_val != exp_val:
                    mutasi = MutasiStok(
                        bahan_id=b_id,
                        titik=data.titik,
                        jadwal_shift_id=data.jadwal_shift_id,
                        tipe='selisih_handover',
                        jumlah_selisih=phys_val - exp_val,
                        keterangan=f"Selisih handover awal shift {data.titik} (fisik={phys_val}, ekspektasi={exp_val})"
                    )
                    db.add(mutasi)

    # Header: karyawan_id opname selalu karyawan yang di-assign di shift (shift.karyawan_id)
    new_opname = StokOpname(
        jadwal_shift_id=data.jadwal_shift_id,
        titik=data.titik,
        tipe=data.tipe,
        metode=metode,
        karyawan_id=shift.karyawan_id,
        catatan=data.catatan,
        waktu_opname=now_local()
    )
    db.add(new_opname)
    await db.flush()

    # Save Details & Overwrite stok_titik
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
    today = now_local().date()
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
        karyawan_id=current_user.id,
        waktu=now_local()
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

# --- VIEW ENDPOINTS ---
@router.get("/stok-gudang", response_model=List[StokGudangOut])
async def list_stok_gudang(
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    result = await db.execute(
        select(StokGudang)
        .options(selectinload(StokGudang.bahan))
        .order_by(StokGudang.updated_at.desc())
    )
    items = result.scalars().all()
    for item in items:
        if item.bahan:
            setattr(item, 'nama_bahan', item.bahan.nama)
    return items

@router.get("/stok-titik", response_model=List[StokTitikOut])
async def list_stok_titik(
    titik: Optional[Literal['bar', 'kitchen']] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    query = select(StokTitik).options(selectinload(StokTitik.bahan))
    if titik:
        query = query.where(StokTitik.titik == titik)
    result = await db.execute(query.order_by(StokTitik.updated_at.desc()))
    items = result.scalars().all()
    for item in items:
        if item.bahan:
            setattr(item, 'nama_bahan', item.bahan.nama)
    return items

@router.get("/mutasi-stok", response_model=List[MutasiStokOut])
async def list_mutasi_stok(
    titik: Optional[Literal['bar', 'kitchen']] = None,
    tanggal_mulai: Optional[date] = None,
    tanggal_selesai: Optional[date] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    query = select(MutasiStok).options(selectinload(MutasiStok.bahan))
    if titik:
        query = query.where(MutasiStok.titik == titik)
    if tanggal_mulai:
        start_dt = datetime.combine(tanggal_mulai, datetime.min.time())
        query = query.where(MutasiStok.created_at >= start_dt)
    if tanggal_selesai:
        end_dt = datetime.combine(tanggal_selesai, datetime.max.time())
        query = query.where(MutasiStok.created_at <= end_dt)

    result = await db.execute(query.order_by(MutasiStok.created_at.desc()))
    items = result.scalars().all()
    for item in items:
        if item.bahan:
            setattr(item, 'nama_bahan', item.bahan.nama)
    return items
