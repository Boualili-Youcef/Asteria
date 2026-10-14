import json

from redis import Redis
from redis.backoff import NoBackoff
from redis.retry import Retry

from .config import RedisSettings


def _client(*, readiness: bool = False) -> Redis:
    settings = RedisSettings.from_env()
    return Redis(
        host=settings.host,
        port=settings.port,
        socket_connect_timeout=settings.connect_timeout,
        socket_timeout=settings.connect_timeout,
        decode_responses=True,
        **({'retry': Retry(NoBackoff(), 0)} if readiness else {}),
    )


def check_redis() -> dict[str, object]:
    return {"ping": bool(_client(readiness=True).ping())}


def publish_order_created(order: dict[str, object]) -> None:
    event = {
        "type": "order.created",
        "order_id": str(order["id"]),
        "customer_id": str(order["customer_id"]),
    }
    _client().rpush("asteria:notifications", json.dumps(event, sort_keys=True))
