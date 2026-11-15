from typing import List, Dict, Optional
from fastapi import APIRouter, Body, Depends, Query, WebSocket, WebSocketDisconnect, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from sqlalchemy.orm import selectinload

from app.core.deps import get_db, get_current_user
from app.models.transaksi import Transaksi, TransaksiDetail
from app.models.master_data import Menu, KategoriMenu
from app.schemas.transaksi import TransaksiDetailOut, KdsStatusUpdate

router = APIRouter()


class KDSConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {
            "kitchen": [],
            "bar": [],
            "all": [],
        }

    async def connect(self, websocket: WebSocket, area_produksi: str):
        await websocket.accept()
        if area_produksi not in self.active_connections:
            self.active_connections[area_produksi] = []
        self.active_connections[area_produksi].append(websocket)

    def disconnect(self, websocket: WebSocket, area_produksi: str):
        if area_produksi in self.active_connections:
            if websocket in self.active_connections[area_produksi]:
                self.active_connections[area_produksi].remove(websocket)

    async def broadcast_order(self, area_produksi: str, message: dict):
        """Broadcast new transaction item or status update to targeted area_produksi screens"""
        if area_produksi in self.active_connections:
            for connection in list(self.active_connections[area_produksi]):
                try:
                    await connection.send_json(message)
                except Exception:
                    pass


kds_manager = KDSConnectionManager()


@router.websocket("/ws/{area_produksi}")
async def websocket_kds_endpoint(websocket: WebSocket, area_produksi: str):
    """
    ROUTING LAYAR KDS VIA WEBSOCKET:
    WebSocket connection endpoint grouped by area_produksi ('kitchen', 'bar', or 'all')
    """
    if area_produksi not in ["kitchen", "bar", "all"]:
        await websocket.close(code=4000)
        return

    await kds_manager.connect(websocket, area_produksi)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        kds_manager.disconnect(websocket, area_produksi)


@router.get("/orders/{area_produksi}", response_model=List[TransaksiDetailOut])
async def get_kds_orders_by_area(
    area_produksi: str,
    include_selesai: bool = Query(False),
    db: AsyncSession = Depends(get_db)
):
    """
    ROUTING LAYAR KDS REST API:
    Retrieve pending/in-progress (and optionally completed) orders routed by category area_produksi ('kitchen', 'bar', or 'all')
    """
    if area_produksi not in ["kitchen", "bar", "all"]:
        raise HTTPException(status_code=400, detail="Area produksi harus 'kitchen', 'bar', atau 'all'")

    statuses = ["menunggu", "diproses", "selesai"] if include_selesai else ["menunggu", "diproses"]

    conditions = [
        Transaksi.status == "selesai",
        TransaksiDetail.status_item.in_(statuses),
    ]
    if area_produksi != "all":
        conditions.append(KategoriMenu.area_produksi == area_produksi)

    result = await db.execute(
        select(TransaksiDetail)
        .join(Transaksi, TransaksiDetail.transaksi_id == Transaksi.id)
        .join(Menu, TransaksiDetail.menu_id == Menu.id)
        .join(KategoriMenu, Menu.kategori_id == KategoriMenu.id)
        .options(
            selectinload(TransaksiDetail.menu).selectinload(Menu.kategori),
            selectinload(TransaksiDetail.transaksi),
        )
        .where(and_(*conditions))
        .order_by(Transaksi.waktu_transaksi.desc(), TransaksiDetail.id.asc())
    )
    return result.scalars().all()


@router.put("/orders/detail/{detail_id}/status")
async def update_item_status(
    detail_id: str,
    status_item: Optional[str] = Query(None),
    payload: Optional[KdsStatusUpdate] = Body(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Update status_item oleh staff kitchen/bar (menunggu -> diproses -> selesai)
    Mendukung pengiriman status_item via query parameter maupun JSON body.
    """
    target_status = status_item or (payload.status_item if payload else None)
    if target_status not in ["menunggu", "diproses", "selesai"]:
        raise HTTPException(status_code=400, detail="Status item tidak valid")

    res = await db.execute(
        select(TransaksiDetail)
        .options(
            selectinload(TransaksiDetail.menu).selectinload(Menu.kategori),
            selectinload(TransaksiDetail.transaksi),
        )
        .where(TransaksiDetail.id == detail_id)
    )
    detail = res.scalars().first()
    if not detail:
        raise HTTPException(status_code=404, detail="Detail pesanan tidak ditemukan")

    detail.status_item = target_status
    await db.commit()

    area = detail.area_produksi or "kitchen"
    ws_msg = {
        "event": "status_updated",
        "id": detail.id,
        "detail_id": detail.id,
        "transaksi_id": detail.transaksi_id,
        "nomor_transaksi": detail.nomor_transaksi,
        "menu_id": detail.menu_id,
        "kode_menu": detail.kode_menu,
        "nama_menu": detail.nama_menu,
        "area_produksi": area,
        "qty": detail.qty,
        "catatan": detail.catatan,
        "status_item": target_status,
    }
    if area in ["kitchen", "bar"]:
        await kds_manager.broadcast_order(area, ws_msg)
    await kds_manager.broadcast_order("all", ws_msg)

    return {
        "message": "Status item berhasil diperbarui",
        "id": detail_id,
        "status_item": target_status,
    }
