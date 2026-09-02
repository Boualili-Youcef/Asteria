#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s PRIVATE_REPORT_DIR PRIVATE_BACKUP_DIR\n' "$0" >&2
}

if [[ $# -ne 2 ]]; then
  usage
  exit 64
fi

report_dir="${1%/}"
backup_dir="${2%/}"
failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

pass() {
  printf 'PASS: %s\n' "$1"
}

[[ -f "${report_dir}/checks.tsv" ]] || {
  printf 'FAIL: rapport checks.tsv absent.\n' >&2
  exit 2
}

host_count="$(tail -n +2 "${report_dir}/checks.tsv" | wc -l | tr -d ' ')"
[[ "${host_count}" == 5 ]] && pass 'cinq hôtes inventoriés' || fail "hôtes inventoriés=${host_count}, attendu=5"

while IFS=$'\t' read -r role ssh_status direct_ssh ntp_status clock_delta sudo_status service_status health_status; do
  [[ "${role}" == role ]] && continue
  [[ "${ssh_status}" == pass ]] || fail "${role}: SSH"
  if [[ "${role}" == bastion ]]; then
    [[ "${direct_ssh}" == allowed ]] || fail "${role}: SSH direct=${direct_ssh}"
  else
    [[ "${direct_ssh}" == auth_denied || "${direct_ssh}" == transport_blocked ]] \
      || fail "${role}: SSH direct=${direct_ssh}"
  fi
  [[ "${ntp_status}" == yes ]] || fail "${role}: NTPSynchronized=${ntp_status}"
  [[ "${clock_delta}" =~ ^[0-9]+$ && "${clock_delta}" -le 1 ]] || fail "${role}: écart horloge=${clock_delta}s"
  [[ "${sudo_status}" == yes ]] || fail "${role}: sudo break-glass non fonctionnel"
  root_use="$(sed -n 's/^ROOT_FS_USE_PERCENT=//p' "${report_dir}/hosts/${role}.txt")"
  [[ "${root_use}" =~ ^[0-9]+$ && "${root_use}" -le 85 ]] \
    || fail "${role}: filesystem racine=${root_use}%"
  timesyncd_status="$(sed -n 's/^TIMESYNCD_ACTIVE=//p' "${report_dir}/hosts/${role}.txt")"
  [[ "${timesyncd_status}" == active ]] || fail "${role}: systemd-timesyncd=${timesyncd_status}"
  case "${role}" in
    control_plane)
      [[ "${service_status}" == k3s:active ]] || fail "${role}: ${service_status}"
      [[ "${health_status}" == ready ]] || fail "${role}: nœuds ${health_status}"
      ;;
    worker_01|worker_02)
      [[ "${service_status}" == k3s-agent:active ]] || fail "${role}: ${service_status}"
      ;;
    postgres)
      [[ "${service_status}" == postgresql:active ]] || fail "${role}: ${service_status}"
      [[ "${health_status}" == yes ]] || fail "${role}: pg_isready=${health_status}"
      ;;
  esac
done <"${report_dir}/checks.tsv"

bastion_ip="$(jq -r '.bastion.access_ip_v4' "${report_dir}/compute-instances.json")"
allow_users_ok=yes
for role in control_plane worker_01 worker_02 postgres; do
  allow_users="$(sed -n 's/^SSHD_ALLOW_USERS=//p' "${report_dir}/hosts/${role}.txt")"
  if [[ "${allow_users}" != "allowusers ubuntu@${bastion_ip}" ]]; then
    fail "${role}: AllowUsers compensatoire invalide"
    allow_users_ok=no
  fi
done
[[ "${allow_users_ok}" == yes ]] && pass 'AllowUsers limité au bastion contrôlé sur quatre VM'

state_mode="$(sed -n 's/^terraform_state_mode=//p' "${report_dir}/controller.txt")"
[[ "${state_mode}" == 600 ]] && pass 'state Terraform en mode 0600' || fail "mode state Terraform=${state_mode}"

for archive_name in terraform/terraform.tfstate terraform/SHA256SUMS postgresql.tar.gz k3s.tar.gz SHA256SUMS; do
  [[ -s "${backup_dir}/${archive_name}" ]] || fail "backup absent: ${archive_name}"
done

for private_name in postgresql.tar.gz k3s.tar.gz SHA256SUMS; do
  if [[ ! -e "${backup_dir}/${private_name}" ]]; then
    continue
  fi
  private_mode="$(stat -c '%a' "${backup_dir}/${private_name}")"
  [[ "${private_mode}" == 600 ]] \
    || fail "mode backup ${private_name}=${private_mode}"
done

if [[ -f "${backup_dir}/SHA256SUMS" ]]; then
  (cd "${backup_dir}" && sha256sum --check SHA256SUMS >/dev/null) \
    && pass 'checksums des archives runtime' \
    || fail 'checksums des archives runtime'
fi

if [[ -f "${backup_dir}/terraform/SHA256SUMS" ]]; then
  (cd "${backup_dir}/terraform" && sha256sum --check SHA256SUMS >/dev/null) \
    && pass 'checksums du state Terraform' \
    || fail 'checksums du state Terraform'
fi

if ((failures > 0)); then
  printf 'RESULTAT: FAIL (%s contrôle(s))\n' "${failures}" >&2
  exit 1
fi

printf 'RESULTAT: PASS T04 foundations\n'
