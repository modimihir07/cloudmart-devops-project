from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://postgres:postgres@localhost:5432/products"
    service_name: str = "product-catalog"
    otel_exporter_otlp_endpoint: str = "http://otel-collector:4317"

    model_config = {"env_prefix": "PRODUCT_", "env_file": ".env"}


settings = Settings()
