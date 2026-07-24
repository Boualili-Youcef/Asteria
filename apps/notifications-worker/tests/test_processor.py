import json

from app import processor


class FakeRedis:
    def blpop(self, _queue: str, timeout: int):
        assert timeout == 1
        return ("asteria:notifications", json.dumps({"type": "order.created"}))


def test_process_one_archives_event(monkeypatch) -> None:
    archived: list[dict[str, object]] = []
    monkeypatch.setattr(processor, "_client", lambda: FakeRedis())
    monkeypatch.setattr(processor, "archive_notification", archived.append)

    assert processor.process_one() is True
    assert archived == [{"type": "order.created"}]
