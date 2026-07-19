#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform/openstack"

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

command -v terraform >/dev/null 2>&1 || {
  printf 'Erreur: terraform est requis pour lire les outputs M06.\n' >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  printf 'Erreur: jq est requis pour construire l inventaire Ansible.\n' >&2
  exit 1
}

instances="$(terraform -chdir="${TF_DIR}" output -json compute_instances)"
ssh_user="${ASTERIA_SSH_USER:-ubuntu}"
ssh_key="${ASTERIA_SSH_PRIVATE_KEY_FILE:-${HOME}/.ssh/tp_cloud}"

jq -n \
  --argjson instances "${instances}" \
  --arg ssh_user "${ssh_user}" \
  --arg ssh_key "${ssh_key}" '
  def vars($role): {
    ansible_host: $instances[$role].access_ip_v4,
    ansible_user: $ssh_user,
    ansible_ssh_private_key_file: $ssh_key,
    asteria_role: $role
  };

  ($instances.bastion.access_ip_v4) as $bastion_ip |
  ($instances.bastion.name) as $bastion_name |
  {
    _meta: {
      hostvars: {
        ($bastion_name): vars("bastion"),
        ($instances.control_plane.name): (
          vars("control_plane") + {
            ansible_ssh_common_args: (
              "-o StrictHostKeyChecking=accept-new -o ProxyJump="
              + $ssh_user + "@" + $bastion_ip
            )
          }
        ),
        ($instances.worker_01.name): (
          vars("worker_01") + {
            ansible_ssh_common_args: (
              "-o StrictHostKeyChecking=accept-new -o ProxyJump="
              + $ssh_user + "@" + $bastion_ip
            )
          }
        ),
        ($instances.worker_02.name): (
          vars("worker_02") + {
            ansible_ssh_common_args: (
              "-o StrictHostKeyChecking=accept-new -o ProxyJump="
              + $ssh_user + "@" + $bastion_ip
            )
          }
        ),
        ($instances.postgres.name): (
          vars("postgres") + {
            ansible_ssh_common_args: (
              "-o StrictHostKeyChecking=accept-new -o ProxyJump="
              + $ssh_user + "@" + $bastion_ip
            )
          }
        )
      }
    },
    all: {
      children: ["bastion", "internal"]
    },
    bastion: {
      hosts: [$bastion_name]
    },
    internal: {
      children: ["kubernetes", "postgres"]
    },
    kubernetes: {
      children: ["control_plane", "workers"]
    },
    control_plane: {
      hosts: [$instances.control_plane.name]
    },
    workers: {
      hosts: [
        $instances.worker_01.name,
        $instances.worker_02.name
      ]
    },
    postgres: {
      hosts: [$instances.postgres.name]
    }
  }
'
