from decimal import Decimal
from fastapi.testclient import TestClient
from app import main


def test_invalid_order_never_writes_or_publishes(monkeypatch):
    def unexpected(*args):
        raise AssertionError('Invalid payload reached a dependency')
    monkeypatch.setattr(main, 'create_order', unexpected)
    monkeypatch.setattr(main, 'publish_order_created', unexpected)
    with TestClient(main.app) as client:
        for payload in [{'customer_id': '', 'amount': '1'},
                        {'customer_id': 'demo', 'amount': '-1'},
                        {'customer_id': 'demo', 'amount': '1.001'}]:
            assert client.post('/api/v1/orders', json=payload).status_code == 422


def test_missing_order_and_malformed_id(monkeypatch):
    monkeypatch.setattr(main, 'get_order', lambda _: None)
    with TestClient(main.app) as client:
        assert client.get('/api/v1/orders/00000000-0000-0000-0000-000000000001').status_code == 404
        assert client.get('/api/v1/orders/not-a-uuid').status_code == 422


def test_publish_failure_documents_existing_nontransactional_gap(monkeypatch):
    persisted = []
    def persist(customer_id, amount):
        order = {'id': 'synthetic', 'customer_id': customer_id, 'amount': Decimal(amount)}
        persisted.append(order)
        return order
    def unavailable(_):
        raise RuntimeError('Redis unavailable')
    monkeypatch.setattr(main, 'create_order', persist)
    monkeypatch.setattr(main, 'publish_order_created', unavailable)
    with TestClient(main.app, raise_server_exceptions=False) as client:
        assert client.post('/api/v1/orders', json={'customer_id': 'demo', 'amount': '1'}).status_code == 500
    assert len(persisted) == 1  # Existing ASIS-009: commit precedes publication.
