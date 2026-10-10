import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.config import settings

async def add_col():
    engine = create_async_engine(settings.ASYNC_DATABASE_URL)
    async with engine.begin() as conn:
        try:
            await conn.execute(text('ALTER TABLE karyawan ADD COLUMN fcm_token VARCHAR(255) NULL;'))
            print("Column added")
        except Exception as e:
            print(e)

asyncio.run(add_col())
