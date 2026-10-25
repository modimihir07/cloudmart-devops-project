from fastapi import APIRouter, HTTPException
from app.models import Product
from app.database import create_pool

router = APIRouter()
pool = None


async def get_pool():
    global pool
    if pool is None:
        pool = await create_pool()
    return pool


@router.get("/health")
async def health():
    p = await get_pool()
    async with p.acquire() as conn:
        await conn.fetchval("SELECT 1")
    return {"status": "healthy", "service": "product-catalog"}


@router.get("/ready")
async def ready():
    return {"status": "ready"}


@router.get("/products", response_model=list[Product])
async def list_products():
    p = await get_pool()
    async with p.acquire() as conn:
        rows = await conn.fetch(
            "SELECT id, name, description, price, created_at FROM products ORDER BY id"
        )
    return [Product(**dict(r)) for r in rows]


@router.get("/products/{product_id}", response_model=Product)
async def get_product(product_id: int):
    p = await get_pool()
    async with p.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, name, description, price, created_at FROM products WHERE id = $1",
            product_id,
        )
    if row is None:
        raise HTTPException(status_code=404, detail="Product not found")
    return Product(**dict(row))
