#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s ABSOLUTE_BACKUP_DIR\n' "$0" >&2
}

if [[ $# -ne 1 || "${1}" != /* ]]; then
  usage
  exit 64
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
tf_dir="${repo_root}/infra/terraform/openstack"
backup_dir="${1%/}"

case "${backup_dir}/" in
  "${repo_root}/"*)
    printf 'Erreur: la sauvegarde Terraform doit rester hors du dépôt.\n' >&2
    exit 65
    ;;
esac

for command_name in git jq sha256sum stat terraform; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'Erreur: commande requise absente: %s\n' "${command_name}" >&2
    exit 69
  }
done

if [[ -e "${backup_dir}" ]] && [[ -n "$(find "${backup_dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  printf 'Erreur: destination non vide, aucun fichier ne sera écrasé.\n' >&2
  exit 73
fi

umask 077
install -d -m 0700 "${backup_dir}"

shopt -s nullglob
sensitive_files=(
  "${tf_dir}"/*.tfstate
  "${tf_dir}"/*.tfstate.*
  "${tf_dir}"/*.tfplan
  "${tf_dir}"/*.tfvars
  "${tf_dir}"/*.tfvars.json
)

if [[ ${#sensitive_files[@]} -eq 0 ]]; then
  printf 'Erreur: aucun state Terraform local trouvé.\n' >&2
  exit 66
fi

for sensitive_file in "${sensitive_files[@]}"; do
  relative_path="${sensitive_file#${repo_root}/}"
  if git -C "${repo_root}" ls-files --error-unmatch -- "${relative_path}" >/dev/null 2>&1; then
    printf 'Erreur: artefact Terraform sensible suivi par Git: %s\n' "${relative_path}" >&2
    exit 67
  fi
done

chmod 0600 "${sensitive_files[@]}"

terraform -chdir="${tf_dir}" state pull >"${backup_dir}/terraform.tfstate"
jq -e '.version and .serial >= 0 and (.resources | type == "array")' \
  "${backup_dir}/terraform.tfstate" >/dev/null

cp -- "${tf_dir}/.terraform.lock.hcl" "${backup_dir}/terraform.lock.hcl"
chmod 0600 "${backup_dir}/terraform.tfstate" "${backup_dir}/terraform.lock.hcl"

state_serial="$(jq -r '.serial' "${backup_dir}/terraform.tfstate")"
resource_count="$(terraform -chdir="${tf_dir}" state list | wc -l | tr -d ' ')"
git_commit="$(git -C "${repo_root}" rev-parse HEAD)"

{
  printf 'created_utc=%s\n' "$(date -u +%FT%TZ)"
  printf 'git_commit=%s\n' "${git_commit}"
  printf 'terraform_version=%s\n' "$(terraform version -json | jq -r '.terraform_version')"
  printf 'state_serial=%s\n' "${state_serial}"
  printf 'resource_count=%s\n' "${resource_count}"
  printf 'source_permissions_after=%s\n' "$(stat -c '%a' "${tf_dir}/terraform.tfstate")"
} >"${backup_dir}/METADATA"

(
  cd "${backup_dir}"
  sha256sum terraform.tfstate terraform.lock.hcl METADATA >SHA256SUMS
  sha256sum --check SHA256SUMS >/dev/null
)

printf 'OK: state Terraform protégé et sauvegardé hors Git.\n'
printf 'destination=%s\n' "${backup_dir}"
printf 'source_mode=%s resources=%s serial=%s\n' \
  "$(stat -c '%a' "${tf_dir}/terraform.tfstate")" \
  "${resource_count}" \
  "${state_serial}"
