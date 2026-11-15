from typing import List, Optional, Literal
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.deps import get_db, require_roles, get_current_user
from app.core.security import get_password_hash
from app.core.foto_helper import validate_and_claim_foto, remove_old_foto_if_replaced
from app.models.karyawan import Karyawan
from app.schemas.karyawan import KaryawanCreate, KaryawanUpdate, KaryawanOut

router = APIRouter()


def _normalize_optional_str(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    cleaned = value.strip()
    return cleaned if cleaned else None


@router.get("", response_model=List[KaryawanOut])
@router.get("/", response_model=List[KaryawanOut])
async def list_karyawan(
    divisi: Optional[Literal['kasir', 'bar', 'kitchen']] = Query(default=None),
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    stmt = select(Karyawan)
    if divisi is not None:
        stmt = stmt.where(Karyawan.divisi == divisi)
    result = await db.execute(stmt.order_by(Karyawan.nama))
    return result.scalars().all()


@router.post("/", response_model=KaryawanOut)
async def create_karyawan(
    karyawan_in: KaryawanCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    if karyawan_in.role == "admin":
        raise HTTPException(status_code=403, detail="Tidak dapat membuat akun admin melalui API")

    email = karyawan_in.email.strip().lower()
    nama = karyawan_in.nama.strip()
    nomor_hp = _normalize_optional_str(karyawan_in.nomor_hp)
    divisi = karyawan_in.divisi or "kasir"

    if not nama:
        raise HTTPException(status_code=400, detail="Nama karyawan tidak boleh kosong")
    if not karyawan_in.password or not karyawan_in.password.strip():
        raise HTTPException(status_code=400, detail="Password wajib diisi")

    existing_email = await db.execute(select(Karyawan).where(Karyawan.email == email))
    if existing_email.scalars().first():
        raise HTTPException(status_code=409, detail="Email sudah terdaftar")

    if nomor_hp is not None:
        existing_hp = await db.execute(select(Karyawan).where(Karyawan.nomor_hp == nomor_hp))
        if existing_hp.scalars().first():
            raise HTTPException(status_code=409, detail="Nomor HP sudah terdaftar")

    if karyawan_in.foto_profile_id:
        await validate_and_claim_foto(db, karyawan_in.foto_profile_id, current_user.id, "profil", required=False)

    new_karyawan = Karyawan(
        nama=nama,
        email=email,
        nomor_hp=nomor_hp,
        role=karyawan_in.role,
        divisi=divisi,
        password=get_password_hash(karyawan_in.password),
        foto_profile_id=karyawan_in.foto_profile_id,
        status_aktif=karyawan_in.status_aktif
    )
    db.add(new_karyawan)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Email atau nomor HP sudah terdaftar")
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

    # Admin tidak boleh mengubah akun admin manapun (termasuk dirinya sendiri)
    if target.role == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akun admin tidak dapat diubah melalui API"
        )

    if karyawan_in.foto_profile_id is not None and karyawan_in.foto_profile_id != target.foto_profile_id:
        await validate_and_claim_foto(db, karyawan_in.foto_profile_id, current_user.id, "profil", required=False)
        await remove_old_foto_if_replaced(db, target.foto_profile_id, karyawan_in.foto_profile_id)
        target.foto_profile_id = karyawan_in.foto_profile_id

    if karyawan_in.nama is not None:
        cleaned_nama = karyawan_in.nama.strip()
        if not cleaned_nama:
            raise HTTPException(status_code=400, detail="Nama karyawan tidak boleh kosong")
        target.nama = cleaned_nama

    if karyawan_in.email is not None and current_user.role == "admin":
        new_email = karyawan_in.email.strip().lower()
        if new_email != target.email:
            existing_email = await db.execute(
                select(Karyawan).where(Karyawan.email == new_email, Karyawan.id != target.id)
            )
            if existing_email.scalars().first():
                raise HTTPException(status_code=409, detail="Email sudah terdaftar")
            target.email = new_email

    if karyawan_in.nomor_hp is not None:
        new_hp = _normalize_optional_str(karyawan_in.nomor_hp)
        if new_hp is not None and new_hp != target.nomor_hp:
            existing_hp = await db.execute(
                select(Karyawan).where(Karyawan.nomor_hp == new_hp, Karyawan.id != target.id)
            )
            if existing_hp.scalars().first():
                raise HTTPException(status_code=409, detail="Nomor HP sudah terdaftar")
        target.nomor_hp = new_hp

    if karyawan_in.divisi is not None and current_user.role == "admin":
        target.divisi = karyawan_in.divisi

    if karyawan_in.password is not None and karyawan_in.password.strip():
        target.password = get_password_hash(karyawan_in.password)

    if karyawan_in.status_aktif is not None and current_user.role == "admin":
        target.status_aktif = karyawan_in.status_aktif

    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Email atau nomor HP sudah terdaftar")
    await db.refresh(target)
    return target

