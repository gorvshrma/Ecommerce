
from datetime import datetime
from pydantic import BaseModel, ConfigDict, EmailStr, Field

class ProductCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    description: str = Field(default="", max_length=1000)
    price: float = Field(gt=0)
    stock: int = Field(ge=0)

class ProductResponse(ProductCreate):
    id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class OrderItemCreate(BaseModel):
    product_id: int
    quantity: int = Field(gt=0, le=100)

class OrderCreate(BaseModel):
    customer_name: str = Field(min_length=2, max_length=120)
    customer_email: EmailStr
    items: list[OrderItemCreate] = Field(min_length=1)

class OrderItemResponse(BaseModel):
    product_id: int
    quantity: int
    unit_price: float
    model_config = ConfigDict(from_attributes=True)

class OrderResponse(BaseModel):
    id: int
    customer_name: str
    customer_email: str
    status: str
    total_amount: float
    created_at: datetime
    items: list[OrderItemResponse]
    model_config = ConfigDict(from_attributes=True)
