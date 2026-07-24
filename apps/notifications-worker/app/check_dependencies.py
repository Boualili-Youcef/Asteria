import json

from .database import check_postgres
from .processor import check_redis


def main() -> None:
    result = {
        "service": "notifications-worker",
        "postgres": check_postgres(),
        "redis": check_redis(),
    }
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
