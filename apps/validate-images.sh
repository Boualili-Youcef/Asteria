#!/usr/bin/env bash
set -euo pipefail

services=(identity-api orders-api notifications-worker)
containers=()

cleanup() {
  if [[ ${#containers[@]} -gt 0 ]]; then
    docker container rm --force "${containers[@]}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

for service in "${services[@]}"; do
  image="asteria/${service}:m13"
  name="asteria-m13-${service}"
  containers+=("${name}")

  run_args=(
    run
    --detach
    --name "${name}"
    --publish 127.0.0.1::8080
  )
  if [[ "${service}" == "notifications-worker" ]]; then
    run_args+=(--env RUN_WORKER=false)
  fi
  run_args+=("${image}")

  docker "${run_args[@]}" >/dev/null

  port=""
  for _ in $(seq 1 30); do
    port="$(docker port "${name}" 8080/tcp | awk -F: '{print $NF}')"
    if [[ -n "${port}" ]] &&
      curl --silent --fail "http://127.0.0.1:${port}/health" >/dev/null; then
      break
    fi
    sleep 1
  done

  curl --silent --fail "http://127.0.0.1:${port}/health" |
    grep -q '"status":"healthy"'
  curl --silent --fail "http://127.0.0.1:${port}/metrics" |
    grep -q 'asteria_service_info'

  image_user="$(docker image inspect --format '{{.Config.User}}' "${image}")"
  test "${image_user}" = "10001:10001"
  printf '%s image: health, metrics and non-root user validated\n' "${service}"
done

printf 'M13 container smoke tests passed\n'
