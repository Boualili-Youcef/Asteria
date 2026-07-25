#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ssh_key="${ASTERIA_SSH_PRIVATE_KEY_FILE:?Set ASTERIA_SSH_PRIVATE_KEY_FILE}"
ssh_user="${ASTERIA_SSH_USER:-ubuntu}"

command -v jq >/dev/null
command -v ssh >/dev/null
command -v terraform >/dev/null
test -r "${ssh_key}"

instances="$(
  terraform -chdir="${repo_root}/infra/terraform/openstack" \
    output -json compute_instances
)"
bastion_ip="$(jq -r '.bastion.access_ip_v4' <<<"${instances}")"
postgres_ip="$(jq -r '.postgres.access_ip_v4' <<<"${instances}")"

ssh_common=(
  -F /dev/null
  -i "${ssh_key}"
  -o BatchMode=yes
  -o ConnectTimeout=8
  -o StrictHostKeyChecking=accept-new
)

apply_runtime() {
  local namespace="$1"
  local service="$2"
  local database="$3"
  local role="$4"
  local needs_redis="$5"
  local secret_file="${repo_root}/.secrets/m08-postgres/${role}.password"
  local redis_args=""

  test -s "${secret_file}"
  if [[ "${needs_redis}" == "true" ]]; then
    redis_args="--from-literal=REDIS_HOST=redis-shared.shared.svc.cluster.local --from-literal=REDIS_PORT=6379 --from-literal=REDIS_CONNECT_TIMEOUT=3"
  fi

  ssh "${ssh_common[@]}" "${ssh_user}@${bastion_ip}" \
    "kubectl --namespace=${namespace} create configmap ${service}-runtime \
      --from-literal=POSTGRES_HOST=${postgres_ip} \
      --from-literal=POSTGRES_PORT=5432 \
      --from-literal=POSTGRES_DATABASE=${database} \
      --from-literal=POSTGRES_USER=${role} \
      --from-literal=POSTGRES_CONNECT_TIMEOUT=3 \
      ${redis_args} \
      --dry-run=client --output=yaml |
     kubectl apply --filename=-"

  ssh "${ssh_common[@]}" "${ssh_user}@${bastion_ip}" \
    "kubectl --namespace=${namespace} create secret generic ${service}-postgres \
      --from-file=POSTGRES_PASSWORD=/dev/stdin \
      --dry-run=client --output=yaml |
     kubectl apply --filename=-" \
    < "${secret_file}"

  printf '%s runtime configuration applied in %s\n' "${service}" "${namespace}"
}

apply_runtime team-identity identity identity_db identity_app false
apply_runtime team-orders orders orders_db orders_app true
apply_runtime \
  team-notifications notifications notifications_db notifications_app true

printf 'M14 runtime ConfigMaps and Secrets applied without storing values in Git\n'
