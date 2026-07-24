from dataclasses import dataclass
import os


class ConfigurationError(RuntimeError):
    """Raised when a required runtime variable is absent."""


def _required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise ConfigurationError(f"{name} is required")
    return value


@dataclass(frozen=True)
class PostgresSettings:
    host: str
    port: int
    database: str
    user: str
    password: str
    connect_timeout: int = 3

    @classmethod
    def from_env(cls) -> "PostgresSettings":
        return cls(
            host=_required("POSTGRES_HOST"),
            port=int(os.getenv("POSTGRES_PORT", "5432")),
            database=_required("POSTGRES_DATABASE"),
            user=_required("POSTGRES_USER"),
            password=_required("POSTGRES_PASSWORD"),
            connect_timeout=int(os.getenv("POSTGRES_CONNECT_TIMEOUT", "3")),
        )


@dataclass(frozen=True)
class RedisSettings:
    host: str
    port: int
    connect_timeout: int = 3

    @classmethod
    def from_env(cls) -> "RedisSettings":
        return cls(
            host=_required("REDIS_HOST"),
            port=int(os.getenv("REDIS_PORT", "6379")),
            connect_timeout=int(os.getenv("REDIS_CONNECT_TIMEOUT", "3")),
        )
