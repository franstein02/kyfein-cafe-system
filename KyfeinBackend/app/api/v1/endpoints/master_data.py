from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.deps import get_db, require_roles, get_current_user
from app.models.master_data import KategoriMenu, Menu, Bahan, MenuResep, KategoriPengeluaran
from app.models.karyawan import Karyawan
from app.schemas.master_data import (
    KategoriMenuCreate, KategoriMenuOut,
    MenuCreate, MenuOut,
    BahanCreate, BahanOut,
    MenuResepCreate, MenuResepOut,
    KategoriPengeluaranCreate, KategoriPengeluaranOut
)

router = APIRouter()

# --- KATEGORI MENU ---
@router.get("/kategori-menu", response_model=List[KategoriMenuOut])
async def list_kategori_menu(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(KategoriMenu).where(KategoriMenu.status_aktif == True))
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
async def list_menu(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Menu).where(Menu.status_aktif == True))
    return result.scalars().all()

@router.post("/menu", response_model=MenuOut)
async def create_menu(
    data: MenuCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    item = Menu(**data.dict(), dibuat_oleh=current_user.id)
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item

# --- BAHAN ---
@router.get("/bahan", response_model=List[BahanOut])
async def list_bahan(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Bahan))
    return result.scalars().all()

@router.post("/bahan", response_model=BahanOut)
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
async def list_kategori_pengeluaran(db: AsyncSession = Depends(get_db)):
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
