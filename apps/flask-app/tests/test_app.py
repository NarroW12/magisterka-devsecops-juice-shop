"""Smoke tests for the Flask test harness."""

from app import app


def test_health():
    client = app.test_client()
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_products_returns_list():
    client = app.test_client()
    response = client.get("/products")
    assert response.status_code == 200
    data = response.get_json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert {"id", "name", "price"}.issubset(data[0].keys())


def test_login_invalid_credentials_returns_401():
    client = app.test_client()
    response = client.post(
        "/login",
        json={"username": "nope", "password": "nope"},
    )
    assert response.status_code == 401


def test_login_valid_credentials_returns_200():
    client = app.test_client()
    response = client.post(
        "/login",
        json={"username": "demo", "password": "demo-only-not-real-credential"},
    )
    assert response.status_code == 200
    assert response.get_json()["username"] == "demo"
