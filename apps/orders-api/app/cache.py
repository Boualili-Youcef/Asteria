import json

from redis import Redis

from .config import RedisSettings


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


def publish_order_created(order: dict[str, object]) -> None:
    event = {
        "type": "order.created",
        "order_id": str(order["id"]),
        "customer_id": str(order["customer_id"]),
    }
    _client().rpush("asteria:notifications", json.dumps(event, sort_keys=True))
