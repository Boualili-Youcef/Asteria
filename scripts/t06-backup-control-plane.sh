#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
source_tf_dir="${repo_root}/infra/terraform/openstack"
ssh_key="${ASTERIA_SSH_PRIVATE_KEY_FILE:-${HOME}/.ssh/tp_cloud}"
backup_root="${1:-${HOME}/.local/share/asteria/backups}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="${backup_root}/t06-${timestamp}"
remote_dir="/var/backups/asteria-t06-teleport/${timestamp}"

if [[ "${backup_root}" != /* ]]; then
  printf 'STOP: le répertoire de backup doit être absolu.\n' >&2
  exit 1
fi
if [[ "${backup_root}" == "${repo_root}" || "${backup_root}" == "${repo_root}/"* ]]; then
  printf 'STOP: le backup sensible doit rester hors Git.\n' >&2
  exit 1
fi
for command_name in jq sha256sum ssh terraform; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'STOP: commande requise absente: %s\n' "${command_name}" >&2
    exit 1
  }
done
[[ -r "${ssh_key}" ]] || {
  printf 'STOP: clé SSH absente ou illisible.\n' >&2
  exit 1
}

bastion_ip="$(
  terraform -chdir="${source_tf_dir}" output -json compute_instances \
    | jq -r '.bastion.access_ip_v4'
)"
[[ "${bastion_ip}" =~ ^[0-9.]+$ ]] || {
  printf 'STOP: adresse du bastion introuvable.\n' >&2
  exit 1
}

ssh_args=(
  -F /dev/null
  -i "${ssh_key}"
  -o IdentitiesOnly=yes
  -o BatchMode=yes
  -o ConnectTimeout=30
  -o StrictHostKeyChecking=yes
)

install -d -m 0700 "${backup_dir}"
ssh "${ssh_args[@]}" "ubuntu@${bastion_ip}" "
  set -e
  sudo install -d -o root -g root -m 0700 '${remote_dir}/backend-clone'
  printf '%s\n' \
    'src:' \
    '  type: sqlite' \
    '  path: /var/lib/teleport/backend' \
    'dst:' \
    '  type: sqlite' \
    '  path: ${remote_dir}/backend-clone' \
    'parallel: 10' \
    'force: false' \
    | sudo tee '${remote_dir}/clone.yaml' >/dev/null
  sudo chmod 0600 '${remote_dir}/clone.yaml'
  sudo teleport backend clone --config='${remote_dir}/clone.yaml'
  sudo tar --acls --xattrs --numeric-owner \
    --exclude=/var/lib/teleport/debug.sock \
    -czf '${remote_dir}/teleport-control-plane.tar.gz' \
    '${remote_dir}/backend-clone' \
    /etc/teleport.yaml /etc/teleport-tls /etc/teleport-resources \
    /etc/systemd/system/teleport.service /var/lib/teleport
  sudo sha256sum '${remote_dir}/teleport-control-plane.tar.gz' \
    | sudo tee '${remote_dir}/SHA256SUMS' >/dev/null
  sudo chmod 0600 '${remote_dir}/teleport-control-plane.tar.gz' \
    '${remote_dir}/SHA256SUMS'
"

umask 077
ssh "${ssh_args[@]}" "ubuntu@${bastion_ip}" \
  "sudo cat '${remote_dir}/teleport-control-plane.tar.gz'" \
  >"${backup_dir}/teleport-control-plane.tar.gz"
install -m 0600 "${source_tf_dir}/terraform.tfstate" \
  "${backup_dir}/terraform-source.tfstate"
install -m 0600 "${source_tf_dir}/.terraform.lock.hcl" \
  "${backup_dir}/terraform-source.lock.hcl"
(
  cd "${backup_dir}"
  sha256sum teleport-control-plane.tar.gz terraform-source.tfstate \
    terraform-source.lock.hcl >SHA256SUMS
  chmod 0600 SHA256SUMS
  sha256sum --check SHA256SUMS
)

printf 'Backup T06 protégé et vérifié: %s\n' "${backup_dir}"
printf 'Copie distante conservée: %s\n' "${remote_dir}"
