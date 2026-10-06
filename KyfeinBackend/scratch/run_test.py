import asyncio
import traceback
from datetime import date, time, timedelta
from decimal import Decimal
from httpx import AsyncClient, ASGITransport
from sqlalchemy.pool import StaticPool
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.core.security import create_access_token
from app.core.utils import now_local
from app.models.karyawan import Karyawan
from app.models.master_data import KonfigurasiLokasi, KategoriMenu, Menu, Bahan, KategoriPengeluaran
from app.models.jadwal import JadwalShift

TEST_DB_URL = "sqlite+aiosqlite:///:memory:"

async def main():
    try:
        engine = create_async_engine(
            TEST_DB_URL,
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
            echo=False
        )
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        session_factory = async_sessionmaker(
            bind=engine,
            class_=AsyncSession,
            expire_on_commit=False,
            autocommit=False,
            autoflush=False
        )

        async with session_factory() as test_db:
            # Seed data
            admin = Karyawan(id="usr-admin", nama="Admin Test", email="admin@kyfein.com", nomor_hp="0811111111", role="admin", password="hashedpassword")
            karyawan1 = Karyawan(id="usr-karyawan1", nama="Karyawan One", email="k1@kyfein.com", nomor_hp="0822222222", role="karyawan", password="hashedpassword")
            test_db.add_all([admin, karyawan1])
            bahan1 = Bahan(id="b-1", nama="Biji Kopi", satuan="gram", isi_per_kemasan=Decimal("1000"), harga_rata_rata=Decimal("150"), stok_minimum=Decimal("100"))
            test_db.add(bahan1)
            await test_db.commit()

        async def _override_get_db():
            async with session_factory() as session:
                yield session

        app.dependency_overrides[get_db] = _override_get_db
        transport = ASGITransport(app=app)
        token_k1 = create_access_token({"sub": "usr-karyawan1"})
        token_admin = create_access_token({"sub": "usr-admin"})

        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res_k1 = await client.get("/api/v1/master/bahan", headers={"Authorization": f"Bearer {token_k1}"})
            print("K1 Status:", res_k1.status_code)
            print("K1 Body:", res_k1.text)

            res_admin = await client.get("/api/v1/master/bahan", headers={"Authorization": f"Bearer {token_admin}"})
            print("Admin Status:", res_admin.status_code)
            print("Admin Body:", res_admin.text)

        app.dependency_overrides.clear()
        await engine.dispose()
    except Exception as e:
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
