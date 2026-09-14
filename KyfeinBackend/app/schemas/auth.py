from typing import Optional
from pydantic import BaseModel, EmailStr

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    role: str
    nama: str

class TokenPayload(BaseModel):
    sub: Optional[str] = None
    role: Optional[str] = None

class LoginRequest(BaseModel):
    email: EmailStr
    password: str
