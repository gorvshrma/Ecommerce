
import os
import socket
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest
from sqlalchemy import text
from sqlalchemy.orm import Session

from . import models, schemas
from .database import Base, SessionLocal, engine, get_db

APP_NAME = os.getenv("APP_NAME", "CloudCart API")
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
ENVIRONMENT = os.getenv("ENVIRONMENT", "local")
GIT_COMMIT = os.getenv("GIT_COMMIT", "unknown")
HOSTNAME = socket.gethostname()

HTTP_REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint"],
)
ORDERS_CREATED = Counter(
    "orders_created_total",
    "Total successfully created orders",
)

def seed_products():
    db = SessionLocal()
    try:
        if db.query(models.Product).count() == 0:
            db.add_all([
                models.Product(
                    name="DevOps Hoodie",
                    description="Cloud-native engineering hoodie",
                    price=1499,
                    stock=25,
                ),
                models.Product(
                    name="Kubernetes Mug",
                    description="Coffee mug for Kubernetes engineers",
                    price=499,
                    stock=50,
                ),
                models.Product(
                    name="Cloud Engineer Tee",
                    description="Minimal cloud engineering t-shirt",
                    price=899,
                    stock=40,
                ),
            ])
            db.commit()
    finally:
        db.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    seed_products()
    yield

app = FastAPI(
    title=APP_NAME,
    description="Backend API for the CloudCart 3-tier DevOps portfolio application.",
    version=APP_VERSION,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv(
        "CORS_ORIGINS",
        "http://localhost:3000,http://localhost:5173"
    ).split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    HTTP_REQUESTS.labels("GET", "/").inc()
    return {
        "application": APP_NAME,
        "version": APP_VERSION,
        "environment": ENVIRONMENT,
        "status": "running",
    }

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.get("/ready")
def ready(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ready", "database": "connected"}
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

@app.get("/info")
def info():
    return {
        "application": APP_NAME,
        "version": APP_VERSION,
        "environment": ENVIRONMENT,
        "git_commit": GIT_COMMIT,
        "hostname": HOSTNAME,
    }

@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/api/products", response_model=list[schemas.ProductResponse])
def list_products(db: Session = Depends(get_db)):
    HTTP_REQUESTS.labels("GET", "/api/products").inc()
    return db.query(models.Product).order_by(models.Product.id).all()

@app.get("/api/products/{product_id}", response_model=schemas.ProductResponse)
def get_product(product_id: int, db: Session = Depends(get_db)):
    product = db.get(models.Product, product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product

@app.post(
    "/api/products",
    response_model=schemas.ProductResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_product(payload: schemas.ProductCreate, db: Session = Depends(get_db)):
    product = models.Product(**payload.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product

@app.get("/api/orders", response_model=list[schemas.OrderResponse])
def list_orders(db: Session = Depends(get_db)):
    return db.query(models.Order).order_by(models.Order.id.desc()).all()

@app.post(
    "/api/orders",
    response_model=schemas.OrderResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_order(payload: schemas.OrderCreate, db: Session = Depends(get_db)):
    total = 0.0
    prepared_items = []

    for item in payload.items:
        product = db.get(models.Product, item.product_id)
        if not product:
            raise HTTPException(
                status_code=404,
                detail=f"Product {item.product_id} not found",
            )
        if product.stock < item.quantity:
            raise HTTPException(
                status_code=409,
                detail=f"Insufficient stock for {product.name}",
            )
        prepared_items.append((product, item.quantity))
        total += product.price * item.quantity

    order = models.Order(
        customer_name=payload.customer_name,
        customer_email=str(payload.customer_email),
        status="pending",
        total_amount=round(total, 2),
    )
    db.add(order)
    db.flush()

    for product, quantity in prepared_items:
        product.stock -= quantity
        db.add(models.OrderItem(
            order_id=order.id,
            product_id=product.id,
            quantity=quantity,
            unit_price=product.price,
        ))

    db.commit()
    db.refresh(order)
    ORDERS_CREATED.inc()
    return order

@app.patch("/api/orders/{order_id}/status")
def update_order_status(
    order_id: int,
    order_status: str,
    db: Session = Depends(get_db),
):
    allowed = {"pending", "processing", "shipped", "delivered", "cancelled"}
    if order_status not in allowed:
        raise HTTPException(status_code=400, detail="Invalid order status")

    order = db.get(models.Order, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    order.status = order_status
    db.commit()
    return {"id": order.id, "status": order.status}
