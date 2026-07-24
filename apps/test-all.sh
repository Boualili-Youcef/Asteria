#!/usr/bin/env bash
set -euo pipefail

apps_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
venv_path="${M13_VENV:-${apps_root}/.venv}"
services=(identity-api orders-api notifications-worker)

if [[ ! -x "${venv_path}/bin/python" ]]; then
  python3 -m venv "${venv_path}"
fi

"${venv_path}/bin/python" -m pip install --upgrade pip

for service in "${services[@]}"; do
  "${venv_path}/bin/python" -m pip install \
    --requirement "${apps_root}/${service}/requirements.txt" \
    --requirement "${apps_root}/${service}/requirements-dev.txt"
done

for service in "${services[@]}"; do
  printf 'Testing %s\n' "${service}"
  (
    cd "${apps_root}/${service}"
    PYTHONPATH=. "${venv_path}/bin/python" -m pytest
  )
done

printf 'M13 unit tests passed\n'
