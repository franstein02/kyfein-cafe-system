from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.deps import get_db, require_roles, get_current_user
from app.core.security import get_password_hash
from app.models.karyawan import Karyawan
from app.schemas.karyawan import KaryawanCreate, KaryawanUpdate, KaryawanOut

router = APIRouter()

@router.get("/", response_model=List[KaryawanOut])
async def list_karyawan(
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    result = await db.execute(select(Karyawan).order_by(Karyawan.nama))
    return result.scalars().all()

@router.post("/", response_model=KaryawanOut)
async def create_karyawan(
    karyawan_in: KaryawanCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin", "owner"]))
):
    # Batasan role elevation (4.2 & 4.3)
    if karyawan_in.role in ["admin", "owner"] and current_user.role != "owner":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Hanya Owner yang berhak membuat akun role Admin atau Owner"
        )

    existing = await db.execute(select(Karyawan).where(Karyawan.email == karyawan_in.email))
    if existing.scalars().first():
        raise HTTPException(status_code=400, detail="Email sudah terdaftar")

    new_karyawan = Karyawan(
        nama=karyawan_in.nama,
        email=karyawan_in.email,
        nomor_hp=karyawan_in.nomor_hp,
        role=karyawan_in.role,
        password=get_password_hash(karyawan_in.password),
        foto_profile=karyawan_in.foto_profile,
        status_aktif=karyawan_in.status_aktif
    )
    db.add(new_karyawan)
    await db.commit()
    await db.refresh(new_karyawan)
    return new_karyawan

@router.put("/{karyawan_id}", response_model=KaryawanOut)
async def update_karyawan(
    karyawan_id: str,
    karyawan_in: KaryawanUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    # Karyawan biasa hanya boleh update profil sendiri
    if current_user.role == "karyawan" and current_user.id != karyawan_id:
        raise HTTPException(status_code=403, detail="Hanya dapat mengedit profil diri sendiri")

    result = await db.execute(select(Karyawan).where(Karyawan.id == karyawan_id))
    target = result.scalars().first()
    if not target:
        raise HTTPException(status_code=404, detail="Karyawan tidak ditemukan")

    if karyawan_in.nama is not None:
        target.nama = karyawan_in.nama
    if karyawan_in.nomor_hp is not None:
        target.nomor_hp = karyawan_in.nomor_hp
    if karyawan_in.foto_profile is not None:
        target.foto_profile = karyawan_in.foto_profile
    if karyawan_in.password:
        target.password = get_password_hash(karyawan_in.password)
    if karyawan_in.status_aktif is not None and current_user.role in ["admin", "owner"]:
        target.status_aktif = karyawan_in.status_aktif

    await db.commit()
    await db.refresh(target)
    return target
