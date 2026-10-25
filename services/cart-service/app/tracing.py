import os
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from app.config import settings


def setup_tracing():
    if os.environ.get("OTEL_SDK_DISABLED", "").lower() in ("true", "1"):
        return trace.get_tracer(settings.service_name)
    try:
        resource = Resource.create({"service.name": settings.service_name})
        provider = TracerProvider(resource=resource)
        exporter = OTLPSpanExporter(
            endpoint=settings.otel_exporter_otlp_endpoint, insecure=True
        )
        processor = BatchSpanProcessor(exporter)
        provider.add_span_processor(processor)
        trace.set_tracer_provider(provider)
        return trace.get_tracer(settings.service_name)
    except Exception:
        return trace.get_tracer(settings.service_name)
