#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
source_tf_dir="${repo_root}/infra/terraform/openstack"
staging_tf_dir="${repo_root}/infra/terraform/openstack-staging"
ssh_key="${ASTERIA_SSH_PRIVATE_KEY_FILE:-${HOME}/.ssh/tp_cloud}"
known_hosts="${ASTERIA_SSH_KNOWN_HOSTS_FILE:-${HOME}/.local/share/asteria/known_hosts/t05-staging}"
namespace="t07-validation"

for command_name in jq ssh terraform; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'STOP: commande requise absente: %s\n' "${command_name}" >&2
    exit 1
  }
done

source_instances="$(terraform -chdir="${source_tf_dir}" output -json compute_instances)"
staging_instances="$(terraform -chdir="${staging_tf_dir}" output -json staging_instances)"
bastion_ip="$(jq -er '.bastion.access_ip_v4' <<<"${source_instances}")"
source_control_plane_ip="$(jq -er '.control_plane.access_ip_v4' <<<"${source_instances}")"
staging_control_plane_ip="$(jq -er '.control_plane.access_ip_v4' <<<"${staging_instances}")"

staging_ssh=(
  ssh
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o ConnectionAttempts=1
  -o "UserKnownHostsFile=${known_hosts}"
  -o StrictHostKeyChecking=accept-new
  -o "ProxyJump=ubuntu@${bastion_ip}"
  -i "${ssh_key}"
)

"${staging_ssh[@]}" "ubuntu@${staging_control_plane_ip}" \
  "sudo /bin/bash -s -- '${namespace}'" <<'REMOTE'
set -euo pipefail
namespace="$1"
kubectl=(/usr/local/bin/k3s kubectl)

trap 'status=$?; printf "FAIL: commande inattendue ligne %s (rc=%s)\n" "${LINENO}" "${status}" >&2; exit "${status}"' ERR

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ready_nodes="$("${kubectl[@]}" get nodes --no-headers | awk '$2 == "Ready" {count++} END {print count+0}')"
total_nodes="$("${kubectl[@]}" get nodes --no-headers | wc -l | tr -d ' ')"
[[ "${ready_nodes}" == 2 && "${total_nodes}" == 2 ]] || fail "topologie attendue 2/2 Ready absente"

"${kubectl[@]}" -n kube-system rollout status daemonset/cilium --timeout=30s >/dev/null
"${kubectl[@]}" -n kube-system rollout status deployment/cilium-operator --timeout=30s >/dev/null
"${kubectl[@]}" -n kube-system rollout status deployment/hubble-relay --timeout=30s >/dev/null

cilium_ready="$("${kubectl[@]}" -n kube-system get ds cilium -o jsonpath='{.status.numberReady}')"
cilium_desired="$("${kubectl[@]}" -n kube-system get ds cilium -o jsonpath='{.status.desiredNumberScheduled}')"
[[ "${cilium_ready}" == 2 && "${cilium_desired}" == 2 ]] || fail "Cilium n'est pas Ready sur les deux nœuds"

chart_version="$("${kubectl[@]}" -n kube-system get helmchart cilium -o jsonpath='{.spec.version}')"
[[ "${chart_version}" == 1.20.1 ]] || fail "version Cilium inattendue: ${chart_version}"

grep -qx 'flannel-backend: none' /etc/rancher/k3s/config.yaml || fail "Flannel non désactivé"
if ip link show flannel.1 >/dev/null 2>&1; then
  fail "interface Flannel encore présente"
fi
ip link show cilium_vxlan >/dev/null 2>&1 || fail "interface Cilium VXLAN absente"

ufw_status="$(ufw status verbose)"
grep -Fq 'Status: active' <<<"${ufw_status}" || fail "UFW inactif"
grep -Fq 'Default: deny (incoming), allow (outgoing), deny (routed)' \
  <<<"${ufw_status}" || fail "politique UFW inattendue"
for ufw_marker in \
  'Asteria T07 Cilium VXLAN' \
  'Asteria T07 Cilium health' \
  'Asteria T07 Hubble peer' \
  'Asteria T07 Pods vers API' \
  'Asteria T07 Pods vers kubelet' \
  'Asteria T07 Hubble relay vers agents'; do
  grep -Fq "${ufw_marker}" <<<"${ufw_status}" || \
    fail "règle UFW absente: ${ufw_marker}"
done

"${kubectl[@]}" -n "${namespace}" wait --for=condition=Available deployment/echo deployment/blocked --timeout=60s >/dev/null
"${kubectl[@]}" -n "${namespace}" wait --for=condition=Ready pod/client pod/storage-probe --timeout=60s >/dev/null

dns_result="$("${kubectl[@]}" -n "${namespace}" exec pod/client -- nslookup echo 2>&1 || true)"
grep -Eq "^Name:[[:space:]]+echo\.${namespace}\.svc\.cluster\.local" \
  <<<"${dns_result}" || fail "résolution DNS refusée"
grep -Eq '^Address:[[:space:]]+10\.43\.' \
  <<<"${dns_result}" || fail "adresse Service DNS inattendue"

allowed_result="$("${kubectl[@]}" -n "${namespace}" exec pod/client -- wget -qO- -T 5 http://echo:8080)"
[[ "${allowed_result}" == allowed-by-explicit-policy ]] || fail "flux explicite client vers echo refusé"

if "${kubectl[@]}" -n "${namespace}" exec pod/client -- wget -qO- -T 3 http://blocked:8080 >/dev/null 2>&1; then
  fail "flux client vers blocked autorisé malgré default-deny"
fi

observer="system:serviceaccount:${namespace}:t07-observer"
[[ "$("${kubectl[@]}" auth can-i list pods --as="${observer}" -n "${namespace}")" == yes ]] || fail "RBAC observateur ne peut pas lister les Pods"
[[ "$("${kubectl[@]}" auth can-i create pods --as="${observer}" -n "${namespace}")" == no ]] || fail "RBAC observateur peut créer des Pods"
[[ "$("${kubectl[@]}" auth can-i get secrets --as="${observer}" -n "${namespace}")" == no ]] || fail "RBAC observateur peut lire les Secrets"

storage_result="$("${kubectl[@]}" -n "${namespace}" exec pod/storage-probe -- cat /data/probe)"
[[ "${storage_result}" == t07-storage-ok ]] || fail "écriture local-path non validée"
[[ "$("${kubectl[@]}" -n "${namespace}" get pvc t07-local-path -o jsonpath='{.status.phase}')" == Bound ]] || fail "PVC non Bound"

psa_output="$({
  cat <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: t07-privileged-denied
  namespace: t07-validation
spec:
  containers:
    - name: denied
      image: busybox:1.37.0
      securityContext:
        privileged: true
YAML
} | "${kubectl[@]}" apply --dry-run=server -f - 2>&1 || true)"
grep -q 'violates PodSecurity' <<<"${psa_output}" || fail "PSA n'a pas refusé le Pod privilégié"

sleep 3
hubble_file="$(mktemp)"
trap 'rm -f "${hubble_file}"' EXIT
while IFS= read -r cilium_pod; do
  "${kubectl[@]}" -n kube-system exec "${cilium_pod}" -- \
    tail -n 2000 /var/run/cilium/hubble/events.log 2>/dev/null || true
done < <("${kubectl[@]}" -n kube-system get pods -l k8s-app=cilium -o name) >"${hubble_file}"

grep -q 't07-validation' "${hubble_file}" || fail "flux T07 absents de Hubble"
grep -Eq '"verdict"[[:space:]]*:[[:space:]]*"FORWARDED"' "${hubble_file}" || fail "succès absent de Hubble"
grep -Eq '"verdict"[[:space:]]*:[[:space:]]*"DROPPED"' "${hubble_file}" || fail "refus absent de Hubble"

"${kubectl[@]}" -n kube-system exec daemonset/cilium -- cilium-dbg status --brief >/dev/null
"${kubectl[@]}" get resourcequota,limitrange,networkpolicy -n "${namespace}"
"${kubectl[@]}" get nodes -o wide
"${kubectl[@]}" get pods -A -o wide
printf 'PASS: DNS, VXLAN inter-nœuds, allow/deny, Hubble, RBAC, PSA, quotas et stockage.\n'
REMOTE

source_ssh=(
  ssh
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o ConnectionAttempts=1
  -o StrictHostKeyChecking=accept-new
  -o "ProxyJump=ubuntu@${bastion_ip}"
  -i "${ssh_key}"
)

"${source_ssh[@]}" "ubuntu@${source_control_plane_ip}" \
  'set -eu; test "$(sudo k3s kubectl get nodes --no-headers | wc -l | tr -d " ")" = 3; ip link show flannel.1 >/dev/null; sudo k3s kubectl get nodes --no-headers'

for node_ip in \
  "$(jq -er '.control_plane.access_ip_v4' <<<"${staging_instances}")" \
  "$(jq -er '.worker.access_ip_v4' <<<"${staging_instances}")"; do
  "${staging_ssh[@]}" "ubuntu@${node_ip}" \
    'set -eu; sudo grep -qx "state=ready" /etc/asteria/t07-staging-managed; systemctl is-active --quiet teleport; test ! -e /home/ubuntu/.kube/config; ufw_status="$(sudo ufw status verbose)"; grep -Fq "Default: deny (incoming), allow (outgoing), deny (routed)" <<<"${ufw_status}"; for marker in "Asteria T07 Cilium VXLAN" "Asteria T07 Cilium health" "Asteria T07 Hubble peer" "Asteria T07 Pods vers kubelet" "Asteria T07 Hubble relay vers agents"; do grep -Fq "${marker}" <<<"${ufw_status}"; done; printf "HOST=%s " "$(hostname)"; free -m | awk "NR==2 {printf \"MEM_AVAILABLE_MB=%s \", \$7}"; systemctl show teleport --property=MemoryCurrent --value | awk "{printf \"TELEPORT_BYTES=%s \", \$1}"; if systemctl is-active --quiet k3s; then systemctl show k3s --property=MemoryCurrent --value | awk "{printf \"K3S_BYTES=%s\\n\", \$1}"; else systemctl show k3s-agent --property=MemoryCurrent --value | awk "{printf \"K3S_AGENT_BYTES=%s\\n\", \$1}"; fi'
done

printf 'PASS: cluster source AS-IS intact et capacité staging mesurée.\n'
