#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/../../.." && pwd)"
source_tf_dir="${repo_root}/infra/terraform/openstack"
staging_tf_dir="${repo_root}/infra/terraform/openstack-staging"

case "${1:---list}" in
  --host)
    printf '{}\n'
    exit 0
    ;;
  --list)
    ;;
  *)
    printf 'Usage: %s [--list | --host <name>]\n' "$0" >&2
    exit 2
    ;;
esac

for command_name in jq terraform; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'Erreur: commande requise absente: %s\n' "${command_name}" >&2
    exit 1
  }
done

source_instances="$(terraform -chdir="${source_tf_dir}" output -json compute_instances)"
staging_instances="$(terraform -chdir="${staging_tf_dir}" output -json staging_instances)"
source_state_file="${source_tf_dir}/terraform.tfstate"
if [[ ! -r "${source_state_file}" ]]; then
  printf 'Erreur: state Terraform source absent ou illisible.\n' >&2
  exit 1
fi
admin_cidrs="$(
  jq -c '[
    .resources[]
    | select(.type == "openstack_networking_secgroup_rule_v2")
    | select(.name == "bastion_ssh")
    | .instances[].attributes.remote_ip_prefix
  ] | unique' "${source_state_file}"
)"

if [[ "$(jq 'length' <<<"${admin_cidrs}")" -eq 0 ]]; then
  printf 'Erreur: aucun CIDR administrateur trouve dans le state source.\n' >&2
  exit 1
fi

ssh_user="${ASTERIA_SSH_USER:-ubuntu}"
ssh_key="${ASTERIA_SSH_PRIVATE_KEY_FILE:-${HOME}/.ssh/tp_cloud}"
staging_known_hosts="${ASTERIA_SSH_KNOWN_HOSTS_FILE:-${HOME}/.local/share/asteria/known_hosts/t05-staging}"

jq -n \
  --argjson source "${source_instances}" \
  --argjson staging "${staging_instances}" \
  --argjson admin_cidrs "${admin_cidrs}" \
  --arg ssh_user "${ssh_user}" \
  --arg ssh_key "${ssh_key}" \
  --arg staging_known_hosts "${staging_known_hosts}" '
  ($source.bastion.access_ip_v4) as $bastion_ip |
  ($source.bastion.name) as $bastion_name |
  def direct_vars($node; $environment; $role): {
    ansible_host: $node.access_ip_v4,
    ansible_user: $ssh_user,
    ansible_ssh_private_key_file: $ssh_key,
    asteria_environment: $environment,
    asteria_role: $role
  };
  def source_agent_vars($node; $role):
    direct_vars($node; "source"; $role) + {
      ansible_ssh_common_args: (
        "-o StrictHostKeyChecking=accept-new -o ProxyJump="
        + $ssh_user + "@" + $bastion_ip
      )
    };
  def staging_agent_vars($node; $role):
    direct_vars($node; "staging"; $role) + {
      ansible_ssh_common_args: (
        "-o UserKnownHostsFile=" + $staging_known_hosts
        + " -o StrictHostKeyChecking=accept-new -o ProxyJump="
        + $ssh_user + "@" + $bastion_ip
      )
    };
  {
    _meta: {
      hostvars: {
        ($bastion_name): direct_vars($source.bastion; "source"; "bastion"),
        ($source.control_plane.name): source_agent_vars($source.control_plane; "control_plane"),
        ($source.worker_01.name): source_agent_vars($source.worker_01; "worker"),
        ($source.worker_02.name): source_agent_vars($source.worker_02; "worker"),
        ($source.postgres.name): source_agent_vars($source.postgres; "postgres"),
        ($staging.control_plane.name): staging_agent_vars($staging.control_plane; "control_plane"),
        ($staging.worker.name): staging_agent_vars($staging.worker; "worker")
      }
    },
    all: {
      children: ["bastion", "teleport_agents"],
      vars: {
        asteria_admin_cidrs: $admin_cidrs,
        asteria_source_bastion_ip: $bastion_ip,
        asteria_teleport_agent_ips: [
          $source.control_plane.access_ip_v4,
          $source.worker_01.access_ip_v4,
          $source.worker_02.access_ip_v4,
          $source.postgres.access_ip_v4,
          $staging.control_plane.access_ip_v4,
          $staging.worker.access_ip_v4
        ]
      }
    },
    bastion: {hosts: [$bastion_name]},
    teleport_agents: {
      children: ["teleport_node_agents", "teleport_kube_agents", "teleport_db_agents"]
    },
    teleport_node_agents: {
      hosts: [
        $source.worker_01.name,
        $source.worker_02.name,
        $staging.control_plane.name,
        $staging.worker.name
      ]
    },
    teleport_kube_agents: {hosts: [$source.control_plane.name]},
    teleport_db_agents: {hosts: [$source.postgres.name]}
  }
'
