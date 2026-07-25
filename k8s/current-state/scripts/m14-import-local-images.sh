#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ssh_key="${ASTERIA_SSH_PRIVATE_KEY_FILE:?Set ASTERIA_SSH_PRIVATE_KEY_FILE}"
ssh_user="${ASTERIA_SSH_USER:-ubuntu}"
images=(
  docker.io/asteria/identity-api:m13
  docker.io/asteria/orders-api:m13
  docker.io/asteria/notifications-worker:m13
)

command -v docker >/dev/null
command -v gzip >/dev/null
command -v jq >/dev/null
command -v ssh >/dev/null
command -v terraform >/dev/null
test -r "${ssh_key}"

for image in "${images[@]}"; do
  docker image inspect "${image}" >/dev/null
done

instances="$(
  terraform -chdir="${repo_root}/infra/terraform/openstack" \
    output -json compute_instances
)"
bastion_ip="$(jq -r '.bastion.access_ip_v4' <<<"${instances}")"

ssh_common=(
  -F /dev/null
  -i "${ssh_key}"
  -o BatchMode=yes
  -o ConnectTimeout=8
  -o StrictHostKeyChecking=accept-new
)

for role in control_plane worker_01 worker_02; do
  node_ip="$(jq -r --arg role "${role}" '.[$role].access_ip_v4' <<<"${instances}")"
  printf 'Importing M13 images on %s (%s)\n' "${role}" "${node_ip}"

  docker save "${images[@]}" |
    gzip -1 |
    ssh "${ssh_common[@]}" \
      -J "${ssh_user}@${bastion_ip}" \
      "${ssh_user}@${node_ip}" \
      'gzip -dc | sudo -n k3s ctr images import -'

  for image in "${images[@]}"; do
    ssh "${ssh_common[@]}" \
      -J "${ssh_user}@${bastion_ip}" \
      "${ssh_user}@${node_ip}" \
      "sudo -n k3s ctr images list | grep -Fq '${image}'"
  done
done

printf 'M14 local images imported on all K3s nodes\n'
