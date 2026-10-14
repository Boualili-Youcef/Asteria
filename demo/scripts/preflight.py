#!/usr/bin/env python3
"""Read the source state and optionally the source bastion; emit a public summary."""
import argparse
import datetime
import ipaddress
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).absolute().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--read-source', action='store_true')
    parser.add_argument('--key', type=Path, default=Path.home() / '.ssh/tp_cloud')
    args = parser.parse_args()
    state = json.loads((ROOT / 'infra/terraform/openstack/terraform.tfstate').read_text())
    instances = state['outputs']['compute_instances']['value']
    report = {'date': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'environment': 'source', 'state_vm_count': len(instances),
              'openstack_identity': 'not_verified', 'quotas': 'not_verified',
              'cloud_mutations': False, 'runtime': 'not_checked'}
    if args.read_source:
        address = str(ipaddress.ip_address(instances['bastion']['access_ip_v4']))
        remote = '''import json, subprocess, shutil
def k(*args):
 r=subprocess.run(['kubectl','--request-timeout=15s',*args],capture_output=True,text=True,timeout=25)
 if r.returncode: raise RuntimeError('Kubernetes read failed')
 return json.loads(r.stdout)
nodes=k('get','nodes','-o','json')['items']
deploys=k('get','deployments','-A','-o','json')['items']
allowed={'team-orders','team-identity','team-notifications','monitoring','shared','ingress-nginx'}
out={'node_count':len(nodes),'nodes_ready':sum(any(c['type']=='Ready' and c['status']=='True' for c in n['status']['conditions']) for n in nodes),'versions':sorted(set(n['status']['nodeInfo']['kubeletVersion'] for n in nodes)), 'deployments':[{'namespace':d['metadata']['namespace'],'name':d['metadata']['name'],'desired':d['spec'].get('replicas',1),'available':d['status'].get('availableReplicas',0),'images':[c['image'] for c in d['spec']['template']['spec']['containers']]} for d in deploys if d['metadata']['namespace'] in allowed]}
try:
 metrics=k('get','--raw','/apis/metrics.k8s.io/v1beta1/nodes')['items']
 out['node_usage']=[{'cpu':m['usage']['cpu'],'memory':m['usage']['memory']} for m in metrics]
except Exception: out['node_usage']='unavailable'
out['bastion_memory']=subprocess.check_output(['free','-m'],text=True).splitlines()[1].split()[1:]
out['bastion_root_disk']=subprocess.check_output(['df','-B1','--output=size,used,avail,pcent','/'],text=True).splitlines()[1].split()
print(json.dumps(out))
'''
        command = ['ssh', '-F', '/dev/null', '-o', 'BatchMode=yes', '-o',
                   'StrictHostKeyChecking=yes', '-o', 'ConnectTimeout=10',
                   '-i', str(args.key), 'ubuntu@' + address, 'python3 -']
        try:
            result = subprocess.run(command, input=remote, capture_output=True,
                                    text=True, timeout=90, check=True)
            report['runtime'] = json.loads(result.stdout)
        except (subprocess.SubprocessError, ValueError):
            report['runtime'] = 'unavailable; no mutation permitted'
    print(json.dumps(report, indent=2))
    return 0 if isinstance(report['runtime'], dict) or not args.read_source else 1


if __name__ == '__main__':
    raise SystemExit(main())
