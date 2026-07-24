from fastapi.testclient import TestClient

from app import main


def test_health_is_independent_from_dependencies(monkeypatch) -> None:
    monkeypatch.setenv("RUN_WORKER", "false")
    with TestClient(main.app) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_readiness_reports_both_dependencies(monkeypatch) -> None:
    monkeypatch.setenv("RUN_WORKER", "false")
    monkeypatch.setattr(
        main,
        "check_postgres",
        lambda: {"database": "notifications_db", "role": "notifications_app"},
    )
    monkeypatch.setattr(main, "check_redis", lambda: {"ping": True})
    with TestClient(main.app) as client:
        response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["postgres"]["database"] == "notifications_db"


def test_readiness_hides_dependency_error(monkeypatch) -> None:
    monkeypatch.setenv("RUN_WORKER", "false")

    def unavailable() -> None:
        raise RuntimeError("secret connection detail")

    monkeypatch.setattr(main, "check_postgres", unavailable)
    with TestClient(main.app) as client:
        response = client.get("/ready")
    assert response.status_code == 503
    assert response.json() == {"detail": "Worker dependency unavailable"}
    assert "secret connection detail" not in response.text


def test_status_can_disable_loop_for_operations(monkeypatch) -> None:
    monkeypatch.setenv("RUN_WORKER", "false")
    with TestClient(main.app) as client:
        response = client.get("/status")
    assert response.status_code == 200
    assert response.json()["loop_enabled"] is False


def test_metrics_are_exposed(monkeypatch) -> None:
    monkeypatch.setenv("RUN_WORKER", "false")
    with TestClient(main.app) as client:
        response = client.get("/metrics")
    assert response.status_code == 200
    assert "asteria_service_info" in response.text
