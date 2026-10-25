import time
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests handled by service",
    ["service", "method", "endpoint", "status"],
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["service", "method", "endpoint"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)


class PrometheusMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, service_name: str):
        super().__init__(app)
        self.service_name = service_name

    async def dispatch(self, request, call_next):
        if request.url.path == "/metrics":
            return await call_next(request)

        start_time = time.time()
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            return response
        except Exception:
            raise
        finally:
            duration = time.time() - start_time
            endpoint = request.url.path
            method = request.method
            REQUEST_COUNT.labels(
                service=self.service_name,
                method=method,
                endpoint=endpoint,
                status=str(status_code),
            ).inc()
            REQUEST_LATENCY.labels(
                service=self.service_name,
                method=method,
                endpoint=endpoint,
            ).observe(duration)


def setup_metrics(app, service_name: str):
    app.add_middleware(PrometheusMiddleware, service_name=service_name)

    @app.get("/metrics")
    async def metrics_endpoint():
        return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
