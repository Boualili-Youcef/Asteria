#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[a-z0-9./:_-]+$ ]]; then
  printf 'Usage: %s <redis-client-image>\n' "$0" >&2
  exit 2
fi

redis_image="$1"
redis_host="redis-shared.shared.svc.cluster.local"
shared_key="m11:shared-connectivity"

cleanup() {
  kubectl --namespace=shared exec deployment/redis-shared -- \
    redis-cli del "${shared_key}" >/dev/null 2>&1 || true
  kubectl --namespace=team-orders delete pod/m11-orders-check \
    --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl --namespace=team-notifications delete pod/m11-notifications-check \
    --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_for_success() {
  local namespace="$1"
  local pod="$2"
  local phase=""

  for _ in $(seq 1 60); do
    phase="$(kubectl --namespace="${namespace}" get pod "${pod}" \
      --output=jsonpath='{.status.phase}' 2>/dev/null || true)"
    case "${phase}" in
      Succeeded)
        return 0
        ;;
      Failed)
        kubectl --namespace="${namespace}" logs "${pod}" >&2 || true
        return 1
        ;;
    esac
    sleep 2
  done

  kubectl --namespace="${namespace}" describe pod "${pod}" >&2 || true
  return 1
}

cleanup

kubectl --namespace=team-orders run m11-orders-check \
  --image="${redis_image}" \
  --restart=Never \
  --command -- sh -ec \
  "test \"\$(redis-cli -h ${redis_host} ping)\" = PONG
   test \"\$(redis-cli -h ${redis_host} set ${shared_key} orders)\" = OK
   printf 'team-orders: PONG and shared key written\\n'"
wait_for_success team-orders m11-orders-check
kubectl --namespace=team-orders logs pod/m11-orders-check

kubectl --namespace=team-notifications run m11-notifications-check \
  --image="${redis_image}" \
  --restart=Never \
  --command -- sh -ec \
  "test \"\$(redis-cli -h ${redis_host} ping)\" = PONG
   test \"\$(redis-cli -h ${redis_host} get ${shared_key})\" = orders
   printf 'team-notifications: PONG and shared key read\\n'"
wait_for_success team-notifications m11-notifications-check
kubectl --namespace=team-notifications logs pod/m11-notifications-check

printf 'M11 shared Redis checks passed\n'
