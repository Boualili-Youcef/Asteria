import json

from .cache import check_redis
from .database import check_postgres


def main() -> None:
    result = {
        "service": "orders-api",
        "postgres": check_postgres(),
        "redis": check_redis(),
    }
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
