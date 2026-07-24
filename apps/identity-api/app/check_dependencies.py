import json

from .database import check_postgres


def main() -> None:
    result = check_postgres()
    print(json.dumps({"service": "identity-api", "postgres": result}, sort_keys=True))


if __name__ == "__main__":
    main()
