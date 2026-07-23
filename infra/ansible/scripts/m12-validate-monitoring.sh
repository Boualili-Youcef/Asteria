#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[a-z0-9./:_-]+$ ]]; then
  printf 'Usage: %s <validation-image>\n' "$0" >&2
  exit 2
fi

validation_image="$1"
pod_name="m12-observability-check"

cleanup() {
  kubectl --namespace=monitoring delete "pod/${pod_name}" \
    --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

kubectl --namespace=monitoring run "${pod_name}" \
  --image="${validation_image}" \
  --restart=Never \
  --command -- sh -ec '
    targets="$(wget -qO- http://prometheus.monitoring.svc.cluster.local:9090/api/v1/targets)"
    up_count="$(printf "%s" "${targets}" | grep -o "\"health\":\"up\"" | wc -l)"
    test "${up_count}" -ge 4
    printf "%s" "${targets}" | grep -q "node-exporter"

    health="$(wget -qO- http://grafana.monitoring.svc.cluster.local:3000/api/health)"
    printf "%s" "${health}" |
      grep -Eq "\"database\"[[:space:]]*:[[:space:]]*\"ok\""

    dashboards="$(wget -qO- "http://grafana.monitoring.svc.cluster.local:3000/api/search?query=Asteria")"
    printf "%s" "${dashboards}" | grep -q "Asteria AS-IS Nodes"

    printf "Prometheus targets up: %s\n" "${up_count}"
    printf "Grafana dashboard visible: Asteria AS-IS Nodes\n"
  '

for _ in $(seq 1 60); do
  phase="$(kubectl --namespace=monitoring get "pod/${pod_name}" \
    --output=jsonpath='{.status.phase}' 2>/dev/null || true)"
  case "${phase}" in
    Succeeded)
      kubectl --namespace=monitoring logs "pod/${pod_name}"
      printf 'M12 monitoring checks passed\n'
      exit 0
      ;;
    Failed)
      kubectl --namespace=monitoring logs "pod/${pod_name}" >&2 || true
      exit 1
      ;;
  esac
  sleep 2
done

kubectl --namespace=monitoring describe "pod/${pod_name}" >&2 || true
exit 1
