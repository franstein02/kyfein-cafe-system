from typing import List, Dict
from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.core.deps import get_db, get_current_user
from app.models.transaksi import Transaksi, TransaksiDetail
from app.models.menu import Menu
from app.models.master_data import KategoriMenu
from app.schemas.transaksi import TransaksiDetailOut

router = APIRouter()

# Active WebSocket Connection Manager for KDS (Kitchen Display System)
class KDSConnectionManager:
    def __init__(self):
        # Active connections per area_produksi ('kitchen', 'bar')
        self.active_connections: Dict[str, List[WebSocket]] = {
            "kitchen": [],
            "bar": []
        }

    async def connect(self, websocket: WebSocket, area_produksi: str):
        await websocket.accept()
        if area_produksi in self.active_connections:
            self.active_connections[area_produksi].append(websocket)

    def disconnect(self, websocket: WebSocket, area_produksi: str):
        if area_produksi in self.active_connections:
            if websocket in self.active_connections[area_produksi]:
                self.active_connections[area_produksi].remove(websocket)

    async def broadcast_order(self, area_produksi: str, message: dict):
        """Broadcast new transaction item specifically to the targeted area_produksi screen"""
        if area_produksi in self.active_connections:
            for connection in self.active_connections[area_produksi]:
                try:
                    await connection.send_json(message)
                except Exception:
                    pass

kds_manager = KDSConnectionManager()

@router.websocket("/ws/{area_produksi}")
async def websocket_kds_endpoint(websocket: WebSocket, area_produksi: str):
    """
    ROUTING LAYAR KDS VIA WEBSOCKET:
    WebSocket connection endpoint grouped by area_produksi ('kitchen' or 'bar')
    """
    if area_produksi not in ["kitchen", "bar"]:
        await websocket.close(code=4000)
        return

    await kds_manager.connect(websocket, area_produksi)
    try:
        while True:
            # Keep connection alive
            data = await websocket.receive_text()
    except WebSocketDisconnect:
        kds_manager.disconnect(websocket, area_produksi)

@router.get("/orders/{area_produksi}", response_model=List[TransaksiDetailOut])
async def get_kds_orders_by_area(
    area_produksi: str,
    db: AsyncSession = Depends(get_db)
):
    """
    ROUTING LAYAR KDS REST API:
    Retrieve pending/in-progress orders routed by category area_produksi ('kitchen' / 'bar')
    """
    if area_produksi not in ["kitchen", "bar"]:
        raise HTTPException(status_code=400, detail="Area produksi harus 'kitchen' atau 'bar'")

    # Query transaksi_detail JOIN menu JOIN kategori_menu WHERE area_produksi = area_produksi
    result = await db.execute(
        select(TransaksiDetail)
        .join(Menu, TransaksiDetail.menu_id == Menu.id)
        .join(KategoriMenu, Menu.kategori_id == KategoriMenu.id)
        .where(
            and_(
                KategoriMenu.area_produksi == area_produksi,
                TransaksiDetail.status_item.in_(["menunggu", "diproses"])
            )
        )
        .order_by(TransaksiDetail.id)
    )
    return result.scalars().all()

@router.put("/orders/detail/{detail_id}/status")
async def update_item_status(
    detail_id: str,
    status_item: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Update status_item oleh staff kitchen/bar (menunggu -> diproses -> selesai)
    """
    if status_item not in ["menunggu", "diproses", "selesai"]:
        raise HTTPException(status_code=400, detail="Status item tidak valid")

    detail = await db.get(TransaksiDetail, detail_id)
    if not detail:
        raise HTTPException(status_code=404, detail="Detail pesanan tidak ditemukan")

    detail.status_item = status_item
    await db.commit()
    return {"message": "Status item berhasil diperbarui", "id": detail_id, "status_item": status_item}
