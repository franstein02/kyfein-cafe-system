from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError
from contextlib import asynccontextmanager

from app.core.config import settings
from app.api.v1.router import api_router

from app.core.firebase_config import init_firebase

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_firebase()
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    description="Backend API Modular Monolith untuk Sistem Kasir Cafe Kyfein",
    lifespan=lifespan
)

@app.exception_handler(IntegrityError)
async def integrity_error_handler(request: Request, exc: IntegrityError):
    err_msg = str(exc.orig) if hasattr(exc, 'orig') and exc.orig else str(exc)
    err_msg_lower = err_msg.lower()
    if "foreign key" in err_msg_lower or "foreignkey" in err_msg_lower or "1452" in err_msg or "1451" in err_msg:
        return JSONResponse(
            status_code=400,
            content={"detail": "Referensi data tidak ditemukan atau melanggar relasi (Foreign Key error)"}
        )
    return JSONResponse(
        status_code=409,
        content={"detail": "Data sudah ada atau melanggar batasan unik (Duplicate/Unique key error)"}
    )

# Set CORS
if settings.BACKEND_CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[str(origin) for origin in settings.BACKEND_CORS_ORIGINS],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(api_router, prefix=settings.API_V1_STR)

@app.get("/")
async def root():
    return {
        "app": settings.PROJECT_NAME,
        "status": "online",
        "docs": "/docs",
        "api_v1": settings.API_V1_STR
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
