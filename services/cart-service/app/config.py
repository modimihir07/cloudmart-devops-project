from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    redis_url: str = "redis://localhost:6379/0"
    service_name: str = "cart-service"
    otel_exporter_otlp_endpoint: str = "http://otel-collector:4317"

    model_config = {"env_prefix": "CART_", "env_file": ".env"}


settings = Settings()
