from pydantic import BaseModel, Field
from decimal import Decimal
from datetime import datetime


class OrderItem(BaseModel):
    product_id: int
    name: str
    price: Decimal
    quantity: int


class OrderCreate(BaseModel):
    session_id: str = Field(default="default")
    items: list[OrderItem]


class Order(BaseModel):
    id: int
    session_id: str
    items: list
    total: Decimal
    status: str
    created_at: datetime | None = None
    updated_at: datetime | None = None
