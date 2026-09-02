#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || "$1" != /* ]]; then
  printf 'Usage: %s ABSOLUTE_BACKUP_DIR\n' "$0" >&2
  exit 64
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
tf_dir="${repo_root}/infra/terraform/openstack-staging"
backup_dir="${1%/}"

case "${backup_dir}/" in
  "${repo_root}/"*)
    printf 'Erreur: la sauvegarde T05 doit rester hors du dépôt.\n' >&2
    exit 65
    ;;
esac

if [[ -e "${backup_dir}" ]] && [[ -n "$(find "${backup_dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  printf 'Erreur: destination non vide.\n' >&2
  exit 73
fi

state_path="${tf_dir}/terraform.tfstate"
[[ -f "${state_path}" ]] || {
  printf 'Erreur: state staging absent.\n' >&2
  exit 66
}

relative_state="${state_path#${repo_root}/}"
if git -C "${repo_root}" ls-files --error-unmatch -- "${relative_state}" >/dev/null 2>&1; then
  printf 'Erreur: le state staging est suivi par Git.\n' >&2
  exit 67
fi

umask 077
install -d -m 0700 "${backup_dir}"
chmod 0600 "${state_path}"

terraform -chdir="${tf_dir}" state pull >"${backup_dir}/terraform.tfstate"
jq -e '.version and .serial >= 0 and (.resources | type == "array")' \
  "${backup_dir}/terraform.tfstate" >/dev/null
install -m 0600 "${tf_dir}/.terraform.lock.hcl" \
  "${backup_dir}/terraform.lock.hcl"
chmod 0600 "${backup_dir}/terraform.tfstate"

state_serial="$(jq -r '.serial' "${backup_dir}/terraform.tfstate")"
managed_count="$(terraform -chdir="${tf_dir}" state list | awk '!/^data\./' | wc -l | tr -d ' ')"
data_count="$(terraform -chdir="${tf_dir}" state list | awk '/^data\./' | wc -l | tr -d ' ')"

{
  printf 'created_utc=%s\n' "$(date -u +%FT%TZ)"
  printf 'git_commit=%s\n' "$(git -C "${repo_root}" rev-parse HEAD)"
  printf 'git_worktree_dirty=%s\n' "$(git -C "${repo_root}" diff --quiet && printf no || printf yes)"
  printf 'terraform_version=%s\n' "$(terraform version -json | jq -r '.terraform_version')"
  printf 'state_serial=%s\n' "${state_serial}"
  printf 'managed_resources=%s\n' "${managed_count}"
  printf 'data_sources=%s\n' "${data_count}"
  printf 'source_mode=%s\n' "$(stat -c '%a' "${state_path}")"
} >"${backup_dir}/METADATA"
chmod 0600 "${backup_dir}/METADATA"

(
  cd "${backup_dir}"
  sha256sum terraform.tfstate terraform.lock.hcl METADATA >SHA256SUMS
  chmod 0600 SHA256SUMS
  sha256sum --check SHA256SUMS >/dev/null
)

printf 'OK: state T05 sauvegardé hors Git.\n'
printf 'destination=%s serial=%s managed=%s data=%s\n' \
  "${backup_dir}" "${state_serial}" "${managed_count}" "${data_count}"
