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
    MenuResepCreate, MenuResepOut, MenuResepItemCreate, MenuResepItemOut,
    KategoriPengeluaranCreate, KategoriPengeluaranOut
)

router = APIRouter()

def _populate_menu_resep(menu: Menu):
    if hasattr(menu, 'resep') and menu.resep:
        for r in menu.resep:
            if hasattr(r, 'bahan') and r.bahan:
                setattr(r, 'nama_bahan', r.bahan.nama)
                setattr(r, 'satuan', r.bahan.satuan)

# --- KATEGORI MENU ---
@router.get("/kategori-menu", response_model=List[KategoriMenuOut])
async def list_kategori_menu(
    include_nonaktif: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    stmt = select(KategoriMenu)
    if not (include_nonaktif and current_user.role in ["admin"]):
        stmt = stmt.where(KategoriMenu.status_aktif == True)
    result = await db.execute(stmt)
    return result.scalars().all()

@router.post("/kategori-menu", response_model=KategoriMenuOut)
async def create_kategori_menu(
    data: KategoriMenuCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
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
    stmt = select(Menu).options(
        selectinload(Menu.kategori),
        selectinload(Menu.resep).selectinload(MenuResep.bahan)
    )
    if not (include_nonaktif and current_user.role in ["admin"]):
        stmt = stmt.where(Menu.status_aktif == True)
    result = await db.execute(stmt)
    menus = result.scalars().all()
    for m in menus:
        _populate_menu_resep(m)
    return menus

@router.get("/menu/{id}", response_model=MenuOut)
async def get_menu_by_id(
    id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    stmt = (
        select(Menu)
        .options(
            selectinload(Menu.kategori),
            selectinload(Menu.resep).selectinload(MenuResep.bahan)
        )
        .where(Menu.id == id)
    )
    res = await db.execute(stmt)
    item = res.scalars().first()
    if not item:
        raise HTTPException(status_code=404, detail="Menu tidak ditemukan")
    _populate_menu_resep(item)
    return item

@router.get("/menu/{id}/resep", response_model=List[MenuResepItemOut])
async def get_menu_resep(
    id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    menu = await db.get(Menu, id)
    if not menu:
        raise HTTPException(status_code=404, detail="Menu tidak ditemukan")
    stmt = select(MenuResep).options(selectinload(MenuResep.bahan)).where(MenuResep.menu_id == id)
    res = await db.execute(stmt)
    reseps = res.scalars().all()
    for r in reseps:
        if r.bahan:
            setattr(r, 'nama_bahan', r.bahan.nama)
            setattr(r, 'satuan', r.bahan.satuan)
    return reseps

@router.put("/menu/{id}/resep", response_model=List[MenuResepItemOut])
async def update_menu_resep(
    id: str,
    items: List[MenuResepItemCreate],
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    menu = await db.get(Menu, id)
    if not menu:
        raise HTTPException(status_code=404, detail="Menu tidak ditemukan")

    old = await db.execute(select(MenuResep).where(MenuResep.menu_id == id))
    for r in old.scalars().all():
        await db.delete(r)
    await db.flush()

    for item in items:
        bahan = await db.get(Bahan, item.bahan_id)
        if not bahan:
            raise HTTPException(status_code=400, detail=f"Bahan dengan ID {item.bahan_id} tidak ditemukan")
        db.add(MenuResep(
            id=str(uuid.uuid4()),
            menu_id=id,
            bahan_id=item.bahan_id,
            jumlah_terpakai=item.jumlah_terpakai
        ))

    await db.commit()

    stmt = select(MenuResep).options(selectinload(MenuResep.bahan)).where(MenuResep.menu_id == id)
    res = await db.execute(stmt)
    reseps = res.scalars().all()
    for r in reseps:
        if r.bahan:
            setattr(r, 'nama_bahan', r.bahan.nama)
            setattr(r, 'satuan', r.bahan.satuan)
    return reseps

import uuid
from app.core.foto_helper import validate_and_claim_foto, remove_old_foto_if_replaced
from app.models.foto import Foto

@router.post("/menu", response_model=MenuOut)
async def create_menu(
    data: MenuCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    if data.foto_id:
        if data.foto_id.startswith('http'):
            new_foto_id = str(uuid.uuid4())
            new_foto = Foto(id=new_foto_id, jenis='menu', path=data.foto_id, uploader_id=current_user.id, dipakai=True)
            db.add(new_foto)
            await db.flush()
            data.foto_id = new_foto_id
        else:
            await validate_and_claim_foto(db, data.foto_id, current_user.id, "menu", required=False)

    resep_items = data.resep or []
    create_data = data.dict(exclude={'resep'})
    item = Menu(**create_data, dibuat_oleh=current_user.id)
    db.add(item)
    await db.flush()

    for r in resep_items:
        bahan = await db.get(Bahan, r.bahan_id)
        if not bahan:
            raise HTTPException(status_code=400, detail=f"Bahan dengan ID {r.bahan_id} tidak ditemukan")
        db.add(MenuResep(
            id=str(uuid.uuid4()),
            menu_id=item.id,
            bahan_id=r.bahan_id,
            jumlah_terpakai=r.jumlah_terpakai
        ))

    await db.commit()
    res = await db.execute(
        select(Menu)
        .options(
            selectinload(Menu.kategori),
            selectinload(Menu.resep).selectinload(MenuResep.bahan)
        )
        .where(Menu.id == item.id)
    )
    result_menu = res.scalar_one()
    _populate_menu_resep(result_menu)
    return result_menu

@router.put("/menu/{id}", response_model=MenuOut)
async def update_menu(
    id: str,
    data: MenuUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    item = await db.get(Menu, id)
    if not item:
        raise HTTPException(status_code=404, detail="Menu tidak ditemukan")

    update_data = data.dict(exclude_unset=True)
    resep_data = update_data.pop('resep', None)

    if 'foto_id' in update_data and data.foto_id != item.foto_id:
        old_foto_id = item.foto_id
        if data.foto_id is None:
            await remove_old_foto_if_replaced(db, old_foto_id, None)
        elif data.foto_id.startswith('http'):
            new_foto_id = str(uuid.uuid4())
            new_foto = Foto(id=new_foto_id, jenis='menu', path=data.foto_id, uploader_id=current_user.id, dipakai=True)
            db.add(new_foto)
            await db.flush()
            data.foto_id = new_foto_id
            update_data['foto_id'] = new_foto_id
            await remove_old_foto_if_replaced(db, old_foto_id, new_foto_id)
        else:
            await validate_and_claim_foto(db, data.foto_id, current_user.id, "menu", required=False)
            await remove_old_foto_if_replaced(db, old_foto_id, data.foto_id)

    for field, val in update_data.items():
        setattr(item, field, val)

    if resep_data is not None:
        old_reseps = await db.execute(select(MenuResep).where(MenuResep.menu_id == id))
        for r in old_reseps.scalars().all():
            await db.delete(r)
        await db.flush()

        for r in resep_data:
            b_id = r.bahan_id if hasattr(r, 'bahan_id') else r['bahan_id']
            jml = r.jumlah_terpakai if hasattr(r, 'jumlah_terpakai') else r['jumlah_terpakai']
            bahan = await db.get(Bahan, b_id)
            if not bahan:
                raise HTTPException(status_code=400, detail=f"Bahan dengan ID {b_id} tidak ditemukan")
            db.add(MenuResep(
                id=str(uuid.uuid4()),
                menu_id=id,
                bahan_id=b_id,
                jumlah_terpakai=jml
            ))

    item.diubah_oleh = current_user.id
    await db.commit()
    res = await db.execute(
        select(Menu)
        .options(
            selectinload(Menu.kategori),
            selectinload(Menu.resep).selectinload(MenuResep.bahan)
        )
        .where(Menu.id == item.id)
    )
    result_menu = res.scalar_one()
    _populate_menu_resep(result_menu)
    return result_menu

@router.delete("/menu/{id}")
async def delete_menu(
    id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    item = await db.get(Menu, id)
    if not item:
        raise HTTPException(status_code=404, detail="Menu tidak ditemukan")
    
    # We could do hard delete, or just soft delete. Let's do hard delete for now.
    await db.delete(item)
    await db.commit()
    return {"message": "Menu berhasil dihapus"}

# --- BAHAN ---
@router.get("/bahan/stok-menipis", response_model=List[BahanStokMenipisOut])
async def get_stok_menipis(
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
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
    if current_user.role in ["admin"]:
        return [BahanAdminOut.model_validate(b) for b in items]
    return [BahanOut.model_validate(b) for b in items]

@router.post("/bahan", response_model=BahanAdminOut)
async def create_bahan(
    data: BahanCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
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
    current_user: Karyawan = Depends(require_roles(["admin"]))
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
    current_user: Karyawan = Depends(require_roles(["admin"]))
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
    current_user: Karyawan = Depends(require_roles(["admin"]))
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
