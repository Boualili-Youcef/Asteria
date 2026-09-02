#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || "$1" != "--run" ]]; then
  printf 'Usage: %s --run\n' "$0" >&2
  exit 64
fi

for command_name in jq ssh terraform timeout; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'Erreur: commande requise absente: %s\n' "${command_name}" >&2
    exit 3
  }
done

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
source_tf_dir="${repo_root}/infra/terraform/openstack"
staging_tf_dir="${repo_root}/infra/terraform/openstack-staging"
ssh_key="${ASTERIA_SSH_PRIVATE_KEY_FILE:-${HOME}/.ssh/tp_cloud}"
known_hosts="${ASTERIA_SSH_KNOWN_HOSTS_FILE:-${HOME}/.local/share/asteria/known_hosts/t05-staging}"
probe_port=18080

bastion_ip="$(
  terraform -chdir="${source_tf_dir}" output -json compute_instances |
    jq -er '.bastion.access_ip_v4'
)"
control_plane_ip="$(
  terraform -chdir="${staging_tf_dir}" output -json staging_instances |
    jq -er '.control_plane.access_ip_v4'
)"

ssh_staging=(
  ssh -o BatchMode=yes -o ConnectTimeout=10
  -o "UserKnownHostsFile=${known_hosts}" -o StrictHostKeyChecking=yes
  -o "ProxyJump=ubuntu@${bastion_ip}" -i "${ssh_key}"
  "ubuntu@${control_plane_ip}"
)
ssh_bastion=(
  ssh -o BatchMode=yes -o ConnectTimeout=10 -i "${ssh_key}"
  "ubuntu@${bastion_ip}"
)

delete_probe_rule() {
  "${ssh_staging[@]}" sudo ufw delete allow \
    from "${bastion_ip}" to any port "${probe_port}" proto tcp \
    >/dev/null 2>&1 || true
}

stop_listener() {
  "${ssh_staging[@]}" \
    'sudo systemctl stop asteria-t05-probe.service 2>/dev/null || true; sudo systemctl reset-failed asteria-t05-probe.service 2>/dev/null || true' \
    >/dev/null 2>&1 || true
}

cleanup() {
  delete_probe_rule
  stop_listener
}
trap cleanup EXIT

cleanup
"${ssh_staging[@]}" sudo systemd-run \
  --unit=asteria-t05-probe --property=RuntimeMaxSec=300 --collect -- \
  /usr/bin/python3 -m http.server "${probe_port}" --bind 0.0.0.0 \
  >/dev/null
sleep 2
"${ssh_staging[@]}" sudo systemctl is-active --quiet asteria-t05-probe.service

test_from_bastion() {
  "${ssh_bastion[@]}" \
    "timeout 6 bash -c '</dev/tcp/${control_plane_ip}/${probe_port}'" \
    >/dev/null 2>&1
}

test_from_controller() {
  timeout 6 bash -c "</dev/tcp/${control_plane_ip}/${probe_port}" \
    >/dev/null 2>&1
}

if test_from_bastion || test_from_controller; then
  printf 'FAIL: le port est joignable avant la règle UFW temporaire.\n' >&2
  exit 20
fi
printf 'PASS: refus initial depuis le bastion et le contrôleur.\n'

"${ssh_staging[@]}" sudo ufw allow \
  from "${bastion_ip}" to any port "${probe_port}" proto tcp \
  comment Asteria-T05-temporary-probe >/dev/null

if ! test_from_bastion; then
  printf 'FAIL: le bastion ne joint pas le listener après la règle UFW.\n' >&2
  exit 21
fi
if test_from_controller; then
  printf 'FAIL: le contrôleur contourne la règle limitée au bastion.\n' >&2
  exit 22
fi
printf 'PASS: succès limité au bastion pendant la règle temporaire.\n'

delete_probe_rule
if test_from_bastion || test_from_controller; then
  printf 'FAIL: le port reste joignable après rollback UFW.\n' >&2
  exit 23
fi

stop_listener
trap - EXIT
printf 'PASS: refus initial, succès contrôlé et refus après rollback sur TCP/%s.\n' \
  "${probe_port}"
