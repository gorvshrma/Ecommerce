
import os
os.environ["DATABASE_URL"] = "sqlite:///./test.db"

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from src.database import Base, get_db
from src.main import app
from src import models

TEST_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
)
TestingSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)

def setup_function():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    db = TestingSessionLocal()
    db.add(models.Product(
        name="Test Product",
        description="Test product",
        price=100.0,
        stock=10,
    ))
    db.commit()
    db.close()

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_products():
    response = client.get("/api/products")
    assert response.status_code == 200
    assert len(response.json()) == 1

def test_create_order():
    response = client.post("/api/orders", json={
        "customer_name": "Demo User",
        "customer_email": "demo@example.com",
        "items": [{"product_id": 1, "quantity": 2}],
    })
    assert response.status_code == 201
    assert response.json()["total_amount"] == 200.0
    assert response.json()["status"] == "pending"

def test_insufficient_stock():
    response = client.post("/api/orders", json={
        "customer_name": "Demo User",
        "customer_email": "demo@example.com",
        "items": [{"product_id": 1, "quantity": 100}],
    })
    assert response.status_code == 409
