#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
python3 - <<'PY'
import os, secrets, json, re
from pathlib import Path
p=Path('.env')
if not p.exists():
    fd=os.open(p,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as f:
        for name in ['PG_ADMIN_PASSWORD','APP_PASSWORD','READ_PASSWORD']:
            f.write(name+'='+secrets.token_hex(24)+'\n')
elif p.is_symlink() or p.stat().st_mode & 0o077:
    raise SystemExit('Refusing unsafe .env: require a regular private file (0600)')
release=json.loads(Path('../evidence/orders-release.json').read_text())
assert release['image']=='ghcr.io/boualili-youcef/asteria/orders-api'
assert re.fullmatch(r'sha256:[0-9a-f]{64}',release['digest'])
lines=[line for line in p.read_text().splitlines() if not line.startswith('ORDERS_IMAGE=')]
lines.append('ORDERS_IMAGE='+release['image']+'@'+release['digest'])
p.write_text('\n'.join(lines)+'\n')
PY
docker compose up --build --detach --wait --wait-timeout 180
echo 'Local Docker live: http://127.0.0.1:4180 — synthetic data only'
