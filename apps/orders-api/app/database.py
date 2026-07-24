from decimal import Decimal
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
                CREATE TABLE IF NOT EXISTS orders (
                    id uuid PRIMARY KEY,
                    customer_id text NOT NULL,
                    amount numeric(12, 2) NOT NULL CHECK (amount >= 0),
                    status text NOT NULL,
                    created_at timestamptz NOT NULL DEFAULT now()
                )
                """
            )


def create_order(customer_id: str, amount: Decimal) -> dict[str, object]:
    ensure_schema()
    order_id = uuid4()
    with _connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO orders (id, customer_id, amount, status)
                VALUES (%s, %s, %s, 'created')
                RETURNING id, customer_id, amount, status, created_at
                """,
                (order_id, customer_id, amount),
            )
            row = cursor.fetchone()
    if row is None:
        raise RuntimeError("PostgreSQL did not return the created order")
    return dict(row)


def get_order(order_id: UUID) -> dict[str, object] | None:
    ensure_schema()
    with _connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, customer_id, amount, status, created_at
                FROM orders
                WHERE id = %s
                """,
                (order_id,),
            )
            row = cursor.fetchone()
    return dict(row) if row else None
