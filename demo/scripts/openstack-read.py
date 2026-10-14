#!/usr/bin/env python3
"""Run after loading only the source OpenRC. Never emit credentials or IDs."""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).absolute().parents[2]


def query(*args):
    result = subprocess.run(['openstack', *args, '-f', 'json'], capture_output=True,
                            text=True, timeout=40, check=True)
    return json.loads(result.stdout)


def main():
    state = json.loads((ROOT / 'infra/terraform/openstack/terraform.tfstate').read_text())
    expected = {item['id'] for resource in state['resources']
                if resource['type'] == 'openstack_compute_instance_v2'
                for instance in resource['instances'] for item in [instance['attributes']]}
    token = query('token', 'issue')
    if not os.environ.get('OS_PROJECT_ID') or token.get('project_id') != os.environ['OS_PROJECT_ID']:
        raise ValueError('Session project not explicitly confirmed')
    servers = query('server', 'list')
    observed = {server['ID'] for server in servers}
    if not expected or not expected.issubset(observed):
        raise ValueError('Authenticated project does not contain the five source state instances')
    result = {'source_identity': 'confirmed_by_token_and_all_source_instance_ids',
              'source_state_instances': len(expected), 'project_instances': len(servers),
              'server_statuses': [server['Status'] for server in servers],
              'mutations': False}
    limits = query('limits', 'show', '--absolute')
    allowed = {'maxTotalCores', 'totalCoresUsed', 'maxTotalRAMSize', 'totalRAMUsed',
               'maxTotalInstances', 'totalInstancesUsed', 'maxTotalVolumeGigabytes',
               'totalGigabytesUsed', 'maxTotalVolumes', 'totalVolumesUsed'}
    result['limits'] = {row['Name']: row['Value'] for row in limits if row.get('Name') in allowed}
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.SubprocessError):
        print('BLOCKED: source authentication, instance ownership or limits unverified; no mutation.', file=sys.stderr)
        raise SystemExit(1)
