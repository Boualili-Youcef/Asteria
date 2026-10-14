#!/usr/bin/env python3
"""Promote an approved CI artifact to an existing isolated Helm 3 release."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import tempfile
import time
import urllib.request

ROOT = Path(__file__).absolute().parents[2]
REPOSITORY = 'Boualili-Youcef/Asteria'
IMAGE = 'ghcr.io/boualili-youcef/asteria/orders-api'
NAMESPACE = 'asteria-demo'
RELEASE = 'orders-demo'


def run(args, timeout=60):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        # Avoid publishing raw CLI errors, manifests or credential-bearing URLs.
        raise RuntimeError(f'{args[0]} {args[1]} failed (exit {result.returncode})')
    return result.stdout


def validate_release(data):
    if set(data) != {'schema', 'commit', 'image', 'digest', 'run_id'}:
        raise ValueError('Unexpected release fields')
    if data['schema'] != 1 or data['image'] != IMAGE:
        raise ValueError('Unexpected repository or schema')
    if not isinstance(data['commit'], str) or not re.fullmatch('[0-9a-f]{40}', data['commit']):
        raise ValueError('A full commit SHA is required')
    if not isinstance(data['digest'], str) or not re.fullmatch('sha256:[0-9a-f]{64}', data['digest']):
        raise ValueError('An immutable digest is required')
    if not isinstance(data['run_id'], str) or not re.fullmatch('[1-9][0-9]{0,19}', data['run_id']):
        raise ValueError('Invalid run ID')
    return data


def verify_ci(data):
    info = json.loads(run(['gh', 'api', f'repos/{REPOSITORY}/actions/runs/{data["run_id"]}']))
    if (info.get('conclusion') != 'success' or info.get('head_sha') != data['commit']
            or info.get('path') != '.github/workflows/orders-demo.yml'
            or info.get('repository', {}).get('full_name') != REPOSITORY):
        raise ValueError('CI identity, commit or success does not match')
    jobs = json.loads(run(['gh', 'api', f'repos/{REPOSITORY}/actions/runs/{data["run_id"]}/jobs']))
    required = {'Synthetic Orders event flow', 'Scan the published candidate before allowing promotion'}
    release_jobs = [job for job in jobs.get('jobs', []) if job.get('name') == 'release']
    if not any(required.issubset({step['name'] for step in job.get('steps', [])
                                 if step.get('conclusion') == 'success'}) for job in release_jobs):
        raise ValueError('Successful scan and real functional gate are required')
    with tempfile.TemporaryDirectory(prefix='asteria-ci-') as directory:
        run(['gh', 'run', 'download', data['run_id'], '--repo', REPOSITORY,
             '--name', 'orders-release-' + data['run_id'], '--dir', directory])
        canonical = validate_release(json.loads((Path(directory) / 'release.json').read_text()))
        if canonical != data:
            raise ValueError('Release differs from the successful CI artifact')


class Target:
    def __init__(self, context, cluster_uid, namespace_uid):
        self.k = ['kubectl', '--context', context, '--request-timeout=20s', '-n', NAMESPACE]
        self.h = ['helm', '--kube-context', context, '--namespace', NAMESPACE]
        # Reading these two namespace identities needs a narrowly scoped ClusterRole.
        system = json.loads(run(self.k + ['get', 'namespace', 'kube-system', '-o', 'json']))
        demo = json.loads(run(self.k + ['get', 'namespace', NAMESPACE, '-o', 'json']))
        if system['metadata']['uid'] != cluster_uid or demo['metadata']['uid'] != namespace_uid:
            raise ValueError('Cluster or namespace identity mismatch')
        if demo['metadata'].get('labels', {}).get('asteria.io/purpose') != 'demo-v1':
            raise ValueError('Namespace is not marked demo-v1')
        if not run(['helm', 'version', '--short']).startswith('v3.'):
            raise ValueError('This procedure requires Helm 3 (--atomic semantics)')

    def image(self):
        obj = json.loads(run(self.k + ['get', 'deployment', 'orders-api', '-o', 'json']))
        return next(c['image'] for c in obj['spec']['template']['spec']['containers']
                    if c['name'] == 'orders-api')

    def verify(self, expected):
        run(self.k + ['rollout', 'status', 'deployment/orders-api', '--timeout=180s'], 210)
        if self.image() != expected:
            raise RuntimeError('Deployment image differs from expected digest')
        pods = json.loads(run(self.k + ['get', 'pods', '-l',
                         'app.kubernetes.io/instance=' + RELEASE, '-o', 'json']))['items']
        active = [p for p in pods if not p['metadata'].get('deletionTimestamp')]
        if not active or not all(any(c['type'] == 'Ready' and c['status'] == 'True'
                                    for c in p['status'].get('conditions', [])) for p in active):
            raise RuntimeError('All active release Pods must be Ready')
        ids = [c.get('imageID', '') for p in active for c in p['status'].get('containerStatuses', [])
               if c['name'] == 'orders-api']
        if not ids or not all('sha256:' in value for value in ids):
            raise RuntimeError('Runtime image IDs unavailable')
        # An OCI index digest may differ from its platform imageID. Record both.
        self.probe()
        return ids

    def probe(self):
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        process = subprocess.Popen(self.k + ['port-forward', '--address=127.0.0.1',
                                   'service/orders-api', f'{port}:8080'],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            for attempt in range(40):
                try:
                    for path in ['health', 'ready', 'metrics']:
                        with urllib.request.urlopen(f'http://127.0.0.1:{port}/{path}', timeout=4) as response:
                            body = response.read()
                            if response.status != 200 or (path == 'metrics' and b'asteria_service_info' not in body):
                                raise RuntimeError('Application probe failed')
                    return
                except (OSError, RuntimeError):
                    if process.poll() is not None or attempt == 39:
                        raise RuntimeError('Private service probes failed') from None
                    time.sleep(.5)
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def transact(target, command, previous_revision, previous_image, expected, event=lambda *_: None):
    """Rollback also covers a successful Helm update followed by failed probes."""
    try:
        event('upgrade_started')
        run(command, 420)
        ids = target.verify(expected)
        event('upgrade_verified')
        return 'promoted', ids
    except (RuntimeError, subprocess.TimeoutExpired, KeyboardInterrupt):
        event('upgrade_failed')
        event('rollback_started')
        run(target.h + ['rollback', RELEASE, str(previous_revision), '--wait', '--timeout', '180s'], 210)
        ids = target.verify(previous_image)
        event('rollback_verified')
        return 'failed_then_rolled_back', ids


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifact', type=Path)
    parser.add_argument('--context', required=True)
    parser.add_argument('--cluster-uid', required=True)
    parser.add_argument('--namespace-uid', required=True)
    parser.add_argument('--execute', action='store_true', help='requires separately approved scope')
    parser.add_argument('--failure-drill', action='store_true', help='invalid readiness path; isolated namespace only')
    parser.add_argument('--evidence', type=Path, help='new private JSON file outside the repository')
    args = parser.parse_args()
    data = validate_release(json.loads(args.artifact.read_text()))
    verify_ci(data)
    target = Target(args.context, args.cluster_uid, args.namespace_uid)
    status = json.loads(run(target.h + ['status', RELEASE, '-o', 'json']))
    if status['info']['status'] != 'deployed':
        raise ValueError('A healthy existing release is required; bootstrap is separate')
    previous = target.image()
    if not re.fullmatch(re.escape(IMAGE) + '@sha256:[0-9a-f]{64}', previous):
        raise ValueError('Previous image must already be pinned to an approved digest')
    target.verify(previous)
    values = {'image': {'repository': IMAGE, 'digest': data['digest'], 'tag': ''},
              'deployment': {'commit': data['commit'], 'run': data['run_id'],
                             'readinessPath': '/demo-intentionally-not-ready' if args.failure_drill else '/ready'}}
    expected = IMAGE + '@' + data['digest']
    with tempfile.TemporaryDirectory(prefix='asteria-values-') as directory:
        path = Path(directory) / 'values.json'
        path.write_text(json.dumps(values))
        common = [RELEASE, str(ROOT / 'k8s/current-state/orders-api/chart'),
                  '-f', str(ROOT / 'demo/values.yaml'), '-f', str(path)]
        # Only render locally: no Helm dry-run output may leak existing secrets.
        run(['helm', 'template', '--namespace', NAMESPACE] + common)
        if not args.execute:
            print(json.dumps({'status': 'preview_only', 'image': expected,
                              'previous_image': previous, 'failure_drill': args.failure_drill}))
            return 0
        if args.evidence is None or ROOT in args.evidence.absolute().parents:
            raise ValueError('--evidence must name a new private file outside the repository')
        # Reserve the evidence file before any mutation; do not overwrite prior evidence.
        descriptor = os.open(args.evidence, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, 'w') as evidence:
            evidence.write(json.dumps({'status': 'started', 'release': data}) + '\n')
            evidence.flush()
            start = time.monotonic()
            def event(name):
                evidence.write(json.dumps({'event': name, 'elapsed_seconds': round(time.monotonic() - start, 3)}) + '\n')
                evidence.flush()
            outcome, ids = transact(target, target.h + ['upgrade'] + common +
                                    ['--atomic', '--wait', '--timeout', '180s', '--history-max', '10'],
                                    status['version'], previous, expected, event)
            result = {'status': outcome, 'date': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                      'duration_seconds': round(time.monotonic() - start, 3), 'release': data,
                      'previous_image': previous, 'observed_image': target.image(),
                      'runtime_image_ids': ids, 'failure_drill': args.failure_drill}
            evidence.write(json.dumps(result) + '\n')
        print(json.dumps(result))
        if args.failure_drill:
            return 0 if outcome == 'failed_then_rolled_back' else 1
        return 0 if outcome == 'promoted' else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, RuntimeError, OSError, KeyError, subprocess.SubprocessError) as error:
        print(f'BLOCKED: {type(error).__name__}; no success claimed. Review private operator logs.', file=__import__('sys').stderr)
        raise SystemExit(1)
