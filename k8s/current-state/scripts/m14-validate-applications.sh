#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  printf 'Usage: %s <worker-01-ip> <worker-02-ip> <test-image>\n' "$0" >&2
  exit 2
fi

worker_01_ip="$1"
worker_02_ip="$2"
test_image="$3"
test_pod="m14-applications-check"

cleanup() {
  kubectl --namespace=team-orders delete "pod/${test_pod}" \
    --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

kubectl --namespace=team-identity rollout status \
  deployment/identity-api --timeout=180s
kubectl --namespace=team-orders rollout status \
  deployment/orders-api --timeout=180s
kubectl --namespace=team-notifications rollout status \
  deployment/notifications-worker --timeout=180s

test "$(
  kubectl --namespace=team-identity get deployment/identity-api \
    --output=jsonpath='{.metadata.labels.asteria\.io/deployment-method}'
)" = "raw-yaml"
test "$(
  kubectl --namespace=team-orders get deployment/orders-api \
    --output=jsonpath='{.metadata.labels.asteria\.io/deployment-method}'
)" = "helm"
test "$(
  kubectl --namespace=team-notifications get deployment/notifications-worker \
    --output=jsonpath='{.metadata.labels.asteria\.io/deployment-method}'
)" = "manual-kubectl"

helm --namespace=team-orders status orders-api >/dev/null
test -z "$(
  kubectl --namespace=team-notifications get ingress --output=name
)"

kubectl --namespace=team-orders run "${test_pod}" \
  --image="${test_image}" \
  --restart=Never \
  --command -- sh -ec '
    suffix="$(date +%s)-$$"

    identity_ready="$(
      wget -qO- \
        http://identity-api.team-identity.svc.cluster.local:8080/ready
    )"
    printf "%s" "${identity_ready}" | grep -q "\"status\":\"ready\""

    identity_created="$(
      wget -qO- \
        --header="Content-Type: application/json" \
        --post-data="{\"email\":\"m14-${suffix}@example.test\",\"display_name\":\"M14 validation\"}" \
        http://identity-api.team-identity.svc.cluster.local:8080/api/v1/users
    )"
    printf "%s" "${identity_created}" | grep -q "m14-${suffix}@example.test"

    orders_ready="$(
      wget -qO- http://orders-api:8080/ready
    )"
    printf "%s" "${orders_ready}" | grep -q "\"status\":\"ready\""

    order_created="$(
      wget -qO- \
        --header="Content-Type: application/json" \
        --post-data="{\"customer_id\":\"m14-${suffix}\",\"amount\":\"12.50\"}" \
        http://orders-api:8080/api/v1/orders
    )"
    printf "%s" "${order_created}" | grep -q "\"status\":\"created\""

    worker_ready="$(
      wget -qO- \
        http://notifications-worker.team-notifications.svc.cluster.local:8080/ready
    )"
    printf "%s" "${worker_ready}" | grep -q "\"status\":\"ready\""

    wget -qO- \
      http://identity-api.team-identity.svc.cluster.local:8080/metrics |
      grep -q asteria_service_info
    wget -qO- http://orders-api:8080/metrics |
      grep -q asteria_service_info

    processed=false
    for _ in $(seq 1 30); do
      if wget -qO- \
        http://notifications-worker.team-notifications.svc.cluster.local:8080/metrics |
        grep -Eq "asteria_notifications_processed_total [1-9][0-9]*(\\.[0-9]+)?"; then
        processed=true
        break
      fi
      sleep 1
    done
    test "${processed}" = "true"

    printf "Identity create/readiness passed\n"
    printf "Orders PostgreSQL/Redis flow passed\n"
    printf "Notifications worker consumed and archived an event\n"
  '

for _ in $(seq 1 90); do
  phase="$(
    kubectl --namespace=team-orders get "pod/${test_pod}" \
      --output=jsonpath='{.status.phase}' 2>/dev/null || true
  )"
  case "${phase}" in
    Succeeded)
      kubectl --namespace=team-orders logs "pod/${test_pod}"
      break
      ;;
    Failed)
      kubectl --namespace=team-orders logs "pod/${test_pod}" >&2 || true
      exit 1
      ;;
  esac
  sleep 2
done

test "${phase}" = "Succeeded"

for worker_ip in "${worker_01_ip}" "${worker_02_ip}"; do
  curl --fail --silent --show-error --max-time 8 \
    --header 'Host: identity.asteria.local' \
    "http://${worker_ip}:30080/ready" |
    grep -q '"status":"ready"'
  curl --fail --silent --show-error --max-time 8 \
    --header 'Host: orders.asteria.local' \
    "http://${worker_ip}:30080/ready" |
    grep -q '"status":"ready"'
  printf 'Ingress routes passed through %s\n' "${worker_ip}"
done

kubectl get deployments \
  --namespace=team-identity \
  --namespace=team-orders \
  --namespace=team-notifications >/dev/null

printf 'M14 heterogeneous application checks passed\n'
