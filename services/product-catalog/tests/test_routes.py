from unittest.mock import AsyncMock, MagicMock
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
    mock_conn.fetch.return_value = [
        {
            "id": 1,
            "name": "Headphones",
            "description": "Noise-cancelling",
            "price": 79.99,
            "created_at": None,
        }
    ]
    mock_conn.fetchrow.return_value = {
        "id": 1,
        "name": "Headphones",
        "description": "Noise-cancelling",
        "price": 79.99,
        "created_at": None,
    }

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
    assert data["service"] == "product-catalog"


@pytest.mark.asyncio
async def test_metrics_endpoint(client):
    resp = await client.get("/metrics")
    assert resp.status_code == 200
    assert "http_requests_total" in resp.text


@pytest.mark.asyncio
async def test_list_products_routes(client):
    # Test unprefixed route
    resp = await client.get("/products")
    assert resp.status_code == 200
    products = resp.json()
    assert len(products) == 1
    assert products[0]["name"] == "Headphones"

    # Test /api prefixed route
    api_resp = await client.get("/api/products")
    assert api_resp.status_code == 200
    assert api_resp.json()[0]["name"] == "Headphones"


@pytest.mark.asyncio
async def test_get_product_detail(client):
    resp = await client.get("/api/products/1")
    assert resp.status_code == 200
    assert resp.json()["id"] == 1
