#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s ABSOLUTE_PRIVATE_REPORT_DIR [SSH_KEY]\n' "$0" >&2
}

if [[ $# -lt 1 || $# -gt 2 || "${1}" != /* ]]; then
  usage
  exit 64
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
tf_dir="${repo_root}/infra/terraform/openstack"
report_dir="${1%/}"
ssh_key="${2:-/home/youcef/.ssh/tp_cloud}"

case "${report_dir}/" in
  "${repo_root}/"*)
    printf 'Erreur: les rapports privés doivent rester hors du dépôt.\n' >&2
    exit 65
    ;;
esac

for command_name in git jq nc ssh stat terraform; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'Erreur: commande requise absente: %s\n' "${command_name}" >&2
    exit 69
  }
done

if [[ ! -f "${ssh_key}" ]]; then
  printf 'Erreur: clé SSH absente: %s\n' "${ssh_key}" >&2
  exit 66
fi

if [[ -e "${report_dir}" ]] && [[ -n "$(find "${report_dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  printf 'Erreur: destination non vide, aucun rapport ne sera écrasé.\n' >&2
  exit 73
fi

umask 077
install -d -m 0700 "${report_dir}/hosts"

instances_file="${report_dir}/compute-instances.json"
terraform -chdir="${tf_dir}" output -json compute_instances >"${instances_file}"
chmod 0600 "${instances_file}"

bastion_ip="$(jq -r '.bastion.access_ip_v4' "${instances_file}")"
ssh_user="${ASTERIA_SSH_USER:-ubuntu}"
common_ssh=(
  -o BatchMode=yes
  -o ConnectTimeout=12
  -o ServerAliveInterval=5
  -o ServerAliveCountMax=2
  -o StrictHostKeyChecking=yes
  -i "${ssh_key}"
)

{
  printf 'created_utc=%s\n' "$(date -u +%FT%TZ)"
  printf 'git_commit=%s\n' "$(git -C "${repo_root}" rev-parse HEAD)"
  printf 'git_dirty_files=%s\n' "$(git -C "${repo_root}" status --short | wc -l | tr -d ' ')"
  printf 'terraform_version=%s\n' "$(terraform version -json | jq -r '.terraform_version')"
  printf 'terraform_state_mode=%s\n' "$(stat -c '%a' "${tf_dir}/terraform.tfstate")"
  printf 'kubectl_client=%s\n' "$(kubectl version --client=true 2>/dev/null | head -n 1 || printf 'absent')"
  printf 'helm_client=%s\n' "$(helm version --short 2>/dev/null || printf 'absent')"
  printf 'ansible_client=%s\n' "$(ansible --version 2>/dev/null | head -n 1 || printf 'absent')"
} >"${report_dir}/controller.txt"

printf 'role\tssh\tdirect_ssh\tntp\tclock_delta_s\tsudo\tservice\thealth\n' \
  >"${report_dir}/checks.tsv"

remote_base='set -uo pipefail
printf "HOSTNAME=%s\n" "$(hostname)"
printf "UTC=%s\n" "$(date -u +%FT%TZ)"
printf "EPOCH=%s\n" "$(date -u +%s)"
timedatectl show --property=NTP --property=NTPSynchronized --property=Timezone
timedatectl timesync-status --no-pager 2>/dev/null || true
printf "TIMESYNCD_ACTIVE=%s\n" "$(systemctl is-active systemd-timesyncd 2>/dev/null || true)"
printf "ROOT_FS_USE_PERCENT=%s\n" "$(df -P / | awk "NR==2 {gsub(/%/,\"\",\$5); print \$5}")"
printf "KERNEL=%s\n" "$(uname -r)"
. /etc/os-release
printf "OS=%s %s\n" "$NAME" "$VERSION_ID"
if sudo -n true 2>/dev/null; then printf "SUDO_NON_INTERACTIVE=yes\n"; else printf "SUDO_NON_INTERACTIVE=no\n"; fi'

roles=(bastion control_plane worker_01 worker_02 postgres)
failures=0
worker_01_ip="$(jq -r '.worker_01.access_ip_v4' "${instances_file}")"

for role in "${roles[@]}"; do
  host_ip="$(jq -r --arg role "${role}" '.[$role].access_ip_v4' "${instances_file}")"
  report_file="${report_dir}/hosts/${role}.txt"
  error_file="${report_dir}/hosts/${role}.stderr"
  direct_error_file="${report_dir}/hosts/${role}.direct.stderr"
  ssh_args=("${common_ssh[@]}")
  if [[ "${role}" != bastion ]]; then
    ssh_args+=(-J "${ssh_user}@${bastion_ip}")
  fi

  role_command="${remote_base}"
  service_name=none
  health_check=not_applicable
  direct_ssh=allowed
  if [[ "${role}" != bastion ]]; then
    if ssh -F /dev/null "${common_ssh[@]}" "${ssh_user}@${host_ip}" true \
      >/dev/null 2>"${direct_error_file}"; then
      direct_ssh=unexpected_authenticated
    elif grep -qi 'Permission denied' "${direct_error_file}"; then
      direct_ssh=auth_denied
    elif nc -z -w 3 "${host_ip}" 22 >/dev/null 2>&1; then
      direct_ssh=handshake_inconclusive
    else
      direct_ssh=transport_blocked
    fi
  fi
  case "${role}" in
    control_plane)
      service_name=k3s
      role_command+="
ASTERIA_WORKER_01_IP='${worker_01_ip}'"
      role_command+='
printf "ROLE_SERVICE=%s\n" "$(systemctl is-active k3s 2>/dev/null || true)"
printf "K3S_VERSION=%s\n" "$(sudo -n k3s --version 2>/dev/null | head -n 1 || true)"
nodes_output="$(sudo -n k3s kubectl get nodes --no-headers 2>/dev/null || true)"
printf "K3S_READY_NODES=%s\n" "$(printf "%s\n" "$nodes_output" | grep -cE "[[:space:]]Ready[[:space:]]" || true)"
printf "K3S_TOTAL_NODES=%s\n" "$(printf "%s\n" "$nodes_output" | grep -c . || true)"
printf "KUBERNETES_SERVER_VERSION=%s\n" "$(sudo -n k3s kubectl version 2>/dev/null | tail -n 1 || true)"
printf "KUBERNETES_NODES_BEGIN\n"
printf "%s\n" "$nodes_output"
printf "KUBERNETES_NODES_END\n"
sudo -n k3s kubectl get pods -A -o wide 2>&1 || true
printf "KUBERNETES_IMAGES_BEGIN\n"
sudo -n k3s kubectl get pods -A -o "custom-columns=NAMESPACE:.metadata.namespace,POD:.metadata.name,IMAGES:.spec.containers[*].image" 2>/dev/null || true
printf "KUBERNETES_IMAGES_END\n"
'
      ;;
    worker_01|worker_02)
      service_name=k3s-agent
      role_command+=$'\nprintf "ROLE_SERVICE=%s\n" "$(systemctl is-active k3s-agent 2>/dev/null || true)"\nprintf "K3S_VERSION=%s\n" "$(sudo -n k3s --version | head -n 1)"'
      ;;
    postgres)
      service_name=postgresql
      role_command+=$'\nprintf "ROLE_SERVICE=%s\n" "$(systemctl is-active postgresql 2>/dev/null || true)"\nprintf "POSTGRES_READY=%s\n" "$(pg_isready -q && printf yes || printf no)"\nprintf "POSTGRES_VERSION=%s\n" "$(sudo -n -u postgres psql --no-psqlrc --tuples-only --no-align --command="show server_version")"\nprintf "POSTGRES_REPLICAS=%s\n" "$(sudo -n -u postgres psql --no-psqlrc --tuples-only --no-align --command="select count(*) from pg_stat_replication")"'
      ;;
    bastion)
      role_command+=$'\nprintf "ROLE_SERVICE=not_applicable\n"\nprintf "KUBECTL_CLIENT=%s\n" "$(kubectl version --client=true 2>/dev/null | head -n 1 || printf absent)"'
      ;;
  esac

  local_epoch_before="$(date -u +%s)"
  if ! ssh "${ssh_args[@]}" "${ssh_user}@${host_ip}" "${role_command}" >"${report_file}" 2>"${error_file}"; then
    printf '%s\tfail\t%s\tunknown\tunknown\tunknown\t%s\tunreachable\n' \
      "${role}" "${direct_ssh}" "${service_name}" \
      >>"${report_dir}/checks.tsv"
    printf 'ECHEC: %s inaccessible; détail dans le rapport privé.\n' "${role}" >&2
    failures=$((failures + 1))
    continue
  fi

  if [[ "${role}" != bastion ]]; then
    printf 'SSHD_ALLOW_USERS=%s\n' \
      "$(ssh "${ssh_args[@]}" "${ssh_user}@${host_ip}" \
        'sudo -n sshd -T 2>/dev/null | grep -E "^allowusers " | head -n 1 || true')" \
      >>"${report_file}"
  fi

  remote_epoch="$(sed -n 's/^EPOCH=//p' "${report_file}")"
  local_epoch_after="$(date -u +%s)"
  if ((remote_epoch < local_epoch_before)); then
    clock_delta=$((local_epoch_before - remote_epoch))
  elif ((remote_epoch > local_epoch_after)); then
    clock_delta=$((remote_epoch - local_epoch_after))
  else
    clock_delta=0
  fi
  printf 'CLOCK_DELTA_SECONDS=%s\n' "${clock_delta}" >>"${report_file}"

  ntp_value="$(sed -n 's/^NTPSynchronized=//p' "${report_file}")"
  sudo_value="$(sed -n 's/^SUDO_NON_INTERACTIVE=//p' "${report_file}")"
  service_value="$(sed -n 's/^ROLE_SERVICE=//p' "${report_file}")"

  case "${role}" in
    control_plane)
      ready_nodes="$(sed -n 's/^K3S_READY_NODES=//p' "${report_file}")"
      total_nodes="$(sed -n 's/^K3S_TOTAL_NODES=//p' "${report_file}")"
      [[ "${ready_nodes}" == 3 && "${total_nodes}" == 3 ]] && health_check=ready || health_check=degraded
      ;;
    postgres)
      health_check="$(sed -n 's/^POSTGRES_READY=//p' "${report_file}")"
      ;;
  esac

  printf '%s\tpass\t%s\t%s\t%s\t%s\t%s:%s\t%s\n' \
    "${role}" "${direct_ssh}" "${ntp_value:-unknown}" "${clock_delta}" \
    "${sudo_value:-unknown}" "${service_name}" "${service_value:-unknown}" \
    "${health_check}" >>"${report_dir}/checks.tsv"
done

chmod -R go-rwx "${report_dir}"

if ((failures > 0)); then
  printf 'ECHEC: %s hôte(s) inaccessible(s).\n' "${failures}" >&2
  exit 2
fi

printf 'OK: inventaire privé collecté sur 5 hôtes.\n'
printf 'destination=%s\n' "${report_dir}"
