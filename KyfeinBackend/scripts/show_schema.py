import asyncio
from sqlalchemy import text
from app.core.database import engine

async def print_schema():
    async with engine.begin() as conn:
        result = await conn.execute(text("SHOW TABLES"))
        tables = [r[0] for r in result.fetchall()]
        
        for table in tables:
            res = await conn.execute(text(f"SHOW CREATE TABLE {table}"))
            create_stmt = res.fetchone()[1]
            print(f"--- {table} ---")
            print(create_stmt)
            print()

if __name__ == "__main__":
    asyncio.run(print_schema())
