from fastapi import APIRouter, HTTPException, Request, Response, status
from app.models import CartItem, CartItemResponse
from app import redis_client

router = APIRouter()


def _session_id(request: Request) -> str:
    sid = request.cookies.get("session_id")
    if not sid:
        sid = request.headers.get("X-Session-Id", "default")
    return sid


@router.get("/health")
async def health():
    r = await redis_client.get_redis()
    await r.ping()
    return {"status": "healthy", "service": "cart-service"}


@router.get("/ready")
async def ready():
    return {"status": "ready"}


@router.get("/cart/items", response_model=list[CartItemResponse])
async def get_cart_items(request: Request):
    items = await redis_client.get_cart(_session_id(request))
    return [
        CartItemResponse(
            product_id=i["product_id"],
            name=i["name"],
            price=i["price"],
            quantity=i["quantity"],
            subtotal=float(i["price"]) * int(i["quantity"]),
        )
        for i in items
    ]


@router.post("/cart/items", response_model=list[CartItemResponse])
async def add_cart_item(request: Request, item: CartItem):
    items = await redis_client.add_item(
        _session_id(request), item.model_dump(mode="json")
    )
    return [
        CartItemResponse(
            product_id=i["product_id"],
            name=i["name"],
            price=i["price"],
            quantity=i["quantity"],
            subtotal=float(i["price"]) * int(i["quantity"]),
        )
        for i in items
    ]


@router.delete("/cart/items/{product_id}", response_model=list[CartItemResponse])
async def remove_cart_item(request: Request, product_id: int):
    sid = _session_id(request)
    existing_items = await redis_client.get_cart(sid)
    if not any(i["product_id"] == product_id for i in existing_items):
        raise HTTPException(status_code=404, detail="Product not found in cart")
    items = await redis_client.remove_item(sid, product_id)
    return [
        CartItemResponse(
            product_id=i["product_id"],
            name=i["name"],
            price=i["price"],
            quantity=i["quantity"],
            subtotal=float(i["price"]) * int(i["quantity"]),
        )
        for i in items
    ]


@router.delete("/cart", status_code=status.HTTP_204_NO_CONTENT)
@router.delete("/cart/items", status_code=status.HTTP_204_NO_CONTENT)
async def clear_cart_endpoint(request: Request):
    await redis_client.clear_cart(_session_id(request))
    return Response(status_code=status.HTTP_204_NO_CONTENT)
