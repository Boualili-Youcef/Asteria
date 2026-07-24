#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ssh_key="${ASTERIA_SSH_PRIVATE_KEY_FILE:?Set ASTERIA_SSH_PRIVATE_KEY_FILE}"
ssh_user="${ASTERIA_SSH_USER:-ubuntu}"
db_local_port="${ASTERIA_M13_DB_LOCAL_PORT:-15432}"
redis_local_port="${ASTERIA_M13_REDIS_LOCAL_PORT:-16379}"

command -v docker >/dev/null
command -v jq >/dev/null
command -v ssh >/dev/null
command -v terraform >/dev/null
test -r "${ssh_key}"

instances="$(
  terraform -chdir="${repo_root}/infra/terraform/openstack" \
    output -json compute_instances
)"
bastion_ip="$(jq -r '.bastion.access_ip_v4' <<<"${instances}")"
worker_ip="$(jq -r '.worker_01.access_ip_v4' <<<"${instances}")"
postgres_ip="$(jq -r '.postgres.access_ip_v4' <<<"${instances}")"

ssh_common=(
  -F /dev/null
  -i "${ssh_key}"
  -o BatchMode=yes
  -o ConnectTimeout=8
  -o ExitOnForwardFailure=yes
  -o StrictHostKeyChecking=accept-new
)

redis_ip="$(
  ssh "${ssh_common[@]}" "${ssh_user}@${bastion_ip}" \
    kubectl --namespace=shared get service/redis-shared \
    --output=jsonpath='{.spec.clusterIP}'
)"

socket_dir="$(mktemp -d /tmp/asteria-m13-tunnels.XXXXXX)"
db_socket="${socket_dir}/db.sock"
redis_socket="${socket_dir}/redis.sock"

cleanup() {
  ssh -S "${db_socket}" -O exit "${ssh_user}@${worker_ip}" \
    >/dev/null 2>&1 || true
  ssh -S "${redis_socket}" -O exit "${ssh_user}@${worker_ip}" \
    >/dev/null 2>&1 || true
  rmdir "${socket_dir}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

ssh "${ssh_common[@]}" \
  -J "${ssh_user}@${bastion_ip}" \
  -M -S "${db_socket}" -fN \
  -L "${db_local_port}:${postgres_ip}:5432" \
  "${ssh_user}@${worker_ip}"

ssh "${ssh_common[@]}" \
  -J "${ssh_user}@${bastion_ip}" \
  -M -S "${redis_socket}" -fN \
  -L "${redis_local_port}:${redis_ip}:6379" \
  "${ssh_user}@${worker_ip}"

validate_service() {
  local service="$1"
  local database="$2"
  local role="$3"
  local secret_file="${repo_root}/.secrets/m08-postgres/${role}.password"
  shift 3

  test -r "${secret_file}"
  POSTGRES_PASSWORD="$(<"${secret_file}")" \
    docker run --rm --network host \
      --env POSTGRES_HOST=127.0.0.1 \
      --env "POSTGRES_PORT=${db_local_port}" \
      --env "POSTGRES_DATABASE=${database}" \
      --env "POSTGRES_USER=${role}" \
      --env POSTGRES_PASSWORD \
      "$@" \
      "asteria/${service}:m13" \
      python -m app.check_dependencies
}

validate_service identity-api identity_db identity_app
validate_service \
  orders-api orders_db orders_app \
  --env REDIS_HOST=127.0.0.1 \
  --env "REDIS_PORT=${redis_local_port}"
validate_service \
  notifications-worker notifications_db notifications_app \
  --env REDIS_HOST=127.0.0.1 \
  --env "REDIS_PORT=${redis_local_port}"

printf 'M13 real dependency checks passed\n'
