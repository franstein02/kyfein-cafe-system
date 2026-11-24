"""End-to-end verification for KDS Bar & Kitchen routing, WebSocket broadcast, status updates, and cancellation."""

import asyncio
from decimal import Decimal
import pytest
from starlette.testclient import TestClient

from app.main import app
from app.core.deps import get_db
from app.models import Absensi, JadwalShift, KategoriMenu, Menu


@pytest.mark.asyncio
async def test_kds_bar_and_kitchen_order_routing_status_and_cancel(
    client, sample_data, test_db, mock_time_at
):
    """
    Verifikasi alur lengkap KDS Bar & Kitchen:
    1. Pesanan POS campuran (Minuman Bar + Makanan Kitchen) masuk tepat ke masing-masing area.
    2. KDS Bar hanya menerima menu area 'bar', KDS Kitchen hanya menerima menu area 'kitchen'.
    3. Update status menunggu -> diproses -> selesai berfungsi per item.
    4. Pembatalan transaksi menghapus item dari antrian KDS aktif.
    """
    mock_time_at("20:00")
    # Tambah kategori kitchen & menu kitchen (+ menu bar sudah ada di sample_data: menu-1)
    kat_kitchen = KategoriMenu(
        id="kat-kds-kitchen",
        nama="Makanan Berat",
        area_produksi="kitchen",
        status_aktif=True,
    )
    menu_kitchen = Menu(
        id="menu-kds-nasgor",
        nama="Nasi Goreng Spesial",
        kode_menu="MKN99",
        kategori_id="kat-kds-kitchen",
        harga=Decimal("28000.00"),
        status_aktif=True,
    )
    absen_kasir = Absensi(
        id="abs-kds-kasir",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-kasir-k1",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1",
        menit_telat=0,
    )
    test_db.add_all([kat_kitchen, menu_kitchen, absen_kasir])
    await test_db.commit()

    headers_kasir = {"Authorization": f"Bearer {sample_data['token_k1']}"}
    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}

    # 1. Buat transaksi campuran Bar (qty 2) + Kitchen (qty 1) via POS endpoint
    res_trx = await client.post(
        "/api/v1/transaksi/",
        headers=headers_kasir,
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "cash",
            "uang_diterima": 100000,
            "details": [
                {"menu_id": "menu-1", "qty": 2, "catatan": "Less sugar"},
                {"menu_id": "menu-kds-nasgor", "qty": 1, "catatan": "Pedas sedang"},
            ],
        },
    )
    assert res_trx.status_code == 200
    trx_data = res_trx.json()
    assert len(trx_data["details"]) == 2
    bar_det = next(d for d in trx_data["details"] if d["menu_id"] == "menu-1")
    kitchen_det = next(d for d in trx_data["details"] if d["menu_id"] == "menu-kds-nasgor")
    assert bar_det["area_produksi"] == "bar"
    assert kitchen_det["area_produksi"] == "kitchen"

    # 2. KDS Bar hanya menerima item Bar; KDS Kitchen hanya menerima item Kitchen; All menerima keduanya
    res_bar = await client.get("/api/v1/kds/orders/bar", headers=headers_kasir)
    assert res_bar.status_code == 200
    bar_orders = res_bar.json()
    assert [o["id"] for o in bar_orders] == [bar_det["id"]]
    assert bar_orders[0]["catatan"] == "Less sugar"
    assert bar_orders[0]["status_item"] == "menunggu"

    res_kitchen = await client.get("/api/v1/kds/orders/kitchen", headers=headers_kasir)
    assert res_kitchen.status_code == 200
    kitchen_orders = res_kitchen.json()
    assert [o["id"] for o in kitchen_orders] == [kitchen_det["id"]]
    assert kitchen_orders[0]["catatan"] == "Pedas sedang"
    assert kitchen_orders[0]["status_item"] == "menunggu"

    res_all = await client.get("/api/v1/kds/orders/all", headers=headers_admin)
    assert res_all.status_code == 200
    assert {o["id"] for o in res_all.json()} == {bar_det["id"], kitchen_det["id"]}

    # 3. Staff Bar proses & selesaikan item Bar; Staff Kitchen proses item Kitchen
    res_bar_proc = await client.put(
        f"/api/v1/kds/orders/detail/{bar_det['id']}/status?status_item=diproses",
        headers=headers_admin,
        json={"status_item": "diproses"},
    )
    assert res_bar_proc.status_code == 200
    assert res_bar_proc.json()["status_item"] == "diproses"

    res_bar_done = await client.put(
        f"/api/v1/kds/orders/detail/{bar_det['id']}/status?status_item=selesai",
        headers=headers_admin,
        json={"status_item": "selesai"},
    )
    assert res_bar_done.status_code == 200
    assert res_bar_done.json()["status_item"] == "selesai"

    # Default GET /kds/orders/bar (include_selesai=false) tidak lagi menampilkan item selesai,
    # sedangkan include_selesai=true menampilkannya sebagai 'selesai'
    assert (await client.get("/api/v1/kds/orders/bar", headers=headers_admin)).json() == []
    bar_with_done = (await client.get("/api/v1/kds/orders/bar?include_selesai=true", headers=headers_admin)).json()
    assert bar_with_done[0]["status_item"] == "selesai"

    # Item kitchen masih menunggu di antrian aktif kitchen
    assert (await client.get("/api/v1/kds/orders/kitchen", headers=headers_admin)).json()[0]["status_item"] == "menunggu"

    # 4. Pembatalan transaksi otomatis mengeluarkan item dari KDS aktif
    res_cancel = await client.put(
        f"/api/v1/transaksi/{trx_data['id']}/cancel",
        headers=headers_admin,
    )
    assert res_cancel.status_code == 200
    assert (await client.get("/api/v1/kds/orders/kitchen?include_selesai=true", headers=headers_admin)).json() == []
    assert (await client.get("/api/v1/kds/orders/bar?include_selesai=true", headers=headers_admin)).json() == []


def test_kds_websocket_realtime_isolation():
    """
    Verifikasi WebSocket /api/v1/kds/ws/{area} terhubung bersih untuk bar, kitchen, dan all
    serta kds_manager merutekan broadcast hanya ke area tujuan & 'all'.
    """
    from app.api.v1.endpoints.kds import kds_manager

    with TestClient(app) as tc:
        with tc.websocket_connect("/api/v1/kds/ws/bar") as ws_bar, \
             tc.websocket_connect("/api/v1/kds/ws/kitchen") as ws_kitchen, \
             tc.websocket_connect("/api/v1/kds/ws/all") as ws_all:

            bar_msg = {
                "event": "new_order",
                "id": "det-ws-bar",
                "area_produksi": "bar",
                "nama_menu": "Kopi Susu Gula Aren",
                "qty": 1,
                "status_item": "menunggu",
            }
            kitchen_msg = {
                "event": "new_order",
                "id": "det-ws-kitchen",
                "area_produksi": "kitchen",
                "nama_menu": "Nasi Kebuli",
                "qty": 2,
                "status_item": "menunggu",
            }

            async def _dispatch():
                await kds_manager.broadcast_order("bar", bar_msg)
                await kds_manager.broadcast_order("all", bar_msg)
                await kds_manager.broadcast_order("kitchen", kitchen_msg)
                await kds_manager.broadcast_order("all", kitchen_msg)

            tc.portal.call(_dispatch)

            assert ws_bar.receive_json()["id"] == "det-ws-bar"
            assert ws_kitchen.receive_json()["id"] == "det-ws-kitchen"
            assert ws_all.receive_json()["id"] == "det-ws-bar"
            assert ws_all.receive_json()["id"] == "det-ws-kitchen"


@pytest.mark.asyncio
async def test_pos_qris_statis_without_photo_succeeds_and_routes_to_kds(
    client, sample_data, test_db, mock_time_at
):
    """QRIS statis cafe cukup konfirmasi pembayaran masuk tanpa wajib upload foto bukti."""
    mock_time_at("20:00")
    kat_kitchen = KategoriMenu(
        id="kat-qris-kitchen",
        nama="Makanan",
        area_produksi="kitchen",
        status_aktif=True,
    )
    menu_kitchen = Menu(
        id="menu-qris-mkn",
        nama="Roti Bakar Keju",
        kode_menu="MKN88",
        kategori_id="kat-qris-kitchen",
        harga=Decimal("18000.00"),
        status_aktif=True,
    )
    absen_kasir = Absensi(
        id="abs-qris-kasir",
        karyawan_id="usr-karyawan1",
        jadwal_shift_id="shift-kasir-k1",
        lat_masuk=Decimal("-6.20000000"),
        lng_masuk=Decimal("106.80000000"),
        foto_masuk_id="foto-k1",
        menit_telat=0,
    )
    test_db.add_all([kat_kitchen, menu_kitchen, absen_kasir])
    await test_db.commit()

    headers_kasir = {"Authorization": f"Bearer {sample_data['token_k1']}"}

    # Nominal kurang dari total_harga tetap ditolak 400
    res_kurang = await client.post(
        "/api/v1/transaksi/",
        headers=headers_kasir,
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "qris",
            "uang_diterima": 10000,
            "details": [{"menu_id": "menu-1", "qty": 1}],
        },
    )
    assert res_kurang.status_code == 400

    # QRIS statis tanpa foto_bukti_qris_id -> 200 OK & masuk KDS Bar + Kitchen
    res_qris = await client.post(
        "/api/v1/transaksi/",
        headers=headers_kasir,
        json={
            "jadwal_shift_id": "shift-kasir-k1",
            "metode_bayar": "qris",
            "uang_diterima": 38000,
            "details": [
                {"menu_id": "menu-1", "qty": 1},
                {"menu_id": "menu-qris-mkn", "qty": 1},
            ],
        },
    )
    assert res_qris.status_code == 200
    data = res_qris.json()
    assert data["metode_bayar"] == "qris"
    assert data["foto_bukti_qris_id"] is None
    assert Decimal(str(data["total_harga"])) == Decimal("38000.00")

    headers_admin = {"Authorization": f"Bearer {sample_data['token_admin']}"}
    bar_orders = (await client.get("/api/v1/kds/orders/bar", headers=headers_admin)).json()
    kitchen_orders = (await client.get("/api/v1/kds/orders/kitchen", headers=headers_admin)).json()
    assert any(o["menu_id"] == "menu-1" for o in bar_orders)
    assert any(o["menu_id"] == "menu-qris-mkn" for o in kitchen_orders)
