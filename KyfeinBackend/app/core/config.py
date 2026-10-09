import os
from typing import List, Union
from pydantic import AnyHttpUrl, validator
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Kyfein Cafe POS API"
    API_V1_STR: str = "/api/v1"
    
    # Database
    DB_HOST: str = os.getenv("DB_HOST", "127.0.0.1")
    DB_PORT: int = int(os.getenv("DB_PORT", "3306"))
    DB_USER: str = os.getenv("DB_USER", "root")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "")
    DB_NAME: str = os.getenv("DB_NAME", "db_kyfein")
    
    SHIFT_TOLERANSI_JAM: int = int(os.getenv("SHIFT_TOLERANSI_JAM", "3"))

    
    @property
    def ASYNC_DATABASE_URL(self) -> str:
        # Using asyncmy for asyncio MySQL connection
        pwd_part = f":{self.DB_PASSWORD}" if self.DB_PASSWORD else ""
        return f"mysql+asyncmy://{self.DB_USER}{pwd_part}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"

    @property
    def SYNC_DATABASE_URL(self) -> str:
        # Using pymysql for synchronous script tasks (like seeding)
        pwd_part = f":{self.DB_PASSWORD}" if self.DB_PASSWORD else ""
        return f"mysql+pymysql://{self.DB_USER}{pwd_part}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"

    # JWT Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "secret_key_kyfein_cafe_system_2026_super_secure_token_change_me")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480 # 8 hours (1 shift)

    # CORS
    BACKEND_CORS_ORIGINS: List[str] = ["*"]

    # Upload Directory
    UPLOAD_DIR: str = os.getenv("UPLOAD_DIR", "uploads")

    class Config:
        case_sensitive = True
        env_file = ".env"
        extra = "allow"

settings = Settings()
