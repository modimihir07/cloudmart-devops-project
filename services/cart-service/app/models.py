from pydantic import BaseModel
from decimal import Decimal


class CartItem(BaseModel):
    product_id: int
    name: str
    price: Decimal
    quantity: int = 1


class CartItemResponse(BaseModel):
    product_id: int
    name: str
    price: Decimal
    quantity: int
    subtotal: Decimal
