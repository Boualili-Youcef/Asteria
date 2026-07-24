import json
from uuid import uuid4

import psycopg
from psycopg.rows import dict_row

from .config import PostgresSettings


def _connect() -> psycopg.Connection:
    settings = PostgresSettings.from_env()
    return psycopg.connect(
        host=settings.host,
        port=settings.port,
        dbname=settings.database,
        user=settings.user,
        password=settings.password,
        connect_timeout=settings.connect_timeout,
        row_factory=dict_row,
    )


def check_postgres() -> dict[str, str]:
    with _connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT current_database() AS database, current_user AS role"
            )
            row = cursor.fetchone()
    if row is None:
        raise RuntimeError("PostgreSQL returned no readiness row")
    return {"database": str(row["database"]), "role": str(row["role"])}


def ensure_schema() -> None:
    with _connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS processed_notifications (
                    id uuid PRIMARY KEY,
                    event_type text NOT NULL,
                    payload jsonb NOT NULL,
                    processed_at timestamptz NOT NULL DEFAULT now()
                )
                """
            )


def archive_notification(event: dict[str, object]) -> None:
    ensure_schema()
    with _connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO processed_notifications (id, event_type, payload)
                VALUES (%s, %s, %s::jsonb)
                """,
                (
                    uuid4(),
                    str(event.get("type", "unknown")),
                    json.dumps(event, sort_keys=True),
                ),
            )
