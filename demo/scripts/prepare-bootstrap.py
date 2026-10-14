#!/usr/bin/env python3
"""Prepare private disposable demo manifests without contacting Kubernetes."""
import argparse
import json
import os
from pathlib import Path
import secrets

from promote import ROOT, NAMESPACE, validate_release

PG = 'postgres@sha256:0ea6700a3b4f0ae6ce746519073558aed4d88a79d8d07622a9a644946c7319c4'
REDIS = 'redis@sha256:9d317178eceac8454a2284a9e6df2466b93c745529947f0cd42a0fa9609d7005'


def resource(kind, name, **fields):
    version = {'Deployment': 'apps/v1', 'NetworkPolicy': 'networking.k8s.io/v1'}.get(kind, 'v1')
    return {'apiVersion': version, 'kind': kind,
            'metadata': {'name': name, 'namespace': NAMESPACE}, **fields}


def peer(labels):
    return {'namespaceSelector': {'matchLabels': {'kubernetes.io/metadata.name': NAMESPACE}},
            'podSelector': {'matchLabels': labels}}


def flow(labels, port, direction):
    return {direction: [peer(labels)], 'ports': [{'protocol': 'TCP', 'port': port}]}


def network():
    out = []
    def policy(name, selector, **rules):
        out.append(resource('NetworkPolicy', name, spec={'podSelector': selector,
            'policyTypes': [k.title() for k in rules], **rules}))
    policy('demo-default-deny', {}, ingress=[], egress=[])
    policy('demo-dns', {}, egress=[{'to': [{
        'namespaceSelector': {'matchLabels': {'kubernetes.io/metadata.name': 'kube-system'}},
        'podSelector': {'matchLabels': {'k8s-app': 'kube-dns'}}}],
        'ports': [{'protocol': p, 'port': 53} for p in ['UDP', 'TCP']]}])
    orders = {'app.kubernetes.io/instance': 'orders-demo'}
    worker = {'app': 'demo-notifications'}
    for name, labels in [('orders', orders), ('worker', worker)]:
        policy('demo-' + name + '-data', {'matchLabels': labels}, egress=[
            flow({'app': 'demo-postgres'}, 5432, 'to'), flow({'app': 'demo-redis'}, 6379, 'to')])
    for name, port in [('postgres', 5432), ('redis', 6379)]:
        policy('demo-' + name + '-clients', {'matchLabels': {'app': 'demo-' + name}},
               ingress=[flow(orders, port, 'from'), flow(worker, port, 'from')])
    policy('demo-orders-probe', {'matchLabels': orders},
           ingress=[flow({'asteria.io/test-role': 'allowed'}, 8080, 'from')])
    policy('demo-probe-egress', {'matchExpressions': [{'key': 'asteria.io/test-role',
        'operator': 'In', 'values': ['allowed', 'denied']}]}, egress=[flow(orders, 8080, 'to')])
    return out


def deployment(name, image, port, request, limit, uid=10001):
    container = {'name': name, 'image': image, 'imagePullPolicy': 'IfNotPresent',
        'ports': [{'containerPort': port}],
        'resources': {'requests': {'cpu': '20m', 'memory': request},
                      'limits': {'cpu': '250m', 'memory': limit}},
        'securityContext': {'allowPrivilegeEscalation': False, 'readOnlyRootFilesystem': True,
                            'capabilities': {'drop': ['ALL']}}}
    labels = {'app': name}
    return resource('Deployment', name, spec={'replicas': 1, 'strategy': {'type': 'Recreate'},
        'selector': {'matchLabels': labels}, 'template': {'metadata': {'labels': labels}, 'spec': {
            'automountServiceAccountToken': False,
            'securityContext': {'runAsNonRoot': True, 'runAsUser': uid, 'runAsGroup': uid,
                                'fsGroup': uid, 'seccompProfile': {'type': 'RuntimeDefault'}},
            'containers': [container]}}})


def runtime():
    pg = deployment('demo-postgres', PG, 5432, '128Mi', '256Mi', uid=999)
    pod = pg['spec']['template']['spec']
    c = pod['containers'][0]
    c['envFrom'] = [{'secretRef': {'name': 'orders-demo-postgres'}}]
    c['env'] = [{'name': 'POSTGRES_DB', 'value': 'demo'},
                {'name': 'PGDATA', 'value': '/var/lib/postgresql/pgdata'}]
    c['args'] = ['postgres', '-c', 'shared_buffers=32MB', '-c', 'max_connections=20']
    mounts = [('data', '/var/lib/postgresql', '512Mi'), ('tmp', '/tmp', '64Mi'),
              ('run', '/var/run/postgresql', '8Mi')]
    c['volumeMounts'] = [{'name': n, 'mountPath': p} for n, p, _ in mounts]
    pod['volumes'] = [{'name': n, 'emptyDir': {'sizeLimit': s}} for n, _, s in mounts]
    c['readinessProbe'] = {'exec': {'command': ['pg_isready', '-U', 'demo', '-d', 'demo']},
                           'initialDelaySeconds': 3, 'periodSeconds': 5}
    redis = deployment('demo-redis', REDIS, 6379, '32Mi', '96Mi')
    c = redis['spec']['template']['spec']['containers'][0]
    c['command'] = ['redis-server']
    c['args'] = ['--save', '', '--appendonly', 'no', '--maxmemory', '64mb',
                 '--maxmemory-policy', 'noeviction']
    c['readinessProbe'] = {'exec': {'command': ['redis-cli', 'ping']}, 'periodSeconds': 5}
    worker = deployment('demo-notifications', 'docker.io/asteria/notifications-worker:m13',
                        8080, '64Mi', '256Mi')
    c = worker['spec']['template']['spec']['containers'][0]
    c['imagePullPolicy'] = 'Never'  # Compare the cached image ID on both workers before bootstrap.
    c['envFrom'] = [{'configMapRef': {'name': 'orders-demo-runtime'}},
                    {'secretRef': {'name': 'orders-demo-postgres'}}]
    c['readinessProbe'] = {'httpGet': {'path': '/ready', 'port': 8080}, 'periodSeconds': 5}
    c['livenessProbe'] = {'httpGet': {'path': '/health', 'port': 8080},
                          'initialDelaySeconds': 10, 'periodSeconds': 10}
    services = [resource('Service', 'demo-' + name, spec={'selector': {'app': 'demo-' + name},
        'ports': [{'port': port, 'targetPort': port}]}) for name, port in [('postgres', 5432), ('redis', 6379)]]
    config = resource('ConfigMap', 'orders-demo-runtime', data={
        'POSTGRES_HOST': 'demo-postgres', 'POSTGRES_DATABASE': 'demo', 'POSTGRES_CONNECT_TIMEOUT': '2',
        'REDIS_HOST': 'demo-redis', 'REDIS_CONNECT_TIMEOUT': '2'})
    secret = resource('Secret', 'orders-demo-postgres', type='Opaque', stringData={
        'POSTGRES_USER': 'demo', 'POSTGRES_PASSWORD': secrets.token_urlsafe(32)})
    return [config, secret, *services, pg, redis, worker]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path, help='new private directory outside Git')
    args = parser.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents:
        raise ValueError('Output must be outside the repository')
    release = validate_release(json.loads((ROOT / 'demo/evidence/orders-release.json').read_text()))
    output.mkdir(mode=0o700, parents=False, exist_ok=False)
    values = {'image': {'repository': release['image'], 'digest': release['digest'], 'tag': ''},
              'deployment': {'commit': release['commit'], 'run': release['run_id']}}
    probes = []
    for role in ['allowed', 'denied']:
        program = ("import urllib.request,sys; "
                   "urllib.request.urlopen('http://orders-api:8080/health',timeout=4); "
                   "print('allowed_probe_passed')") if role == 'allowed' else (
                   "import urllib.request,urllib.error,socket,sys\n"
                   "socket.gethostbyname('orders-api')\n"
                   "try:\n urllib.request.urlopen('http://orders-api:8080/health',timeout=4)\n"
                   "except urllib.error.HTTPError:\n sys.exit('Unexpected HTTP response')\n"
                   "except OSError:\n print('denied_probe_passed'); sys.exit(0)\n"
                   "sys.exit('Unexpected access: network isolation failed')\n")
        probes.append(resource('Pod', 'demo-network-' + role, spec={
            'restartPolicy': 'Never', 'automountServiceAccountToken': False,
            'activeDeadlineSeconds': 120,
            'securityContext': {'runAsNonRoot': True, 'runAsUser': 10001, 'runAsGroup': 10001,
                                'seccompProfile': {'type': 'RuntimeDefault'}},
            'containers': [{'name': 'probe', 'image': release['image'] + '@' + release['digest'],
                'command': ['python', '-c', program],
                'resources': {'requests': {'cpu': '10m', 'memory': '32Mi'},
                              'limits': {'cpu': '100m', 'memory': '64Mi'}},
                'securityContext': {'allowPrivilegeEscalation': False, 'readOnlyRootFilesystem': True,
                                    'capabilities': {'drop': ['ALL']}}}]}))
        probes[-1]['metadata']['labels'] = {'asteria.io/test-role': role}
    files = {'network.json': {'apiVersion': 'v1', 'kind': 'List', 'items': network()},
             'runtime.json': {'apiVersion': 'v1', 'kind': 'List', 'items': runtime()},
             'network-probes.json': {'apiVersion': 'v1', 'kind': 'List', 'items': probes},
             'release-values.json': values}
    for name, data in files.items():
        descriptor = os.open(output / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, 'w') as stream:
            json.dump(data, stream, indent=2)
            stream.write('\n')
    print(json.dumps({'status': 'prepared_only', 'namespace': NAMESPACE,
        'deployments_including_helm': 4, 'network_policies': len(network()),
        'credentials': 'private_bundle_only', 'cluster_contacted': False}))


if __name__ == '__main__':
    main()
