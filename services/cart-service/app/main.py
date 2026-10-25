from fastapi import FastAPI
from app.routes import router
from app.tracing import setup_tracing
from app.redis_client import close_redis
from app.metrics import setup_metrics
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

setup_tracing()

app = FastAPI(title="Cart Service", version="1.0.0")

# Setup Prometheus metrics endpoint and middleware
setup_metrics(app, service_name="cart-service")

# Register routes for both direct /cart and ingress /api/cart
app.include_router(router)
app.include_router(router, prefix="/api")

FastAPIInstrumentor.instrument_app(app)


@app.on_event("shutdown")
async def shutdown():
    await close_redis()
