#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/home/ubuntu/.kube/config}"

test_namespace="m09-connectivity"
worker_one="k8s-worker-01"
worker_two="k8s-worker-02"
probe_one="probe-worker-01"
probe_two="probe-worker-02"
probe_image="${ASTERIA_M09_PROBE_IMAGE:-busybox:1.37.0}"
postgres_host="${ASTERIA_POSTGRES_HOST:-}"

cleanup() {
  kubectl delete namespace "${test_namespace}" \
    --ignore-not-found --wait=true >/dev/null 2>&1 || true
}

trap cleanup EXIT
cleanup

kubectl create namespace "${test_namespace}"

kubectl run "${probe_one}" \
  --namespace "${test_namespace}" \
  --image "${probe_image}" \
  --restart Never \
  --overrides "{\"spec\":{\"nodeName\":\"${worker_one}\"}}" \
  --command -- sh -c 'sleep 300'

kubectl run "${probe_two}" \
  --namespace "${test_namespace}" \
  --image "${probe_image}" \
  --restart Never \
  --overrides "{\"spec\":{\"nodeName\":\"${worker_two}\"}}" \
  --command -- sh -c 'sleep 300'

kubectl wait \
  --namespace "${test_namespace}" \
  --for=condition=Ready pod/${probe_one} pod/${probe_two} \
  --timeout=180s

probe_two_ip="$(kubectl get pod "${probe_two}" \
  --namespace "${test_namespace}" \
  --output jsonpath='{.status.podIP}')"

kubectl exec --namespace "${test_namespace}" "${probe_one}" -- \
  nslookup kubernetes.default.svc.cluster.local

kubectl exec --namespace "${test_namespace}" "${probe_one}" -- \
  ping -c 3 -W 3 "${probe_two_ip}"

if [[ -n "${postgres_host}" ]]; then
  kubectl exec --namespace "${test_namespace}" "${probe_one}" -- \
    nc -z -w 5 "${postgres_host}" 5432
fi

printf '%s\n' "M09 connectivity checks passed"
