#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
ansible_root="${repo_root}/infra/ansible"
inventory="${ansible_root}/inventory/staging_terraform_inventory.sh"
playbook="${ansible_root}/playbooks/t07-kubernetes-foundation.yml"
ansible_playbook="${ASTERIA_ANSIBLE_PLAYBOOK:-${HOME}/.local/share/asteria/venvs/t06-ansible/bin/ansible-playbook}"

usage() {
  cat >&2 <<'USAGE'
Usage:
  scripts/t07-provision-kubernetes.sh preflight
  scripts/t07-provision-kubernetes.sh deploy
  scripts/t07-provision-kubernetes.sh validate
  scripts/t07-provision-kubernetes.sh idempotence

T07 cible uniquement les deux VM staging. Le cluster source n'est jamais
reconstruit par ce script.
USAGE
}

require_file() {
  [[ -x "$1" ]] || {
    printf 'STOP: exécutable absent: %s\n' "$1" >&2
    exit 1
  }
}

run_playbook() {
  ANSIBLE_CONFIG="${ansible_root}/ansible.cfg" \
  ANSIBLE_LOCAL_TEMP="${ansible_root}/.ansible/tmp" \
    "${ansible_playbook}" -i "${inventory}" "${playbook}" "$@"
}

preflight() {
  require_file "${ansible_playbook}"
  bash -n "${script_dir}/t07-provision-kubernetes.sh"
  bash -n "${script_dir}/t07-validate-kubernetes.sh"
  terraform -chdir="${repo_root}/infra/terraform/openstack-staging" fmt -check
  terraform -chdir="${repo_root}/infra/terraform/openstack-staging" validate
  run_playbook --syntax-check
}

case "${1:-}" in
  preflight)
    preflight
    ;;
  deploy)
    preflight
    run_playbook
    "${script_dir}/t07-validate-kubernetes.sh"
    ;;
  validate)
    "${script_dir}/t07-validate-kubernetes.sh"
    ;;
  idempotence)
    run_playbook
    ;;
  *)
    usage
    exit 64
    ;;
esac
