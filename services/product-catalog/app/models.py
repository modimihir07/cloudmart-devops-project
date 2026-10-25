from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime


class Product(BaseModel):
    id: int
    name: str
    description: str
    price: Decimal
    created_at: datetime | None = None


class ProductCreate(BaseModel):
    name: str
    description: str = ""
    price: Decimal
