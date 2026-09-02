#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s SECONDARY_OPENRC --apply\n' "$0" >&2
}

if [[ $# -ne 2 || "$2" != "--apply" ]]; then
  usage
  exit 64
fi

openrc_path="$1"
[[ -f "${openrc_path}" ]] || {
  printf 'Erreur: OpenRC absent: %s\n' "${openrc_path}" >&2
  exit 2
}

for command_name in jq openstack terraform; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'Erreur: commande requise absente: %s\n' "${command_name}" >&2
    exit 3
  }
done

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
source_tf_dir="${repo_root}/infra/terraform/openstack"
staging_tf_dir="${repo_root}/infra/terraform/openstack-staging"
plan_name="t05-staging.tfplan"

umask 077

# L'OpenRC demande le mot de passe silencieusement dans le terminal opérateur.
# shellcheck disable=SC1090
source "${openrc_path}"

: "${OS_PROJECT_ID:?OS_PROJECT_ID absent après chargement OpenRC}"
export TF_VAR_expected_project_id="${OS_PROJECT_ID}"
export TF_VAR_source_bastion_cidr
TF_VAR_source_bastion_cidr="$(
  terraform -chdir="${source_tf_dir}" output -json compute_instances |
    jq -er '.bastion.access_ip_v4 + "/32"'
)"

limits_json="$(openstack limits show --absolute -f json)"
limit_value() {
  jq -er --arg name "$1" '.[] | select(.Name == $name) | .Value' \
    <<<"${limits_json}"
}

max_instances="$(limit_value maxTotalInstances)"
max_cores="$(limit_value maxTotalCores)"
max_ram="$(limit_value maxTotalRAMSize)"
used_instances="$(limit_value totalInstancesUsed)"
used_cores="$(limit_value totalCoresUsed)"
used_ram="$(limit_value totalRAMUsed)"

if [[ "${max_instances}" != 4 || "${max_cores}" != 4 || "${max_ram}" != 8192 ]]; then
  printf 'STOP: profil de quotas différent de CAP-05 (VM=%s, vCPU=%s, RAM=%s).\n' \
    "${max_instances}" "${max_cores}" "${max_ram}" >&2
  exit 10
fi

if [[ "${used_instances}" != 0 || "${used_cores}" != 0 || "${used_ram}" != 0 ]]; then
  printf 'STOP: projet secondaire non vide (VM=%s, vCPU=%s, RAM=%s).\n' \
    "${used_instances}" "${used_cores}" "${used_ram}" >&2
  exit 11
fi

server_count="$(openstack server list -f value -c ID | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
compute_port_count="$(
  openstack port list --device-owner compute:nova -f value -c ID |
    sed '/^[[:space:]]*$/d' |
    wc -l |
    tr -d ' '
)"

if [[ "${server_count}" != 0 || "${compute_port_count}" != 0 ]]; then
  printf 'STOP: ressources compute inattendues (VM=%s, ports=%s).\n' \
    "${server_count}" "${compute_port_count}" >&2
  exit 12
fi

terraform -chdir="${staging_tf_dir}" init -input=false
terraform -chdir="${staging_tf_dir}" fmt -check -recursive
terraform -chdir="${staging_tf_dir}" validate
terraform -chdir="${staging_tf_dir}" plan -input=false -out="${plan_name}"
chmod 0600 "${staging_tf_dir}/${plan_name}"

plan_json="$(terraform -chdir="${staging_tf_dir}" show -json "${plan_name}")"
create_count="$(jq '[.resource_changes[] | select(.change.actions == ["create"])] | length' <<<"${plan_json}")"
unexpected_count="$(jq '[.resource_changes[] | select(.change.actions != ["create"])] | length' <<<"${plan_json}")"
probe_count="$(jq '[.resource_changes[] | select(.address | contains("probe_from_bastion"))] | length' <<<"${plan_json}")"

if [[ "${create_count}" != 14 || "${unexpected_count}" != 0 || "${probe_count}" != 0 ]]; then
  printf 'STOP: impact inattendu (create=%s, autres=%s, probe=%s).\n' \
    "${create_count}" "${unexpected_count}" "${probe_count}" >&2
  exit 20
fi

printf 'GATE T05 PASS: projet secondaire vide, CAP-05, 14 créations, aucune destruction.\n'
terraform -chdir="${staging_tf_dir}" apply -input=false "${plan_name}"
chmod 0600 "${staging_tf_dir}/terraform.tfstate"
terraform -chdir="${staging_tf_dir}" output -json staging_instances |
  jq '{control_plane: .control_plane.name, worker: .worker.name, statuses: [.control_plane.status, .worker.status]}'
