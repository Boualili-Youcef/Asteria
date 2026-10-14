#!/usr/bin/env python3
"""Write one synthetic order only after checking the isolated demo target."""
import argparse
import base64
from contextlib import contextmanager
import datetime
import json
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.request
import uuid

from promote import ROOT, Target, validate_release


@contextmanager
def forward(target, resource, remote_port):
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    process = subprocess.Popen(target.k + ['port-forward', '--address=127.0.0.1',
        resource, f'{port}:{remote_port}'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for attempt in range(40):
            try:
                with socket.create_connection(('127.0.0.1', port), timeout=.5):
                    break
            except OSError:
                if process.poll() is not None:
                    raise RuntimeError('Private port-forward failed') from None
                time.sleep(.25)
        else:
            raise RuntimeError('Private port-forward unavailable')
        yield port
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def request(port, path, data=None):
    req = urllib.request.Request(f'http://127.0.0.1:{port}/{path}',
        data=json.dumps(data).encode() if data else None,
        headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=8) as response:
        return response.status, response.read().decode()


def read(target, kind, name):
    result = subprocess.run(target.k + ['get', kind, name, '-o', 'json'],
        capture_output=True, text=True, check=True, timeout=30)
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifact', type=Path)
    parser.add_argument('--context', required=True)
    parser.add_argument('--cluster-uid', required=True)
    parser.add_argument('--namespace-uid', required=True)
    parser.add_argument('--execute', action='store_true', help='write one approved synthetic order')
    parser.add_argument('--output', type=Path, required=True, help='new private evidence file outside Git')
    args = parser.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents or output.exists():
        raise ValueError('Evidence must be a new private file outside the repository')
    release = validate_release(json.loads(args.artifact.read_text()))
    target = Target(args.context, args.cluster_uid, args.namespace_uid)
    expected = release['image'] + '@' + release['digest']
    target.verify(expected)
    config = read(target, 'configmap', 'orders-demo-runtime')['data']
    if (config.get('POSTGRES_HOST') != 'demo-postgres'
            or config.get('POSTGRES_DATABASE') != 'demo' or config.get('REDIS_HOST') != 'demo-redis'):
        raise ValueError('Only the disposable demo data services are accepted')
    if not args.execute:
        print(json.dumps({'status': 'preview_only', 'business_writes': 0}))
        return
    # Reserve the evidence before writing. Raw exceptions/connection strings are never published.
    descriptor = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as evidence:
        report = {'schema': 1, 'date': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'environment': 'source-k3s-asteria-demo', 'status': 'failed', 'release': release,
                  'historical_data_accessed': False}
        start = time.monotonic()
        try:
            import psycopg
            data = read(target, 'secret', 'orders-demo-postgres')['data']
            user = base64.b64decode(data['POSTGRES_USER']).decode()
            password = base64.b64decode(data['POSTGRES_PASSWORD']).decode()
            if user != 'demo' or len(password) < 32:
                raise ValueError('Expected a dedicated synthetic database identity')
            with forward(target, 'service/orders-api', 8080) as orders, \
                 forward(target, 'service/demo-postgres', 5432) as postgres, \
                 forward(target, 'deployment/demo-notifications', 8080) as worker:
                for port in [orders, worker]:
                    if request(port, 'ready')[0] != 200:
                        raise RuntimeError('Demo dependency not ready')
                with psycopg.connect(host='127.0.0.1', port=postgres, dbname='demo', user=user,
                                      password=password, connect_timeout=5, autocommit=True) as conn:
                    assert conn.execute('SELECT current_database(), current_user').fetchone() == ('demo', 'demo')
                    status, body = request(orders, 'api/v1/orders',
                        {'customer_id': 'demo-' + uuid.uuid4().hex, 'amount': '12.50'})
                    if status != 201:
                        raise RuntimeError('Synthetic order creation failed')
                    order = str(uuid.UUID(json.loads(body)['id']))
                    if request(orders, 'api/v1/orders/' + order)[0] != 200:
                        raise RuntimeError('Synthetic order cannot be read')
                    for attempt in range(60):
                        archived = conn.execute("SELECT count(*) FROM processed_notifications WHERE payload->>'order_id'=%s", (order,)).fetchone()[0]
                        if archived == 1:
                            break
                        time.sleep(.5)
                    else:
                        raise RuntimeError('Matching notification was not archived')
                    persisted = conn.execute('SELECT count(*) FROM orders WHERE id=%s', (order,)).fetchone()[0]
                    if persisted != 1:
                        raise RuntimeError('Order persistence check failed')
                metrics = request(worker, 'metrics')[1]
                counters = [float(line.split()[1]) for line in metrics.splitlines()
                            if line.startswith('asteria_notifications_processed_total ')]
                if len(counters) != 1 or counters[0] < 1:
                    raise RuntimeError('Worker processing metric unavailable')
                report.update(status='passed', order_created_and_read=True, persisted_orders_for_id=persisted,
                    archived_notifications_for_id=archived, worker_processed_counter=counters[0])
        finally:
            report['duration_seconds'] = round(time.monotonic() - start, 3)
            json.dump(report, evidence, indent=2)
            evidence.write('\n')
    print(json.dumps(report))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('BLOCKED: ' + type(error).__name__ + '; inspect private operator evidence.', file=__import__('sys').stderr)
        raise SystemExit(1)
