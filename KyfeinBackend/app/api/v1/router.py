from fastapi import APIRouter

from app.api.v1.endpoints import (
    auth, karyawan, master_data, transaksi,
    stok, absensi, jadwal, kds, reporting, foto
)

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(karyawan.router, prefix="/karyawan", tags=["Karyawan"])
api_router.include_router(master_data.router, prefix="/master", tags=["Master Data"])
api_router.include_router(transaksi.router, prefix="/transaksi", tags=["POS & Transaksi"])
api_router.include_router(stok.router, prefix="/stok", tags=["Stok & Opname"])
api_router.include_router(absensi.router, prefix="/absensi", tags=["Absensi & Izin"])
api_router.include_router(jadwal.router, prefix="/jadwal", tags=["Jadwal Shift"])
api_router.include_router(kds.router, prefix="/kds", tags=["Layar KDS"])
api_router.include_router(reporting.router, prefix="/reporting", tags=["Reporting & Profit"])
api_router.include_router(foto.router, prefix="/foto", tags=["Foto"])
