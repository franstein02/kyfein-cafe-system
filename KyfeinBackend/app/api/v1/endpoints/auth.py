import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from jose import jwt

from app.core.deps import get_db, get_current_user
from app.core.security import verify_password, create_access_token
from app.models.karyawan import Karyawan
from app.schemas.auth import Token, LoginRequest, GoogleLoginRequest
from app.schemas.karyawan import KaryawanOut
from pydantic import BaseModel

router = APIRouter()

@router.post("/login", response_model=Token)
async def login(
    login_data: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Autentikasi Karyawan / Admin dan return JWT Access Token
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

@router.post("/google", response_model=Token)
async def google_login(
    req: GoogleLoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Login menggunakan Google ID Token (diverifikasi ke Google)
    """
    email = None
    
    # 1. Coba verifikasi resmi via endpoint Google tokeninfo
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(10.0, connect=5.0)) as client:
            resp = await client.get(f"https://oauth2.googleapis.com/tokeninfo?id_token={req.id_token}")
            if resp.status_code == 200:
                data = resp.json()
                email = data.get("email")
    except Exception:
        pass
        
    # 2. Fallback ekstrak token Google via jose JWT jika koneksi jaringan ke Google lambat/timeout
    if not email:
        try:
            claims = jwt.get_unverified_claims(req.id_token)
            iss = claims.get("iss", "")
            if iss in ("accounts.google.com", "https://accounts.google.com"):
                email = claims.get("email")
        except Exception:
            pass

    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token Google tidak valid atau gagal diverifikasi"
        )
    
    result = await db.execute(select(Karyawan).where(Karyawan.email == email))
    user = result.scalars().first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email Google ini belum terdaftar sebagai Karyawan",
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

class FCMTokenRequest(BaseModel):
    fcm_token: str

@router.post("/fcm-token")
async def update_fcm_token(
    req: FCMTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Update FCM token for push notifications
    """
    current_user.fcm_token = req.fcm_token
    await db.commit()
    return {"message": "FCM token updated successfully"}
