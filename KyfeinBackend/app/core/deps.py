from typing import AsyncGenerator, List, Callable
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.core.security import decode_token
from app.models.karyawan import Karyawan

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")
oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

async def get_current_user(
    db: AsyncSession = Depends(get_db),
    token: str = Depends(oauth2_scheme)
) -> Karyawan:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token autentikasi tidak valid atau telah kadaluarsa",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = decode_token(token)
    if payload is None:
        raise credentials_exception
        
    user_id: str = payload.get("sub")
    if user_id is None:
        raise credentials_exception
        
    result = await db.execute(select(Karyawan).where(Karyawan.id == user_id))
    user = result.scalars().first()
    
    if user is None:
        raise credentials_exception
        
    if not user.status_aktif:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akun karyawan tidak aktif"
        )
        
    return user

async def get_optional_user(
    db: AsyncSession = Depends(get_db),
    token: str = Depends(oauth2_scheme_optional)
) -> Karyawan | None:
    if not token:
        return None
    try:
        return await get_current_user(db=db, token=token)
    except HTTPException:
        return None

def require_roles(allowed_roles: List[str]):
    async def role_checker(current_user: Karyawan = Depends(get_current_user)) -> Karyawan:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Akses ditolak. Fitur ini memerlukan role {allowed_roles}"
            )
        return current_user
    return role_checker
