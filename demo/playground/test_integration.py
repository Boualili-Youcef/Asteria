#!/usr/bin/env python3
"""Exercise only the asteria-playground Compose project, never Kubernetes."""
import json
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request
from uuid import UUID

ROOT = Path(__file__).parent
BASE = "http://127.0.0.1:4180"


def request(path, payload=None, origin=None):
    headers = {"Content-Type": "application/json"}
    if origin:
        headers["Origin"] = origin
    req = urllib.request.Request(BASE+path, data=json.dumps(payload).encode() if payload is not None else None, headers=headers)
    with urllib.request.urlopen(req, timeout=12) as response:
        return json.load(response)


def compose(*args):
    return subprocess.check_output(["docker", "compose", "--project-name", "asteria-playground", *args], cwd=ROOT, text=True)


def wait_for(predicate, timeout=35):
    end = time.monotonic()+timeout
    while time.monotonic()<end:
        value = request("/api/snapshot")
        if predicate(value):
            return value
        time.sleep(0.5)
    raise AssertionError("Local observation timed out")


def order_and_archive():
    result = request("/api/orders", {"amount": "42.10"})
    order_id = str(UUID(result["order"]["id"]))
    assert request("/api/orders/"+order_id)["id"] == order_id
    wait_for(lambda s: any(a["order_id"]==order_id for a in s["archives"]))
    sql = f"SELECT (SELECT count(*) FROM orders WHERE id='{order_id}') || ':' || (SELECT count(*) FROM processed_notifications WHERE payload->>'order_id'='{order_id}');"
    assert compose("exec", "-T", "postgres", "psql", "-U", "postgres", "-d", "playground", "-tAc", sql).strip() == "1:1"
    return order_id


def main():
    assert request("/api/health")["mode"]=="local-docker-live"
    before=request("/api/snapshot")
    first=order_and_archive()
    try:
        compose("stop", "redis")
        unavailable=wait_for(lambda s: s["services"]["orders"]["ready"]==503)
        assert unavailable["services"]["orders"]["health"]==200
        assert unavailable["services"]["worker"]["ready"]==503
    finally:
        compose("start", "redis")
    wait_for(lambda s:s["services"]["orders"]["ready"]==200 and s["services"]["worker"]["ready"]==200)
    second=order_and_archive()
    after=request("/api/snapshot")
    assert after["orders_count"]==before["orders_count"]+2
    assert after["archives_count"]==before["archives_count"]+2
    for path, payload, origin in [("/api/orders", {"amount": "-1"}, None), ("/api/orders/not-a-uuid", None, None), ("/api/orders", {"amount": "1.00"}, "https://unrelated.example")]:
        try:
            request(path,payload,origin)
            raise AssertionError("Expected request rejection")
        except urllib.error.HTTPError as error:
            assert error.code in {403,422}
    config=json.loads(compose("config", "--format", "json"))
    assert all(not s.get("ports") for name,s in config["services"].items() if name!="console")
    assert config["services"]["console"]["ports"][0]["host_ip"]=="127.0.0.1"
    # A real independent reader role must be unable to mutate the application tables.
    check = subprocess.run(["docker","compose","exec","-T","postgres","psql","-U","postgres","-d","playground","-v","ON_ERROR_STOP=1","-c","SET ROLE asteria_reader; DELETE FROM orders WHERE false;"],cwd=ROOT,capture_output=True,text=True)
    assert check.returncode!=0 and "permission denied" in check.stderr
    print(json.dumps({"mode":"local-docker-live","status":"passed","orders_created":2,"matching_sql_archives":2,"redis_down":{"health":200,"ready":503},"redis_recovered":True,"read_only_role_refused_write":True,"origin_rejected":True,"data_ports_unpublished":True,"synthetic_ids":[first,second]},indent=2))


if __name__ == "__main__":
    main()
