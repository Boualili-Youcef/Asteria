"""Local-only BFF. Fixed upstreams, read-only DB role, no Docker socket or shell."""
from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.request
from uuid import UUID

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
import psycopg
from psycopg.rows import dict_row

app = FastAPI(title="Asteria Local Docker Playground", docs_url=None, redoc_url=None, openapi_url=None)
WEB = Path(__file__).parent / "web"


@app.middleware("http")
async def localhost_boundary(request: Request, call_next):
    # Host and Origin checks block browser-driven requests from unrelated websites.
    if request.headers.get("host") not in {"127.0.0.1:4180", "localhost:4180", "127.0.0.1:8080"}:
        from fastapi.responses import JSONResponse
        return JSONResponse({"detail": "Localhost only"}, status_code=403)
    origin = request.headers.get("origin")
    if origin and origin not in {"http://127.0.0.1:4180", "http://localhost:4180"}:
        from fastapi.responses import JSONResponse
        return JSONResponse({"detail": "Origin refused"}, status_code=403)
    result = await call_next(request)
    result.headers["Cache-Control"] = "no-store"
    result.headers["X-Content-Type-Options"] = "nosniff"
    result.headers["Content-Security-Policy"] = "default-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"
    return result


def upstream(service: str, path: str, payload=None):
    if service not in {"orders", "worker"}:
        raise ValueError("Unlisted service")
    request = urllib.request.Request(
        f"http://{service}:8080{path}",
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, {"detail": "Application request rejected"}
    except (urllib.error.URLError, TimeoutError):
        return 503, {"detail": "Application unavailable"}


def read_database():
    with psycopg.connect(
        host=os.environ["POSTGRES_HOST"], dbname=os.environ["POSTGRES_DATABASE"],
        user=os.environ["POSTGRES_USER"], password=os.environ["POSTGRES_PASSWORD"],
        connect_timeout=2, options="-c default_transaction_read_only=on", row_factory=dict_row,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT to_regclass('public.orders') AS orders, to_regclass('public.processed_notifications') AS archives")
            tables = cursor.fetchone()
            count = 0
            archives = []
            orders = []
            if tables["orders"]:
                cursor.execute("SELECT count(*) AS count FROM orders")
                count = cursor.fetchone()["count"]
                cursor.execute("SELECT id, amount, created_at FROM orders ORDER BY created_at DESC LIMIT 20")
                orders = [{"id": str(row["id"]), "amount": str(row["amount"]), "created_at": row["created_at"].isoformat()} for row in cursor.fetchall()]
            archive_count = 0
            if tables["archives"]:
                cursor.execute("SELECT count(*) AS count FROM processed_notifications")
                archive_count = cursor.fetchone()["count"]
                cursor.execute("SELECT payload, processed_at FROM processed_notifications ORDER BY processed_at DESC LIMIT 20")
                archives = [{"order_id": row["payload"].get("order_id"), "type": row["payload"].get("type"), "processed_at": row["processed_at"].isoformat()} for row in cursor.fetchall()]
            return {"orders_count": count, "archives_count": archive_count, "orders": orders, "archives": archives}


@app.get("/api/health")
def health():
    return {"mode": "local-docker-live", "bff": "healthy"}


@app.get("/api/snapshot")
def snapshot():
    def probe(pair):
        service, endpoint = pair
        code, _ = upstream(service, "/" + endpoint)
        return service, endpoint, code
    with ThreadPoolExecutor(max_workers=4) as executor:
        probes = list(executor.map(probe, [(s, e) for s in ("orders", "worker") for e in ("health", "ready")]))
    status = {s: {} for s in ("orders", "worker")}
    for service, endpoint, code in probes:
        status[service][endpoint] = code
    try:
        db = read_database()
    except psycopg.Error as error:
        raise HTTPException(503, "Local database unavailable") from error
    return {"mode": "local-docker-live", "observed_at": time.time(), "services": status, **db}


class OrderInput(BaseModel):
    amount: Decimal = Field(ge=0, max_digits=12, decimal_places=2)


@app.post("/api/orders", status_code=201)
def create_order(payload: OrderInput):
    start = time.perf_counter()
    code, result = upstream("orders", "/api/v1/orders", {"customer_id": "playground-synthetic", "amount": str(payload.amount)})
    if code != 201:
        raise HTTPException(code, "Orders unavailable. A DB commit may already exist: inspect the counters before retrying.")
    return {"order": result, "api_duration_ms": round((time.perf_counter()-start)*1000, 3)}


@app.get("/api/orders/{order_id}")
def get_order(order_id: UUID):
    code, result = upstream("orders", f"/api/v1/orders/{order_id}")
    if code != 200:
        raise HTTPException(code, "Order unavailable")
    return result


@app.get("/")
def index():
    return FileResponse(WEB / "index.html")


app.mount("/assets", StaticFiles(directory=WEB), name="assets")
