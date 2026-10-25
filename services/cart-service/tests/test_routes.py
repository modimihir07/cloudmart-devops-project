from unittest.mock import AsyncMock
import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from app.main import app
import app.routes as routes_module
import app.redis_client as redis_module


@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture(autouse=True)
def mock_redis_storage(monkeypatch):
    storage = {}

    mock_redis = AsyncMock()

    async def _mock_get(key):
        return storage.get(key)

    async def _mock_setex(key, time, value):
        storage[key] = value

    async def _mock_delete(key):
        storage.pop(key, None)

    async def _mock_ping():
        return True

    mock_redis.get.side_effect = _mock_get
    mock_redis.setex.side_effect = _mock_setex
    mock_redis.delete.side_effect = _mock_delete
    mock_redis.ping.side_effect = _mock_ping

    async def _get_mock_redis():
        return mock_redis

    monkeypatch.setattr(redis_module, "get_redis", _get_mock_redis)


@pytest.mark.asyncio
async def test_ready_endpoint(client):
    resp = await client.get("/ready")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ready"


@pytest.mark.asyncio
async def test_health_endpoint(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "healthy"
    assert data["service"] == "cart-service"


@pytest.mark.asyncio
async def test_metrics_endpoint(client):
    resp = await client.get("/metrics")
    assert resp.status_code == 200
    assert "http_requests_total" in resp.text


@pytest.mark.asyncio
async def test_cart_operations(client):
    headers = {"X-Session-Id": "test-session-123"}

    # Initially empty
    resp = await client.get("/api/cart/items", headers=headers)
    assert resp.status_code == 200
    assert resp.json() == []

    # Add item
    item_payload = {
        "product_id": 1,
        "name": "Headphones",
        "price": 79.99,
        "quantity": 2,
    }
    add_resp = await client.post("/api/cart/items", json=item_payload, headers=headers)
    assert add_resp.status_code == 200
    items = add_resp.json()
    assert len(items) == 1
    assert items[0]["product_id"] == 1
    assert items[0]["quantity"] == 2
    assert float(items[0]["subtotal"]) == 159.98

    # Test unprefixed route works too
    unprefixed_resp = await client.get("/cart/items", headers=headers)
    assert unprefixed_resp.status_code == 200
    assert len(unprefixed_resp.json()) == 1

    # Remove item
    del_resp = await client.delete("/api/cart/items/1", headers=headers)
    assert del_resp.status_code == 200
    assert del_resp.json() == []

    # Delete non-existent item returns 404
    del_missing = await client.delete("/api/cart/items/999", headers=headers)
    assert del_missing.status_code == 404

    # Clear cart endpoint
    clear_resp = await client.delete("/api/cart", headers=headers)
    assert clear_resp.status_code == 204
