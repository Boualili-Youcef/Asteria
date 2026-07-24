from uuid import UUID

from fastapi import FastAPI, HTTPException, Response, status
from pydantic import BaseModel, Field
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Info, generate_latest
from psycopg import IntegrityError

from .database import check_postgres, create_user, get_user

app = FastAPI(title="Asteria Identity API", version="1.0.0")

SERVICE_INFO = Info("asteria_service", "Asteria service identity")
SERVICE_INFO.info({"name": "identity-api", "version": "1.0.0"})
USERS_CREATED = Counter(
    "asteria_identity_users_created_total",
    "Users created by identity-api",
)
POSTGRES_READY = Gauge(
    "asteria_identity_postgres_ready",
    "Whether identity-api can query PostgreSQL",
)


class UserCreate(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    display_name: str = Field(min_length=1, max_length=120)


@app.get("/")
def root() -> dict[str, str]:
    return {"service": "identity-api", "status": "running"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"service": "identity-api", "status": "healthy"}


@app.get("/ready")
def readiness() -> dict[str, object]:
    try:
        dependency = check_postgres()
    except Exception as exc:
        POSTGRES_READY.set(0)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="PostgreSQL unavailable",
        ) from exc
    POSTGRES_READY.set(1)
    return {"service": "identity-api", "status": "ready", "postgres": dependency}


@app.post("/api/v1/users", status_code=status.HTTP_201_CREATED)
def post_user(payload: UserCreate) -> dict[str, object]:
    try:
        user = create_user(payload.email, payload.display_name)
    except IntegrityError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User email already exists",
        ) from exc
    USERS_CREATED.inc()
    return user


@app.get("/api/v1/users/{user_id}")
def read_user(user_id: UUID) -> dict[str, object]:
    user = get_user(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return user


@app.get("/metrics", include_in_schema=False)
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
