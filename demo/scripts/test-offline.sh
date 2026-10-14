#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python="${ASTERIA_TEST_PYTHON:-${root}/apps/.venv/bin/python}"
[[ -x "$python" ]] || { echo 'Install the pinned apps requirements in a local venv first.' >&2; exit 1; }
for app in identity-api orders-api notifications-worker; do
  (cd "${root}/apps/${app}" && PYTHONPATH=. "$python" -m pytest)
done
python3 -m unittest discover -s "${root}/demo/tests" -v
helm lint "${root}/k8s/current-state/orders-api/chart"
echo 'PASS: offline application and delivery checks'
