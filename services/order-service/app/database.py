import asyncpg
from app.config import settings


async def create_pool():
    return await asyncpg.create_pool(dsn=settings.database_url, min_size=2, max_size=10)


async def init_db(pool):
    async with pool.acquire() as conn:
        await conn.execute(
            """
            CREATE TABLE IF NOT EXISTS orders (
                id SERIAL PRIMARY KEY,
                session_id VARCHAR(255) NOT NULL,
                items JSONB NOT NULL DEFAULT '[]',
                total NUMERIC(10,2) NOT NULL,
                status VARCHAR(50) NOT NULL DEFAULT 'pending',
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );
        """
        )
