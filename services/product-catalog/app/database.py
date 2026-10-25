import asyncpg
from app.config import settings


async def create_pool():
    return await asyncpg.create_pool(dsn=settings.database_url, min_size=2, max_size=10)


async def init_db(pool):
    async with pool.acquire() as conn:
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS products (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                price NUMERIC(10,2) NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        """)
        count = await conn.fetchval("SELECT COUNT(*) FROM products")
        if count == 0:
            await conn.executemany(
                "INSERT INTO products (name, description, price) VALUES ($1, $2, $3)",
                [
                    (
                        "Wireless Bluetooth Headphones",
                        "Noise-cancelling over-ear headphones with 30hr battery life.",
                        79.99,
                    ),
                    (
                        "Ergonomic Keyboard",
                        "Mechanical keyboard with Cherry MX switches and wrist rest.",
                        129.99,
                    ),
                    (
                        "USB-C Hub 7-in-1",
                        "HDMI 4K, USB 3.0, SD card reader, and PD 100W charging.",
                        34.99,
                    ),
                    (
                        "27-inch 4K Monitor",
                        "IPS panel, 99% sRGB, USB-C with 65W power delivery.",
                        449.99,
                    ),
                    (
                        "Smart LED Desk Lamp",
                        "Adjustable color temperature, wireless charging base.",
                        59.99,
                    ),
                    (
                        "Portable SSD 1TB",
                        "USB 3.2 Gen 2, read 1050MB/s, IP55 water resistant.",
                        109.99,
                    ),
                    (
                        "Webcam 4K",
                        "Auto-focus, built-in ring light, privacy shutter.",
                        89.99,
                    ),
                    (
                        "Mechanical Mouse",
                        "Wireless, 8 programmable buttons, 16000 DPI sensor.",
                        54.99,
                    ),
                ],
            )
