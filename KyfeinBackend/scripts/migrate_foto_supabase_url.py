"""Idempotent migration: add foto.supabase_url and ensure Supabase folders (menu/ & absensi/)."""

import asyncio
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

import httpx
from sqlalchemy import text
from app.core.config import settings
from app.core.database import engine
from app.core.supabase_storage import build_public_url, upload_image_bytes


async def migrate() -> None:
    async with engine.begin() as conn:
        col_res = await conn.execute(text("SHOW COLUMNS FROM foto LIKE 'supabase_url'"))
        if col_res.first() is None:
            await conn.execute(
                text("ALTER TABLE foto ADD COLUMN supabase_url VARCHAR(500) NULL AFTER path")
            )
            print("Added column foto.supabase_url")
        else:
            print("foto.supabase_url already exists")

        await conn.execute(
            text(
                "UPDATE foto SET supabase_url = path "
                "WHERE supabase_url IS NULL AND (path LIKE 'http://%' OR path LIKE 'https://%')"
            )
        )
        print("Backfilled existing HTTP paths to foto.supabase_url")

    async with httpx.AsyncClient(timeout=15.0) as client:
        headers = {
            "apikey": settings.SUPABASE_KEY,
            "Authorization": f"Bearer {settings.SUPABASE_KEY}",
            "Content-Type": "application/json",
        }
        list_resp = await client.post(
            f"{settings.SUPABASE_URL.rstrip('/')}/storage/v1/object/list/{settings.SUPABASE_BUCKET}",
            headers=headers,
            json={"prefix": "", "limit": 50},
        )
        existing_folders = {x.get("name") for x in list_resp.json()} if list_resp.status_code == 200 else set()

        for folder in ("menu", "absensi"):
            placeholder_obj = f"{folder}/.emptyFolderPlaceholder"
            if folder not in existing_folders:
                check = await client.head(build_public_url(placeholder_obj))
                if check.status_code != 200:
                    await upload_image_bytes(
                        placeholder_obj,
                        b"",
                        content_type="application/octet-stream",
                    )
            print(f"Verified Supabase folder: Storage/{folder}/")


if __name__ == "__main__":
    asyncio.run(migrate())
