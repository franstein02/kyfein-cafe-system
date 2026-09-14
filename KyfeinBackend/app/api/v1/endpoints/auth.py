from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.deps import get_db, get_current_user
from app.core.security import verify_password, create_access_token
from app.models.karyawan import Karyawan
from app.schemas.auth import Token, LoginRequest
from app.schemas.karyawan import KaryawanOut

router = APIRouter()

@router.post("/login", response_model=Token)
async def login(
    login_data: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Autentikasi Karyawan / Admin / Owner dan return JWT Access Token
    """
    result = await db.execute(select(Karyawan).where(Karyawan.email == login_data.email))
    user = result.scalars().first()
    
    if not user or not verify_password(login_data.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email atau password salah",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    if not user.status_aktif:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akun karyawan telah dinonaktifkan"
        )
        
    access_token = create_access_token(subject=user.id, role=user.role)
    
    return Token(
        access_token=access_token,
        token_type="bearer",
        user_id=user.id,
        role=user.role,
        nama=user.nama
    )

@router.get("/me", response_model=KaryawanOut)
async def get_me(current_user: Karyawan = Depends(get_current_user)):
    """
    Get profil karyawan yang sedang login
    """
    return current_user
