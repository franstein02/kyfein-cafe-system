import pytest
import pytest_asyncio
from datetime import date, time, timedelta
from decimal import Decimal
from httpx import AsyncClient, ASGITransport
from sqlalchemy.pool import StaticPool
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

from app.main import app
from app.core.deps import get_db
from app.core.security import create_access_token
from app.core.utils import now_local
from app.models import (
    Base, Foto, Karyawan, KonfigurasiLokasi, KategoriMenu, Menu, Bahan, KategoriPengeluaran, JadwalShift
)

TEST_DB_URL = "sqlite+aiosqlite:///:memory:"

from sqlalchemy import event
from sqlalchemy.engine import Engine

@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    if "sqlite" in dbapi_connection.__class__.__module__.lower():
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

@pytest_asyncio.fixture
async def test_engine():
    engine = create_async_engine(
        TEST_DB_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=False
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield engine

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()

@pytest_asyncio.fixture
async def test_session_factory(test_engine):
    return async_sessionmaker(
        bind=test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False
    )

@pytest_asyncio.fixture
async def test_db(test_session_factory):
    async with test_session_factory() as session:
        yield session

@pytest_asyncio.fixture
async def client(test_session_factory):
    async def _override_get_db():
        async with test_session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = _override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()

@pytest_asyncio.fixture
async def sample_data(test_db):
    # Location config
    lokasi = KonfigurasiLokasi(
        id="lok-1",
        latitude=Decimal("-6.20000000"),
        longitude=Decimal("106.80000000"),
        radius_meter=Decimal("100.00")
    )
    test_db.add(lokasi)

    # Users
    admin = Karyawan(
        id="usr-admin",
        nama="Admin Test",
        email="admin@kyfein.com",
        nomor_hp="0811111111",
        role="admin",
        password="hashedpassword"
    )
    karyawan1 = Karyawan(
        id="usr-karyawan1",
        nama="Karyawan One",
        email="k1@kyfein.com",
        nomor_hp="0822222222",
        role="karyawan",
        password="hashedpassword"
    )
    karyawan2 = Karyawan(
        id="usr-karyawan2",
        nama="Karyawan Two",
        email="k2@kyfein.com",
        nomor_hp="0833333333",
        role="karyawan",
        password="hashedpassword"
    )
    test_db.add_all([admin, karyawan1, karyawan2])
    await test_db.flush()

    # Kategori & Menu
    kat_aktif = KategoriMenu(id="kat-1", nama="Coffee", area_produksi="bar", status_aktif=True)
    kat_nonaktif = KategoriMenu(id="kat-2", nama="Non-Coffee Old", area_produksi="bar", status_aktif=False)
    menu_aktif = Menu(id="menu-1", nama="Espresso", kode_menu="ESP01", harga=Decimal("20000"), kategori_id="kat-1", status_aktif=True)
    menu_nonaktif = Menu(id="menu-2", nama="Old Latte", kode_menu="LAT01", harga=Decimal("25000"), kategori_id="kat-1", status_aktif=False)
    test_db.add_all([kat_aktif, kat_nonaktif, menu_aktif, menu_nonaktif])

    # Bahan
    bahan1 = Bahan(id="b-1", nama="Biji Kopi", satuan="gram", isi_per_kemasan=Decimal("1000"), harga_rata_rata=Decimal("150"), stok_minimum=Decimal("100"))
    test_db.add(bahan1)

    # Kategori Pengeluaran
    kat_peng = KategoriPengeluaran(id="katp-1", nama="Operasional", status_aktif=True)
    test_db.add(kat_peng)

    # Today's Shifts
    today = now_local().date()
    shift_bar_k1 = JadwalShift(
        id="shift-bar-k1",
        karyawan_id="usr-karyawan1",
        tanggal=today,
        shift="shift_1",
        area_kerja="bar",
        jam_mulai=time(8, 0),
        jam_selesai=time(16, 0)
    )
    shift_bar_k2 = JadwalShift(
        id="shift-bar-k2",
        karyawan_id="usr-karyawan2",
        tanggal=today,
        shift="shift_2",
        area_kerja="bar",
        jam_mulai=time(16, 0),
        jam_selesai=time(23, 0)
    )
    shift_kasir_k1 = JadwalShift(
        id="shift-kasir-k1",
        karyawan_id="usr-karyawan1",
        tanggal=today,
        shift="shift_2",
        area_kerja="kasir",
        jam_mulai=time(16, 0),
        jam_selesai=time(23, 0)
    )
    # Past Shifts
    shift_past = JadwalShift(
        id="shift-past",
        karyawan_id="usr-karyawan1",
        tanggal=today - timedelta(days=2),
        shift="shift_1",
        area_kerja="bar",
        jam_mulai=time(8, 0),
        jam_selesai=time(16, 0)
    )
    shift_past2 = JadwalShift(
        id="shift-past2",
        karyawan_id="usr-karyawan2",
        tanggal=today - timedelta(days=2),
        shift="shift_1",
        area_kerja="bar",
        jam_mulai=time(8, 0),
        jam_selesai=time(16, 0)
    )
    test_db.add_all([shift_bar_k1, shift_bar_k2, shift_kasir_k1, shift_past, shift_past2])

    # Dummy Foto records for tests
    foto_k1 = Foto(id="foto-k1", jenis="absensi", path="uploads/test1.jpg", uploader_id="usr-karyawan1", dipakai=False)
    foto_izin_k1 = Foto(id="foto-izin-k1", jenis="izin", path="uploads/test2.jpg", uploader_id="usr-karyawan1", dipakai=False)
    test_db.add_all([foto_k1, foto_izin_k1])

    await test_db.commit()

    token_admin = create_access_token("usr-admin", "admin")
    token_k1 = create_access_token("usr-karyawan1", "karyawan")
    token_k2 = create_access_token("usr-karyawan2", "karyawan")

    return {
        "token_admin": token_admin,
        "token_k1": token_k1,
        "token_k2": token_k2,
        "today": today,
        "foto_k1": foto_k1,
        "foto_izin_k1": foto_izin_k1
    }
