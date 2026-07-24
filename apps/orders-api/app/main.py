from decimal import Decimal
from uuid import UUID

from fastapi import FastAPI, HTTPException, Response, status
from pydantic import BaseModel, Field
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Info, generate_latest

from .cache import check_redis, publish_order_created
from .database import check_postgres, create_order, get_order

app = FastAPI(title="Asteria Orders API", version="1.0.0")

SERVICE_INFO = Info("asteria_service", "Asteria service identity")
SERVICE_INFO.info({"name": "orders-api", "version": "1.0.0"})
ORDERS_CREATED = Counter(
    "asteria_orders_created_total",
    "Orders persisted by orders-api",
)
DEPENDENCIES_READY = Gauge(
    "asteria_orders_dependencies_ready",
    "Whether orders-api can query PostgreSQL and Redis",
)


class OrderCreate(BaseModel):
    customer_id: str = Field(min_length=1, max_length=120)
    amount: Decimal = Field(ge=0, max_digits=12, decimal_places=2)


@app.get("/")
def root() -> dict[str, str]:
    return {"service": "orders-api", "status": "running"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"service": "orders-api", "status": "healthy"}


@app.get("/ready")
def readiness() -> dict[str, object]:
    try:
        postgres = check_postgres()
        redis = check_redis()
    except Exception as exc:
        DEPENDENCIES_READY.set(0)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Application dependency unavailable",
        ) from exc
    DEPENDENCIES_READY.set(1)
    return {
        "service": "orders-api",
        "status": "ready",
        "postgres": postgres,
        "redis": redis,
    }


@app.post("/api/v1/orders", status_code=status.HTTP_201_CREATED)
def post_order(payload: OrderCreate) -> dict[str, object]:
    order = create_order(payload.customer_id, payload.amount)
    publish_order_created(order)
    ORDERS_CREATED.inc()
    return order


@app.get("/api/v1/orders/{order_id}")
def read_order(order_id: UUID) -> dict[str, object]:
    order = get_order(order_id)
    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )
    return order


@app.get("/metrics", include_in_schema=False)
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
