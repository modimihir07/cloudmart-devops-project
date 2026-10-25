from unittest.mock import AsyncMock, MagicMock
from datetime import datetime, timezone
import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from app.main import app
import app.routes as routes_module


@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture(autouse=True)
def mock_db_pool(monkeypatch):
    mock_conn = AsyncMock()
    mock_conn.fetchval.return_value = 1

    sample_order = {
        "id": 1,
        "session_id": "test-session-123",
        "items": [
            {"product_id": 1, "name": "Headphones", "price": 79.99, "quantity": 1}
        ],
        "total": 79.99,
        "status": "confirmed",
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }

    mock_conn.fetch.return_value = [sample_order]
    mock_conn.fetchrow.return_value = sample_order

    mock_acquire = MagicMock()
    mock_acquire.__aenter__.return_value = mock_conn
    mock_acquire.__aexit__.return_value = None

    mock_pool = MagicMock()
    mock_pool.acquire.return_value = mock_acquire

    async def _mock_get_pool():
        return mock_pool

    monkeypatch.setattr(routes_module, "get_pool", _mock_get_pool)


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
    assert data["service"] == "order-service"


@pytest.mark.asyncio
async def test_metrics_endpoint(client):
    resp = await client.get("/metrics")
    assert resp.status_code == 200
    assert "http_requests_total" in resp.text


@pytest.mark.asyncio
async def test_order_routes(client):
    headers = {"X-Session-Id": "test-session-123"}

    # Test list orders (prefixed and unprefixed)
    resp = await client.get("/api/orders", headers=headers)
    assert resp.status_code == 200
    orders = resp.json()
    assert len(orders) == 1
    assert orders[0]["id"] == 1
    assert orders[0]["status"] == "confirmed"

    unprefixed = await client.get("/orders", headers=headers)
    assert unprefixed.status_code == 200
    assert len(unprefixed.json()) == 1

    # Test create order
    payload = {
        "session_id": "test-session-123",
        "items": [
            {"product_id": 1, "name": "Headphones", "price": 79.99, "quantity": 1}
        ],
    }
    create_resp = await client.post("/api/orders", json=payload, headers=headers)
    assert create_resp.status_code == 201
    assert create_resp.json()["id"] == 1

    # Test get order by id
    get_resp = await client.get("/api/orders/1")
    assert get_resp.status_code == 200
    assert get_resp.json()["id"] == 1
