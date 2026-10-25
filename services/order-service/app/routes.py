import json
from fastapi import APIRouter, HTTPException, Request
from app.models import Order, OrderCreate
from app.database import create_pool

router = APIRouter()
pool = None


async def get_pool():
    global pool
    if pool is None:
        pool = await create_pool()
    return pool


def _to_order(row) -> Order:
    d = dict(row)
    if isinstance(d.get("items"), str):
        d["items"] = json.loads(d["items"])
    return Order(**d)


@router.get("/health")
async def health():
    p = await get_pool()
    async with p.acquire() as conn:
        await conn.fetchval("SELECT 1")
    return {"status": "healthy", "service": "order-service"}


@router.get("/ready")
async def ready():
    return {"status": "ready"}


@router.get("/orders", response_model=list[Order])
async def list_orders(request: Request):
    sid = request.headers.get("X-Session-Id", "default")
    p = await get_pool()
    async with p.acquire() as conn:
        rows = await conn.fetch(
            "SELECT id, session_id, items, total, status, created_at, updated_at "
            "FROM orders WHERE session_id = $1 ORDER BY created_at DESC",
            sid,
        )
    return [_to_order(r) for r in rows]


@router.post("/orders", response_model=Order, status_code=201)
async def create_order(order_data: OrderCreate):
    total = sum(item.price * item.quantity for item in order_data.items)
    p = await get_pool()
    async with p.acquire() as conn:
        row = await conn.fetchrow(
            "INSERT INTO orders (session_id, items, total, status) "
            "VALUES ($1, $2::jsonb, $3, 'confirmed') "
            "RETURNING id, session_id, items, total, status, created_at, updated_at",
            order_data.session_id,
            json.dumps([item.model_dump(mode="json") for item in order_data.items]),
            total,
        )
    return _to_order(row)


@router.get("/orders/{order_id}", response_model=Order)
async def get_order(order_id: int):
    p = await get_pool()
    async with p.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, session_id, items, total, status, created_at, updated_at "
            "FROM orders WHERE id = $1",
            order_id,
        )
    if row is None:
        raise HTTPException(status_code=404, detail="Order not found")
    return _to_order(row)
