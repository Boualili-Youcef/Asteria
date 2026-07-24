import json

from redis import Redis

from .config import RedisSettings
from .database import archive_notification


def _client() -> Redis:
    settings = RedisSettings.from_env()
    return Redis(
        host=settings.host,
        port=settings.port,
        socket_connect_timeout=settings.connect_timeout,
        socket_timeout=settings.connect_timeout,
        decode_responses=True,
    )


def check_redis() -> dict[str, object]:
    return {"ping": bool(_client().ping())}


def process_one(timeout: int = 1) -> bool:
    message = _client().blpop("asteria:notifications", timeout=timeout)
    if message is None:
        return False
    _, raw_event = message
    event = json.loads(raw_event)
    if not isinstance(event, dict):
        raise ValueError("Notification event must be a JSON object")
    archive_notification(event)
    return True
