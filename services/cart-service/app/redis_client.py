import json
import redis.asyncio as aioredis
from app.config import settings

_redis: aioredis.Redis | None = None


async def get_redis() -> aioredis.Redis:
    global _redis
    if _redis is None:
        _redis = aioredis.from_url(
            settings.redis_url, decode_responses=True, max_connections=10
        )
    return _redis


async def close_redis():
    global _redis
    if _redis:
        await _redis.close()
        _redis = None


async def get_cart(session_id: str) -> list[dict]:
    r = await get_redis()
    data = await r.get(f"cart:{session_id}")
    return json.loads(data) if data else []


async def set_cart(session_id: str, items: list[dict]):
    r = await get_redis()
    await r.setex(f"cart:{session_id}", 86400, json.dumps(items))


async def add_item(session_id: str, item: dict):
    items = await get_cart(session_id)
    for existing in items:
        if existing["product_id"] == item["product_id"]:
            existing["quantity"] += item.get("quantity", 1)
            await set_cart(session_id, items)
            return items
    items.append(item)
    await set_cart(session_id, items)
    return items


async def remove_item(session_id: str, product_id: int):
    items = await get_cart(session_id)
    items = [i for i in items if i["product_id"] != product_id]
    await set_cart(session_id, items)
    return items


async def clear_cart(session_id: str):
    r = await get_redis()
    await r.delete(f"cart:{session_id}")
