#!/usr/bin/env python3
"""Exercise real Orders/Redis/Worker/PostgreSQL in disposable local Docker containers."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).absolute().parents[2]


def docker(*args, env=None):
    result = subprocess.run(['docker', *args], capture_output=True, text=True,
                            env=env, timeout=90)
    if result.returncode:
        raise RuntimeError('Docker operation failed: ' + args[0])
    return result.stdout.strip()


def request(port, path, data=None):
    req = urllib.request.Request(f'http://127.0.0.1:{port}/{path}',
            data=json.dumps(data).encode() if data is not None else None,
            headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()


def until(predicate, seconds=50):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        try:
            if predicate():
                return
        except (OSError, RuntimeError):
            pass
        time.sleep(.5)
    raise RuntimeError('Timed out waiting for the synthetic test')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--postgres-image', required=True, help='locally available repo@sha256 digest')
    parser.add_argument('--redis-image', required=True, help='locally available repo@sha256 digest or image ID')
    parser.add_argument('--orders-image', default='asteria/orders-api:m13')
    parser.add_argument('--worker-image', default='asteria/notifications-worker:m13')
    parser.add_argument('--output', required=True, type=Path, help='new evidence JSON file')
    args = parser.parse_args()
    for image in [args.postgres_image, args.redis_image]:
        if not re.fullmatch(r'(?:[a-z0-9./:_-]+@)?sha256:[a-f0-9]{64}', image):
            raise ValueError('Infrastructure images must be pinned by digest')
    if args.output.exists():
        raise ValueError('Evidence file already exists')
    identifier = 'asteria-e2e-' + uuid.uuid4().hex[:12]
    containers = []
    network = None
    start = time.monotonic()
    report = {'schema': 1, 'environment': 'local-docker',
              'date': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'cloud_mutations': False, 'kubernetes_rollback': 'not_tested', 'status': 'failed', 'checks': []}
    try:
        image_ids = {}
        # Check that reused M13 application images contain the exact repository Python sources.
        for app, image in [('orders-api', args.orders_image), ('notifications-worker', args.worker_image)]:
            image_ids[app] = json.loads(docker('image', 'inspect', image))[0]['Id']
            container = docker('create', '--label', 'asteria.test=' + identifier, image_ids[app])
            containers.append(container)
            with tempfile.TemporaryDirectory() as directory:
                docker('cp', container + ':/app/app', directory)
                for source in (ROOT / 'apps' / app / 'app').glob('*.py'):
                    copied = Path(directory) / 'app' / source.name
                    if hashlib.sha256(source.read_bytes()).digest() != hashlib.sha256(copied.read_bytes()).digest():
                        raise ValueError('Cached application image differs from source: ' + app)
        report['application_image_ids'] = image_ids
        report['source_files_match_images'] = True
        report['postgres_image'] = args.postgres_image
        report['redis_image'] = args.redis_image
        # A dedicated bridge supports host-loopback API publishing. No database
        # or Redis port is published; this network does not claim egress filtering.
        network = docker('network', 'create', '--label', 'asteria.test=' + identifier, identifier)
        password = secrets.token_urlsafe(24)
        env = {**os.environ, 'POSTGRES_PASSWORD': password}

        def launch(name, image, variables=(), port=False, memory='256m'):
            command = ['run', '-d', '--name', identifier + '-' + name,
                       '--label', 'asteria.test=' + identifier, '--network', identifier,
                       '--network-alias', name, '--memory', memory, '--cpus', '.5']
            if port:
                command += ['-p', '127.0.0.1::8080']
            for value in variables:
                command += ['-e', value]
            container = docker(*command, image, env=env)
            containers.append(container)
            return container

        pg = launch('postgres', args.postgres_image,
                    ['POSTGRES_USER=demo', 'POSTGRES_DB=demo', 'POSTGRES_PASSWORD'])
        redis = launch('redis', args.redis_image, memory='128m')
        until(lambda: 'accepting connections' in docker('exec', pg, 'pg_isready', '-U', 'demo'))
        until(lambda: docker('exec', redis, 'redis-cli', 'ping') == 'PONG')
        env['POSTGRES_HOST'] = 'postgres'
        variables = ['POSTGRES_HOST=postgres', 'POSTGRES_DATABASE=demo', 'POSTGRES_USER=demo',
                     'POSTGRES_PASSWORD', 'REDIS_HOST=redis']
        orders = launch('orders', image_ids['orders-api'], variables, port=True)
        worker = launch('worker', image_ids['notifications-worker'], variables, port=True)
        orders_port = docker('port', orders, '8080/tcp').rsplit(':', 1)[1]
        worker_port = docker('port', worker, '8080/tcp').rsplit(':', 1)[1]
        until(lambda: request(orders_port, 'ready')[0] == 200)
        until(lambda: request(worker_port, 'ready')[0] == 200)

        def order_roundtrip():
            code, body = request(orders_port, 'api/v1/orders',
                                 {'customer_id': identifier, 'amount': '12.50'})
            if code != 201:
                raise RuntimeError('Synthetic order creation failed')
            order_id = str(uuid.UUID(json.loads(body)['id']))
            if request(orders_port, 'api/v1/orders/' + order_id)[0] != 200:
                raise RuntimeError('Created order cannot be read')
            sql = ("SELECT count(*) FROM processed_notifications "
                   "WHERE payload->>'order_id'='" + order_id + "';")
            until(lambda: docker('exec', pg, 'psql', '-U', 'demo', '-d', 'demo', '-tAc', sql) == '1')
            if docker('exec', pg, 'psql', '-U', 'demo', '-d', 'demo', '-tAc',
                      "SELECT count(*) FROM orders WHERE id='" + order_id + "';") != '1':
                raise RuntimeError('PostgreSQL order persistence not confirmed')

        order_roundtrip()
        report['checks'].append('order_persisted_and_matching_notification_archived')
        # Keep the service address/DNS while making Redis unresponsive. This
        # models a hung dependency; removing a Docker container also removes
        # its service discovery entry, which is a different failure scenario.
        report['fault_mode'] = 'redis_process_paused_network_preserved'
        docker('pause', redis)
        try:
            until(lambda: request(orders_port, 'ready')[0] == 503)
            if request(orders_port, 'health')[0] != 200:
                raise RuntimeError('Liveness unexpectedly depends on Redis')
            report['checks'].append('redis_failure_readiness_503_liveness_200')
        finally:
            docker('unpause', redis)
        until(lambda: request(orders_port, 'ready')[0] == 200)
        order_roundtrip()
        until(lambda: 'asteria_notifications_processed_total 2.0' in request(worker_port, 'metrics')[1])
        report['checks'] += ['redis_recovered_second_order_archived', 'worker_counter_2']
        report['status'] = 'passed'
    finally:
        cleanup_errors = []
        for container in reversed(containers):
            try:
                labels = json.loads(docker('inspect', container))[0]['Config'].get('Labels') or {}
                if labels.get('asteria.test') != identifier:
                    raise ValueError('Ownership label mismatch')
                docker('rm', '-f', '-v', container)
            except (RuntimeError, ValueError):
                cleanup_errors.append('container')
        if network:
            try:
                docker('network', 'rm', network)
            except RuntimeError:
                cleanup_errors.append('network')
        report['cleanup'] = 'passed' if not cleanup_errors else 'failed'
        report['duration_seconds'] = round(time.monotonic() - start, 3)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open('x') as output:
            json.dump(report, output, indent=2)
            output.write('\n')
        if cleanup_errors:
            raise RuntimeError('Local cleanup failed; inspect resources with the unique test label')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    raise SystemExit(main())
