from typing import List, Union
from decimal import Decimal
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.deps import get_db, require_roles, get_current_user
from app.models.master_data import KategoriMenu, Menu, Bahan, MenuResep, KategoriPengeluaran
from app.models.stok import StokGudang, StokTitik
from app.models.karyawan import Karyawan
from app.schemas.master_data import (
    KategoriMenuCreate, KategoriMenuOut,
    MenuCreate, MenuUpdate, MenuOut,
    BahanCreate, BahanOut, BahanAdminOut, BahanStokMenipisOut,
    MenuResepCreate, MenuResepOut,
    KategoriPengeluaranCreate, KategoriPengeluaranOut
)

router = APIRouter()

# --- KATEGORI MENU ---
@router.get("/kategori-menu", response_model=List[KategoriMenuOut])
async def list_kategori_menu(
    include_nonaktif: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    stmt = select(KategoriMenu)
    if not (include_nonaktif and current_user.role in ["admin", "owner"]):
        stmt = stmt.where(KategoriMenu.status_aktif == True)
    result = await db.execute(stmt)
    return result.scalars().all()

@router.post("/kategori-menu", response_model=KategoriMenuOut)
async def create_kategori_menu(
    data: KategoriMenuCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    item = KategoriMenu(**data.dict())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item

# --- MENU ---
@router.get("/menu", response_model=List[MenuOut])
async def list_menu(
    include_nonaktif: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    stmt = select(Menu).options(selectinload(Menu.kategori))
    if not (include_nonaktif and current_user.role in ["admin", "owner"]):
        stmt = stmt.where(Menu.status_aktif == True)
    result = await db.execute(stmt)
    return result.scalars().all()

from app.core.foto_helper import validate_and_claim_foto, remove_old_foto_if_replaced

@router.post("/menu", response_model=MenuOut)
async def create_menu(
    data: MenuCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    if data.foto_id:
        await validate_and_claim_foto(db, data.foto_id, current_user.id, "menu", required=False)

    item = Menu(**data.dict(), dibuat_oleh=current_user.id)
    db.add(item)
    await db.commit()
    res = await db.execute(select(Menu).options(selectinload(Menu.kategori)).where(Menu.id == item.id))
    return res.scalar_one()

@router.put("/menu/{id}", response_model=MenuOut)
async def update_menu(
    id: str,
    data: MenuUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    item = await db.get(Menu, id)
    if not item:
        raise HTTPException(status_code=404, detail="Menu tidak ditemukan")

    if data.foto_id is not None and data.foto_id != item.foto_id:
        await validate_and_claim_foto(db, data.foto_id, current_user.id, "menu", required=False)
        await remove_old_foto_if_replaced(db, item.foto_id, data.foto_id)

    update_data = data.dict(exclude_unset=True)
    for field, val in update_data.items():
        setattr(item, field, val)

    item.diubah_oleh = current_user.id
    await db.commit()
    res = await db.execute(select(Menu).options(selectinload(Menu.kategori)).where(Menu.id == item.id))
    return res.scalar_one()

# --- BAHAN ---
@router.get("/bahan/stok-menipis", response_model=List[BahanStokMenipisOut])
async def get_stok_menipis(
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    """
    List bahan yang total stoknya (stok_gudang dikonversi ke satuan kecil via isi_per_kemasan,
    ditambah stok_titik bar + kitchen) di bawah bahan.stok_minimum.
    """
    bahan_res = await db.execute(select(Bahan))
    all_bahan = bahan_res.scalars().all()

    result = []
    for b in all_bahan:
        isi_per_kemasan = Decimal(str(b.isi_per_kemasan or 1))

        # 1. Stok Gudang
        sg_res = await db.execute(select(StokGudang).where(StokGudang.bahan_id == b.id))
        sg = sg_res.scalars().first()
        stok_gudang_kecil = Decimal('0')
        if sg:
            stok_gudang_kecil = Decimal(str(sg.jumlah_kemasan_besar)) * isi_per_kemasan + Decimal(str(sg.jumlah_satuan_kecil))

        # 2. Stok Titik (Bar + Kitchen)
        st_res = await db.execute(select(StokTitik).where(StokTitik.bahan_id == b.id))
        st_list = st_res.scalars().all()
        stok_titik_total = sum((Decimal(str(st.jumlah)) for st in st_list), Decimal('0'))

        total_stok = stok_gudang_kecil + stok_titik_total

        if total_stok < Decimal(str(b.stok_minimum)):
            setattr(b, 'total_stok', total_stok)
            result.append(b)

    return result

@router.get("/bahan", response_model=Union[List[BahanAdminOut], List[BahanOut]])
async def list_bahan(
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    result = await db.execute(select(Bahan))
    items = result.scalars().all()
    if current_user.role in ["admin", "owner"]:
        return [BahanAdminOut.model_validate(b) for b in items]
    return [BahanOut.model_validate(b) for b in items]

@router.post("/bahan", response_model=BahanAdminOut)
async def create_bahan(
    data: BahanCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    item = Bahan(**data.dict())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


# --- RESEP ---
@router.post("/resep", response_model=MenuResepOut)
async def create_resep(
    data: MenuResepCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    item = MenuResep(**data.dict())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item

# --- KATEGORI PENGELUARAN ---
@router.get("/kategori-pengeluaran", response_model=List[KategoriPengeluaranOut])
async def list_kategori_pengeluaran(
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    result = await db.execute(select(KategoriPengeluaran).where(KategoriPengeluaran.status_aktif == True))
    return result.scalars().all()

@router.post("/kategori-pengeluaran", response_model=KategoriPengeluaranOut)
async def create_kategori_pengeluaran(
    data: KategoriPengeluaranCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    item = KategoriPengeluaran(**data.dict())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item

# --- KONFIGURASI LOKASI ---
from app.models.master_data import KonfigurasiLokasi
from app.schemas.master_data import KonfigurasiLokasiUpdate, KonfigurasiLokasiOut

@router.get("/konfigurasi-lokasi", response_model=KonfigurasiLokasiOut)
async def get_konfigurasi_lokasi(
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    res = await db.execute(select(KonfigurasiLokasi).limit(1))
    item = res.scalars().first()
    if not item:
        raise HTTPException(status_code=404, detail="Konfigurasi lokasi belum diatur")
    return item

@router.put("/konfigurasi-lokasi", response_model=KonfigurasiLokasiOut)
async def update_konfigurasi_lokasi(
    data: KonfigurasiLokasiUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    res = await db.execute(select(KonfigurasiLokasi).limit(1))
    item = res.scalars().first()
    if not item:
        item = KonfigurasiLokasi(
            latitude=data.latitude or Decimal("0"),
            longitude=data.longitude or Decimal("0"),
            radius_meter=data.radius_meter or Decimal("50"),
            updated_by=current_user.id
        )
        db.add(item)
    else:
        if data.latitude is not None:
            item.latitude = data.latitude
        if data.longitude is not None:
            item.longitude = data.longitude
        if data.radius_meter is not None:
            item.radius_meter = data.radius_meter
        item.updated_by = current_user.id

    await db.commit()
    await db.refresh(item)
    return item
