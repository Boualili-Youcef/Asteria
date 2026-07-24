from fastapi.testclient import TestClient

from app import main


client = TestClient(main.app)


def test_health_is_independent_from_postgres() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"service": "identity-api", "status": "healthy"}


def test_readiness_reports_postgres(monkeypatch) -> None:
    monkeypatch.setattr(
        main,
        "check_postgres",
        lambda: {"database": "identity_db", "role": "identity_app"},
    )
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["postgres"]["database"] == "identity_db"


def test_readiness_hides_dependency_error(monkeypatch) -> None:
    def unavailable() -> None:
        raise RuntimeError("secret connection detail")

    monkeypatch.setattr(main, "check_postgres", unavailable)
    response = client.get("/ready")
    assert response.status_code == 503
    assert response.json() == {"detail": "PostgreSQL unavailable"}
    assert "secret connection detail" not in response.text


def test_create_user_delegates_to_database(monkeypatch) -> None:
    monkeypatch.setattr(
        main,
        "create_user",
        lambda email, display_name: {
            "id": "b6d6ac3d-bbaa-4b99-b2c5-590b2092d073",
            "email": email,
            "display_name": display_name,
        },
    )
    response = client.post(
        "/api/v1/users",
        json={"email": "user@example.test", "display_name": "Test User"},
    )
    assert response.status_code == 201
    assert response.json()["email"] == "user@example.test"


def test_metrics_are_exposed() -> None:
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "asteria_service_info" in response.text
