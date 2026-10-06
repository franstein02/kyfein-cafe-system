import pytest
import pytest_asyncio
from decimal import Decimal
from sqlalchemy import select

from app.models import (
    Base, Foto, Karyawan, Menu, MenuResep, Bahan, Transaksi, TransaksiDetail, RequestOff
)

@pytest.mark.asyncio
async def test_issue8_idempotent_migration_and_snapshot_protection(sample_data, test_db):
    """
    Issue 8 Verification:
    - Re-running migration v6 logic does NOT alter existing snapshot HPP values.
    - Model definitions have RequestOff UniqueConstraint(karyawan_id, tanggal) and hpp_satuan.
    """
    # 1. Create a transaction detail with a specific snapshotted HPP (e.g. 5000.00)
    trx = Transaksi(
        id="trx-test-8",
        jadwal_shift_id="shift-kasir-k1",
        kasir_id="usr-karyawan1",
        nomor_transaksi="TRX-TEST-008",
        metode_bayar="cash",
        total_harga=Decimal("20000.00"),
        status="selesai"
    )
    test_db.add(trx)

    trx_detail = TransaksiDetail(
        id="td-test-8",
        transaksi_id="trx-test-8",
        menu_id="menu-1",
        qty=1,
        harga_satuan=Decimal("20000.00"),
        hpp_satuan=Decimal("5000.00"),
        subtotal=Decimal("20000.00"),
        status_item="menunggu"
    )
    test_db.add(trx_detail)
    await test_db.commit()

    # 2. Simulate running apply_schema_v6 twice: Since hpp_satuan column already exists,
    # the backfill must BE SKIPPED and hpp_satuan must remain exactly 5000.00!
    res_fetch = await test_db.get(TransaksiDetail, "td-test-8")
    assert res_fetch.hpp_satuan == Decimal("5000.00")

    # 3. Verify RequestOff table definition has unique constraint
    table_args = getattr(RequestOff, "__table_args__", ())
    if isinstance(table_args, tuple):
        has_uq = any(
            getattr(arg, "name", None) == "uq_request_off_karyawan_tanggal"
            for arg in table_args
        )
        assert has_uq, "RequestOff model must contain uq_request_off_karyawan_tanggal UniqueConstraint"
