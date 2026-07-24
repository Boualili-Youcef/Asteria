from decimal import Decimal

from fastapi.testclient import TestClient

from app import main


client = TestClient(main.app)


def test_health_is_independent_from_dependencies() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_readiness_reports_both_dependencies(monkeypatch) -> None:
    monkeypatch.setattr(
        main,
        "check_postgres",
        lambda: {"database": "orders_db", "role": "orders_app"},
    )
    monkeypatch.setattr(main, "check_redis", lambda: {"ping": True})
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["redis"] == {"ping": True}


def test_readiness_hides_dependency_error(monkeypatch) -> None:
    def unavailable() -> None:
        raise RuntimeError("secret connection detail")

    monkeypatch.setattr(main, "check_postgres", unavailable)
    response = client.get("/ready")
    assert response.status_code == 503
    assert response.json() == {"detail": "Application dependency unavailable"}
    assert "secret connection detail" not in response.text


def test_create_order_persists_and_publishes(monkeypatch) -> None:
    created = {
        "id": "3cab4258-7768-44f8-aea1-395d5206d50f",
        "customer_id": "customer-1",
        "amount": Decimal("12.50"),
        "status": "created",
    }
    published: list[dict[str, object]] = []
    monkeypatch.setattr(main, "create_order", lambda customer_id, amount: created)
    monkeypatch.setattr(main, "publish_order_created", published.append)

    response = client.post(
        "/api/v1/orders",
        json={"customer_id": "customer-1", "amount": "12.50"},
    )
    assert response.status_code == 201
    assert response.json()["status"] == "created"
    assert published == [created]


def test_metrics_are_exposed() -> None:
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "asteria_service_info" in response.text
