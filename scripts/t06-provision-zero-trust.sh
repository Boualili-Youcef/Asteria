#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
source_tf_dir="${repo_root}/infra/terraform/openstack"
staging_tf_dir="${repo_root}/infra/terraform/openstack-staging"
inventory="${repo_root}/infra/ansible/inventory/t06_terraform_inventory.sh"
control_playbook="${repo_root}/infra/ansible/playbooks/t06-teleport-control-plane.yml"
kube_playbook="${repo_root}/infra/ansible/playbooks/t06-kubernetes-rbac.yml"
postgres_playbook="${repo_root}/infra/ansible/playbooks/t06-postgresql-mtls.yml"
agents_playbook="${repo_root}/infra/ansible/playbooks/t06-teleport-agents.yml"
plan_file="${source_tf_dir}/t06-network.tfplan"
plan_meta="${plan_file}.meta"
staging_vars="${source_tf_dir}/t06-staging-agents.auto.tfvars.json"
t06_pki_dir="${ASTERIA_T06_PKI_DIR:-${HOME}/.local/share/asteria/t06-pki}"
ansible_playbook="${ASTERIA_ANSIBLE_PLAYBOOK:-${HOME}/.local/share/asteria/venvs/t06-ansible/bin/ansible-playbook}"
ssh_key="${ASTERIA_SSH_PRIVATE_KEY_FILE:-${HOME}/.ssh/tp_cloud}"

usage() {
  cat >&2 <<'USAGE'
Usage:
  scripts/t06-provision-zero-trust.sh prepare
  scripts/t06-provision-zero-trust.sh plan
  scripts/t06-provision-zero-trust.sh apply
  scripts/t06-provision-zero-trust.sh deploy
  ASTERIA_T06_AGENT_LIMIT=<hôte> scripts/t06-provision-zero-trust.sh resume-agent
  scripts/t06-provision-zero-trust.sh validate

Ordre obligatoire: prepare -> plan -> examen humain -> apply -> deploy -> validate.
Le plan/apply exige le bon OpenRC source déjà chargé dans le shell.
USAGE
}

require_commands() {
  local command_name
  for command_name in "$@"; do
    command -v "${command_name}" >/dev/null 2>&1 || {
      printf 'STOP: commande requise absente: %s\n' "${command_name}" >&2
      exit 1
    }
  done
}

tf_code_digest() {
  (
    cd "${source_tf_dir}"
    rg --files -g '*.tf' | sort | xargs sha256sum
  ) | sha256sum | awk '{print $1}'
}

state_serial() {
  jq -r '.serial' "${source_tf_dir}/terraform.tfstate"
}

check_source_project() {
  local expected_project current_project
  require_commands openstack
  expected_project="$(
    jq -r '[
      .resources[]
      | select(.type == "openstack_networking_secgroup_v2")
      | select(.name == "bastion")
      | .instances[].attributes.tenant_id
    ][0] // empty' "${source_tf_dir}/terraform.tfstate"
  )"
  if [[ -z "${expected_project}" ]]; then
    printf 'STOP: projet source impossible à dériver du state.\n' >&2
    exit 1
  fi
  current_project="$(openstack token issue -f value -c project_id 2>/dev/null | tr -d '[:space:]')"
  if [[ -z "${current_project}" || "${current_project}" != "${expected_project}" ]]; then
    printf 'STOP: le token OpenStack actif ne cible pas le projet source du state.\n' >&2
    exit 1
  fi
  printf 'Garde-fou OpenStack: projet source confirmé sans afficher son identifiant.\n'
}

prepare() {
  local source_instances staging_instances proxy_ip
  require_commands jq openssl sha256sum terraform
  source_instances="$(terraform -chdir="${source_tf_dir}" output -json compute_instances)"
  staging_instances="$(terraform -chdir="${staging_tf_dir}" output -json staging_instances)"
  proxy_ip="$(jq -r '.bastion.access_ip_v4' <<<"${source_instances}")"

  "${script_dir}/t06-generate-lab-pki.sh" \
    "${t06_pki_dir}" teleport.asteria.lab "${proxy_ip}"

  umask 077
  jq -n --argjson staging "${staging_instances}" '{
    teleport_staging_agent_cidrs: [
      ($staging.control_plane.access_ip_v4 + "/32"),
      ($staging.worker.access_ip_v4 + "/32")
    ]
  }' >"${staging_vars}"
  chmod 0600 "${staging_vars}"

  terraform -chdir="${source_tf_dir}" fmt -check
  terraform -chdir="${source_tf_dir}" validate
  printf 'Préparation T06 valide ; aucune ressource cloud ou VM modifiée.\n'
}

create_plan() {
  local expected_count changed_count invalid_count admin_count
  require_commands jq openstack rg sha256sum terraform
  [[ -f "${staging_vars}" ]] || {
    printf 'STOP: exécuter prepare avant plan.\n' >&2
    exit 1
  }
  check_source_project
  terraform -chdir="${source_tf_dir}" plan \
    -out="$(basename "${plan_file}")"

  admin_count="$(
    jq '[
      .resources[]
      | select(.type == "openstack_networking_secgroup_rule_v2")
      | select(.name == "bastion_ssh")
      | .instances[]
    ] | length' "${source_tf_dir}/terraform.tfstate"
  )"
  expected_count="$(jq '.teleport_staging_agent_cidrs | length' "${staging_vars}")"
  expected_count=$((expected_count + admin_count + 3))
  changed_count="$(
    terraform -chdir="${source_tf_dir}" show -json "$(basename "${plan_file}")" \
      | jq '[.resource_changes[] | select(.change.actions != ["no-op"])] | length'
  )"
  invalid_count="$(
    terraform -chdir="${source_tf_dir}" show -json "$(basename "${plan_file}")" \
      | jq '[
          .resource_changes[]
          | select(.change.actions != ["no-op"])
          | select(
              (.change.actions != ["create"]) or
              (.address | test("openstack_networking_secgroup_rule_v2\\.bastion_teleport_from_")) == false
            )
        ] | length'
  )"
  if [[ "${changed_count}" -ne "${expected_count}" || "${invalid_count}" -ne 0 ]]; then
    printf 'STOP: impact inattendu ; T06 autorise seulement %s créations de règles proxy.\n' \
      "${expected_count}" >&2
    exit 1
  fi

  umask 077
  {
    printf 'code_digest=%s\n' "$(tf_code_digest)"
    printf 'state_serial=%s\n' "$(state_serial)"
    printf 'expected_creates=%s\n' "${expected_count}"
  } >"${plan_meta}"
  chmod 0600 "${plan_file}" "${plan_meta}"
  printf 'Plan T06: %s ajouts, 0 modification, 0 remplacement, 0 destruction.\n' \
    "${expected_count}"
}

apply_plan() {
  local saved_code saved_serial
  require_commands jq openstack rg sha256sum terraform
  [[ -f "${plan_file}" && -f "${plan_meta}" ]] || {
    printf 'STOP: plan T06 ou métadonnées absents.\n' >&2
    exit 1
  }
  saved_code="$(awk -F= '$1 == "code_digest" {print $2}' "${plan_meta}")"
  saved_serial="$(awk -F= '$1 == "state_serial" {print $2}' "${plan_meta}")"
  if [[ "${saved_code}" != "$(tf_code_digest)" || "${saved_serial}" != "$(state_serial)" ]]; then
    printf 'STOP: code ou state modifié depuis le plan ; recréer le plan.\n' >&2
    exit 1
  fi
  check_source_project
  terraform -chdir="${source_tf_dir}" apply "$(basename "${plan_file}")"
  rm -f "${plan_file}" "${plan_meta}"
  printf 'Règles réseau T06 appliquées sans destruction.\n'
}

ssh_base_args() {
  printf '%s\0' \
    -F /dev/null \
    -i "${ssh_key}" \
    -o IdentitiesOnly=yes \
    -o BatchMode=yes \
    -o ConnectTimeout=30 \
    -o StrictHostKeyChecking=yes
}

deploy() {
  local bastion_ip ca_pin join_token token_file python_version agent_limit
  local -a ssh_args agent_playbook_args
  require_commands jq ssh terraform
  [[ -x "${ansible_playbook}" ]] || {
    printf 'STOP: ansible-playbook introuvable: %s\n' "${ansible_playbook}" >&2
    exit 1
  }
  python_version="$(${ansible_playbook} --version | awk '/python version/ {print $4; exit}')"
  if [[ "${python_version}" == 3.14* ]]; then
    printf 'STOP: Ansible/Python 3.14 échoue sur ce poste ; définir ASTERIA_ANSIBLE_PLAYBOOK vers un venv Python 3.12.\n' >&2
    exit 1
  fi
  [[ -r "${t06_pki_dir}/ca.crt" && -r "${t06_pki_dir}/proxy.key" ]] || {
    printf 'STOP: PKI T06 absente ; exécuter prepare.\n' >&2
    exit 1
  }
  if [[ "$(terraform -chdir="${source_tf_dir}" state list | rg -c 'bastion_teleport_from_')" -lt 3 ]]; then
    printf 'STOP: les règles réseau T06 ne sont pas dans le state ; exécuter apply.\n' >&2
    exit 1
  fi

  export ANSIBLE_CONFIG="${repo_root}/infra/ansible/ansible.cfg"
  export ANSIBLE_HOME="${repo_root}/.ansible"
  export ANSIBLE_TIMEOUT=30
  export ASTERIA_T06_PKI_DIR="${t06_pki_dir}"

  agent_playbook_args=(-i "${inventory}" "${agents_playbook}")
  agent_limit="${ASTERIA_T06_AGENT_LIMIT:-}"
  if [[ -n "${agent_limit}" ]]; then
    if ! [[ "${agent_limit}" =~ ^[A-Za-z0-9._-]+$ ]]; then
      printf 'STOP: ASTERIA_T06_AGENT_LIMIT contient un nom d’hôte invalide.\n' >&2
      exit 1
    fi
    agent_playbook_args+=(--limit "${agent_limit}")
  fi

  if [[ "${1:-}" != "--agents-only" ]]; then
    "${ansible_playbook}" -i "${inventory}" "${control_playbook}"
    "${ansible_playbook}" -i "${inventory}" "${kube_playbook}"
    "${ansible_playbook}" -i "${inventory}" "${postgres_playbook}"
  fi

  bastion_ip="$(terraform -chdir="${source_tf_dir}" output -json compute_instances | jq -r '.bastion.access_ip_v4')"
  mapfile -d '' -t ssh_args < <(ssh_base_args)
  ca_pin="$(
    ssh "${ssh_args[@]}" "ubuntu@${bastion_ip}" \
      "sudo tctl -c /etc/teleport.yaml status" \
      | awk '$1 == "CA" && $2 == "pins:" {print $3; exit}'
  )"
  [[ "${ca_pin}" =~ ^sha256:[0-9a-f]+$ ]] || {
    printf 'STOP: empreinte CA Teleport introuvable.\n' >&2
    exit 1
  }
  join_token="$(
    ssh "${ssh_args[@]}" "ubuntu@${bastion_ip}" \
      "sudo tctl -c /etc/teleport.yaml tokens add --type=node,kube,db --ttl=10m --format=text"
  )"
  join_token="$(tr -d '[:space:]' <<<"${join_token}")"
  [[ "${join_token}" =~ ^[A-Za-z0-9._-]{16,}$ ]] || {
    printf 'STOP: token Teleport inattendu ; rien ne sera enrôlé.\n' >&2
    exit 1
  }

  token_file="$(mktemp)"
  cleanup_enrollment() {
    local cleanup_file="${token_file:-}"
    if [[ -n "${cleanup_file}" && -f "${cleanup_file}" ]]; then
      if command -v shred >/dev/null 2>&1; then
        shred -u "${cleanup_file}" 2>/dev/null || true
      else
        rm -f "${cleanup_file}"
      fi
    fi
    if [[ -n "${join_token:-}" && -n "${bastion_ip:-}" ]]; then
      ssh "${ssh_args[@]}" "ubuntu@${bastion_ip}" \
        "sudo tctl -c /etc/teleport.yaml tokens rm '${join_token}'" \
        >/dev/null 2>&1 || true
    fi
  }
  trap cleanup_enrollment EXIT
  umask 077
  printf '%s\n' "${join_token}" >"${token_file}"
  export ASTERIA_T06_JOIN_TOKEN_FILE="${token_file}"
  export ASTERIA_T06_CA_PIN="${ca_pin}"
  "${ansible_playbook}" "${agent_playbook_args[@]}"
  unset ASTERIA_T06_JOIN_TOKEN_FILE ASTERIA_T06_CA_PIN
  cleanup_enrollment
  trap - EXIT
  if [[ -n "${agent_limit}" ]]; then
    printf 'Agent T06 %s validé ; token éphémère retiré.\n' "${agent_limit}"
  else
    printf 'Control plane et six agents T06 enrôlés ; token éphémère retiré.\n'
  fi
}

validate() {
  local bastion_ip node_count resource_counts kube_count db_count token_count
  local -a ssh_args
  require_commands curl jq ssh terraform
  bastion_ip="$(terraform -chdir="${source_tf_dir}" output -json compute_instances | jq -r '.bastion.access_ip_v4')"
  curl --fail --silent --show-error \
    --cacert "${t06_pki_dir}/ca.crt" \
    --resolve "teleport.asteria.lab:3080:${bastion_ip}" \
    https://teleport.asteria.lab:3080/webapi/ping >/dev/null
  mapfile -d '' -t ssh_args < <(ssh_base_args)
  node_count="$(
    ssh "${ssh_args[@]}" "ubuntu@${bastion_ip}" \
      "sudo tctl -c /etc/teleport.yaml get nodes --format=json" \
      | jq 'length'
  )"
  if [[ "${node_count}" -ne 7 ]]; then
    printf 'STOP: 7 nœuds Teleport attendus, %s observés.\n' "${node_count}" >&2
    exit 1
  fi
  resource_counts="$(
    ssh "${ssh_args[@]}" "ubuntu@${bastion_ip}" '
      set -e
      printf "%s " "$(sudo tctl -c /etc/teleport.yaml get kube_server --format=json | jq length)"
      printf "%s " "$(sudo tctl -c /etc/teleport.yaml get db_server --format=json | jq length)"
      sudo tctl -c /etc/teleport.yaml tokens ls --format=json | jq length
    '
  )"
  read -r kube_count db_count token_count <<<"${resource_counts}"
  if [[ "${kube_count}" -ne 1 || "${db_count}" -ne 1 || "${token_count}" -ne 0 ]]; then
    printf 'STOP: services attendus kube=1/db=1/tokens=0 ; observés %s/%s/%s.\n' \
      "${kube_count}" "${db_count}" "${token_count}" >&2
    exit 1
  fi
  ssh "${ssh_args[@]}" "ubuntu@${bastion_ip}" \
    "systemctl is-active ssh teleport >/dev/null && sudo tctl -c /etc/teleport.yaml get role/asteria-platform >/dev/null && sudo tctl -c /etc/teleport.yaml get role/asteria-observer >/dev/null"
  printf 'Validation infrastructure T06: proxy TLS, 7 nœuds, kube=1, db=1, tokens=0, RBAC et break-glass actifs.\n'
}

case "${1:-}" in
  prepare) prepare ;;
  plan) create_plan ;;
  apply) apply_plan ;;
  deploy) deploy ;;
  resume-agent) deploy --agents-only ;;
  validate) validate ;;
  *) usage; exit 2 ;;
esac
