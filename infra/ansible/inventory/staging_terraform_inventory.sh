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
ssh_user="${ASTERIA_SSH_USER:-ubuntu}"
ssh_key="${ASTERIA_SSH_PRIVATE_KEY_FILE:-${HOME}/.ssh/tp_cloud}"
ssh_known_hosts="${ASTERIA_SSH_KNOWN_HOSTS_FILE:-${HOME}/.local/share/asteria/known_hosts/t05-staging}"

jq -n \
  --argjson source "${source_instances}" \
  --argjson staging "${staging_instances}" \
  --arg ssh_user "${ssh_user}" \
  --arg ssh_key "${ssh_key}" \
  --arg ssh_known_hosts "${ssh_known_hosts}" '
  ($source.bastion.access_ip_v4) as $bastion_ip |
  ($source.bastion.name) as $bastion_name |
  def base_vars($host; $role): {
    ansible_host: $host,
    ansible_user: $ssh_user,
    ansible_ssh_private_key_file: $ssh_key,
    asteria_role: $role
  };
  def staging_vars($node; $role):
    base_vars($node.access_ip_v4; $role) + {
      ansible_ssh_common_args: (
        "-o UserKnownHostsFile=" + $ssh_known_hosts
        + " -o StrictHostKeyChecking=accept-new -o ProxyJump="
        + $ssh_user + "@" + $bastion_ip
      )
    };
  {
    _meta: {
      hostvars: {
        ($bastion_name): base_vars($bastion_ip; "source_bastion"),
        ($staging.control_plane.name): staging_vars(
          $staging.control_plane; "staging_control_plane"
        ),
        ($staging.worker.name): staging_vars(
          $staging.worker; "staging_worker"
        )
      }
    },
    all: {
      children: ["bastion", "staging"],
      vars: {
        asteria_source_bastion_ip: $bastion_ip,
        asteria_source_bastion_cidr: ($bastion_ip + "/32"),
        asteria_staging_control_plane_ip: $staging.control_plane.access_ip_v4,
        asteria_staging_worker_ip: $staging.worker.access_ip_v4
      }
    },
    bastion: {
      hosts: [$bastion_name]
    },
    staging: {
      children: ["staging_control_plane", "staging_workers"]
    },
    staging_control_plane: {
      hosts: [$staging.control_plane.name]
    },
    staging_workers: {
      hosts: [$staging.worker.name]
    }
  }
'
