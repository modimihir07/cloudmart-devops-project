import logging
from fastapi import FastAPI
from app.routes import router
from app.tracing import setup_tracing
from app.database import init_db, create_pool
from app.metrics import setup_metrics
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

logger = logging.getLogger("order-service")

setup_tracing()

app = FastAPI(title="Order Service", version="1.0.0")

# Setup Prometheus metrics endpoint and middleware
setup_metrics(app, service_name="order-service")

# Register routes for both direct /orders and ingress /api/orders
app.include_router(router)
app.include_router(router, prefix="/api")

FastAPIInstrumentor.instrument_app(app)


@app.on_event("startup")
async def startup():
    try:
        pool = await create_pool()
        await init_db(pool)
        await pool.close()
    except Exception as exc:
        logger.warning("Database initialization skipped or delayed on startup: %s", exc)


@app.on_event("shutdown")
async def shutdown():
    from app.routes import get_pool

    p = await get_pool()
    if p:
        await p.close()
