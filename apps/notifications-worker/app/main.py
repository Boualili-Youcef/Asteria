import asyncio
from contextlib import asynccontextmanager, suppress
import os

from fastapi import FastAPI, HTTPException, Response, status
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Info, generate_latest

from .database import check_postgres
from .processor import check_redis, process_one

SERVICE_INFO = Info("asteria_service", "Asteria service identity")
SERVICE_INFO.info({"name": "notifications-worker", "version": "1.0.0"})
NOTIFICATIONS_PROCESSED = Counter(
    "asteria_notifications_processed_total",
    "Notifications archived by the worker",
)
DEPENDENCIES_READY = Gauge(
    "asteria_notifications_dependencies_ready",
    "Whether notifications-worker can query PostgreSQL and Redis",
)
WORKER_LOOP_RUNNING = Gauge(
    "asteria_notifications_worker_loop_running",
    "Whether the background consumption loop is running",
)


async def worker_loop() -> None:
    WORKER_LOOP_RUNNING.set(1)
    try:
        while True:
            try:
                processed = await asyncio.to_thread(process_one)
                if processed:
                    NOTIFICATIONS_PROCESSED.inc()
                DEPENDENCIES_READY.set(1)
            except asyncio.CancelledError:
                raise
            except Exception:
                DEPENDENCIES_READY.set(0)
                await asyncio.sleep(2)
    finally:
        WORKER_LOOP_RUNNING.set(0)


@asynccontextmanager
async def lifespan(_: FastAPI):
    task: asyncio.Task | None = None
    if os.getenv("RUN_WORKER", "true").lower() == "true":
        task = asyncio.create_task(worker_loop())
    yield
    if task is not None:
        task.cancel()
        with suppress(asyncio.CancelledError):
            await task


app = FastAPI(
    title="Asteria Notifications Worker",
    version="1.0.0",
    lifespan=lifespan,
)


@app.get("/")
def root() -> dict[str, str]:
    return {"service": "notifications-worker", "status": "running"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"service": "notifications-worker", "status": "healthy"}


@app.get("/ready")
def readiness() -> dict[str, object]:
    try:
        postgres = check_postgres()
        redis = check_redis()
    except Exception as exc:
        DEPENDENCIES_READY.set(0)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Worker dependency unavailable",
        ) from exc
    DEPENDENCIES_READY.set(1)
    return {
        "service": "notifications-worker",
        "status": "ready",
        "postgres": postgres,
        "redis": redis,
    }


@app.get("/status")
def worker_status() -> dict[str, object]:
    return {
        "service": "notifications-worker",
        "loop_enabled": os.getenv("RUN_WORKER", "true").lower() == "true",
    }


@app.get("/metrics", include_in_schema=False)
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
