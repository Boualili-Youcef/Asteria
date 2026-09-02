#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s <organisation> <equipe> <client-id> <fichier-secret-hors-git>\n' "$0" >&2
}

if [[ "$#" -ne 4 ]]; then
  usage
  exit 2
fi

github_org="$1"
github_team="$2"
github_client_id="$3"
secret_file="$4"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
source_tf_dir="${repo_root}/infra/terraform/openstack"
ssh_key="${ASTERIA_SSH_PRIVATE_KEY_FILE:-${HOME}/.ssh/tp_cloud}"

for value in "${github_org}" "${github_team}" "${github_client_id}"; do
  if ! [[ "${value}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf 'STOP: organisation, équipe et client ID acceptent seulement A-Z, a-z, 0-9, point, tiret et underscore.\n' >&2
    exit 1
  fi
done
if [[ "${secret_file}" != /* || ! -f "${secret_file}" ]]; then
  printf 'STOP: fournir un fichier secret absolu existant hors Git.\n' >&2
  exit 1
fi
if [[ "${secret_file}" == "${repo_root}" || "${secret_file}" == "${repo_root}/"* ]]; then
  printf 'STOP: le secret OAuth ne doit jamais être placé dans le dépôt.\n' >&2
  exit 1
fi
secret_mode="$(stat -c '%a' "${secret_file}")"
if (( 8#${secret_mode} & 8#077 )); then
  printf 'STOP: le fichier secret doit être en mode 0600.\n' >&2
  exit 1
fi
github_secret="$(tr -d '\r\n' <"${secret_file}")"
if ! [[ "${github_secret}" =~ ^[A-Za-z0-9._-]{16,}$ ]]; then
  printf 'STOP: format de secret OAuth inattendu.\n' >&2
  exit 1
fi

for command_name in jq scp ssh terraform; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'STOP: commande requise absente: %s\n' "${command_name}" >&2
    exit 1
  }
done

bastion_ip="$(terraform -chdir="${source_tf_dir}" output -json compute_instances | jq -r '.bastion.access_ip_v4')"
connector_file="$(mktemp)"
cleanup_connector() {
  if command -v shred >/dev/null 2>&1; then
    shred -u "${connector_file}" 2>/dev/null || true
  else
    rm -f "${connector_file}"
  fi
}
trap cleanup_connector EXIT
chmod 0600 "${connector_file}"
cat >"${connector_file}" <<EOF
kind: github
version: v3
metadata:
  name: github
spec:
  client_id: "${github_client_id}"
  client_secret: "${github_secret}"
  display: GitHub
  redirect_url: "https://teleport.asteria.lab:3080/v1/webapi/github/callback"
  teams_to_roles:
    - organization: "${github_org}"
      team: "${github_team}"
      roles:
        - asteria-platform
EOF
unset github_secret

ssh_options=(
  -F /dev/null
  -i "${ssh_key}"
  -o IdentitiesOnly=yes
  -o BatchMode=yes
  -o ConnectTimeout=30
  -o StrictHostKeyChecking=yes
)
scp "${ssh_options[@]}" "${connector_file}" \
  "ubuntu@${bastion_ip}:/tmp/asteria-t06-github.yaml"
ssh "${ssh_options[@]}" "ubuntu@${bastion_ip}" '
  set -e
  cleanup_remote() {
    sudo rm -f /run/asteria-t06-github.yaml
  }
  trap cleanup_remote EXIT
  sudo install -o root -g root -m 0600 \
    /tmp/asteria-t06-github.yaml /run/asteria-t06-github.yaml
  rm -f /tmp/asteria-t06-github.yaml
  sudo tctl -c /etc/teleport.yaml create --force \
    -f /run/asteria-t06-github.yaml
  sudo rm -f /run/asteria-t06-github.yaml
  sudo tctl -c /etc/teleport.yaml get github/github >/dev/null
  auth_type="$(sudo awk "/^[[:space:]]+type: (local|github)$/ {print \$2; exit}" /etc/teleport.yaml)"
  case "${auth_type}" in
    local)
      rollback_auth() {
        sudo cp /run/asteria-t06-teleport.yaml.before-github /etc/teleport.yaml
        sudo rm -f /etc/teleport-resources/github-enabled
        sudo systemctl restart teleport
        sudo rm -f /run/asteria-t06-teleport.yaml.before-github
      }
      sudo cp /etc/teleport.yaml /run/asteria-t06-teleport.yaml.before-github
      trap rollback_auth ERR
      sudo sed -i -E \
        "s/^([[:space:]]+)type: local$/\\1type: github/" \
        /etc/teleport.yaml
      sudo /usr/local/bin/teleport configure --test=/etc/teleport.yaml
      sudo install -o root -g root -m 0644 /dev/null \
        /etc/teleport-resources/github-enabled
      sudo systemctl restart teleport
      ;;
    github)
      sudo install -o root -g root -m 0644 /dev/null \
        /etc/teleport-resources/github-enabled
      ;;
    *)
      printf "Type d authentification Teleport inattendu.\n" >&2
      exit 1
      ;;
  esac
  for attempt in $(seq 1 30); do
    if curl --silent --show-error --fail \
      --cacert /usr/local/share/ca-certificates/asteria-t06-ca.crt \
      https://teleport.asteria.lab:3080/webapi/ping >/dev/null; then
      break
    fi
    test "$attempt" -lt 30
    sleep 2
  done
  sudo rm -f /run/asteria-t06-teleport.yaml.before-github
  trap - ERR
  cleanup_remote
  trap - EXIT
'
printf 'Connecteur GitHub installé et authentification GitHub activée. Tester ensuite tsh login --auth=github.\n'
