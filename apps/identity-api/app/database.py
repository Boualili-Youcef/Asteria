from uuid import UUID, uuid4

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
                CREATE TABLE IF NOT EXISTS users (
                    id uuid PRIMARY KEY,
                    email text UNIQUE NOT NULL,
                    display_name text NOT NULL,
                    created_at timestamptz NOT NULL DEFAULT now()
                )
                """
            )


def create_user(email: str, display_name: str) -> dict[str, object]:
    ensure_schema()
    user_id = uuid4()
    with _connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO users (id, email, display_name)
                VALUES (%s, %s, %s)
                RETURNING id, email, display_name, created_at
                """,
                (user_id, email, display_name),
            )
            row = cursor.fetchone()
    if row is None:
        raise RuntimeError("PostgreSQL did not return the created user")
    return dict(row)


def get_user(user_id: UUID) -> dict[str, object] | None:
    ensure_schema()
    with _connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, email, display_name, created_at
                FROM users
                WHERE id = %s
                """,
                (user_id,),
            )
            row = cursor.fetchone()
    return dict(row) if row else None
