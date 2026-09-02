#!/usr/bin/env bash
set -euo pipefail

teleport_version="18.11.0"
install_root="${ASTERIA_T06_CLIENT_ROOT:-${HOME}/.local/share/asteria/tools/teleport}"
bin_dir="${ASTERIA_T06_CLIENT_BIN_DIR:-${HOME}/.local/bin}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"
source_tf_dir="${repo_root}/infra/terraform/openstack"
pki_dir="${ASTERIA_T06_PKI_DIR:-${HOME}/.local/share/asteria/t06-pki}"
ca_file="${pki_dir}/ca.crt"
proxy_hostname="teleport.asteria.lab"
nss_db="${HOME}/.pki/nssdb"
nss_ca_name="Asteria T06 Lab Root CA"
archive="teleport-v${teleport_version}-linux-amd64-bin.tar.gz"
version_dir="${install_root}/${teleport_version}"
download_dir="${install_root}/downloads"

for command_name in awk certutil curl getent jq sed sha256sum sudo tar terraform; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'STOP: commande requise absente: %s\n' "${command_name}" >&2
    exit 1
  }
done

if [[ ! -f "${ca_file}" ]]; then
  printf 'STOP: CA T06 absente: %s\n' "${ca_file}" >&2
  exit 1
fi

proxy_ip="$(
  terraform -chdir="${source_tf_dir}" output -json compute_instances |
    jq -er '.bastion.access_ip_v4'
)"

umask 077
mkdir -p "${download_dir}" "${version_dir}" "${bin_dir}"
curl --fail --silent --show-error --location \
  "https://cdn.teleport.dev/${archive}.sha256" \
  --output "${download_dir}/${archive}.sha256"
curl --fail --silent --show-error --location \
  "https://cdn.teleport.dev/${archive}" \
  --output "${download_dir}/${archive}"
(
  cd "${download_dir}"
  sha256sum --check "${archive}.sha256"
)

if [[ ! -x "${version_dir}/teleport/tsh" ]]; then
  tar -xzf "${download_dir}/${archive}" -C "${version_dir}"
fi
ln -sfn "${version_dir}/teleport/tsh" "${bin_dir}/tsh"

resolved_ip="$(getent ahostsv4 "${proxy_hostname}" 2>/dev/null | awk 'NR == 1 {print $1}')"
if [[ "${resolved_ip}" != "${proxy_ip}" ]]; then
  sudo sed -i -E \
    "/[[:space:]]${proxy_hostname//./\\.}([[:space:]]|$)/d" /etc/hosts
  sudo sed -i "\$a\\${proxy_ip} ${proxy_hostname}" /etc/hosts
fi

sudo install -o root -g root -m 0644 "${ca_file}" \
  /usr/local/share/ca-certificates/asteria-t06-ca.crt
sudo update-ca-certificates >/dev/null

mkdir -p "${nss_db}"
if [[ ! -f "${nss_db}/cert9.db" ]]; then
  certutil -N --empty-password -d "sql:${nss_db}"
fi
certutil -D -d "sql:${nss_db}" -n "${nss_ca_name}" >/dev/null 2>&1 || true
certutil -A -d "sql:${nss_db}" -n "${nss_ca_name}" -t 'C,,' -i "${ca_file}"

test "$(getent ahostsv4 "${proxy_hostname}" | awk 'NR == 1 {print $1}')" = \
  "${proxy_ip}"
curl --fail --silent --show-error \
  "https://${proxy_hostname}:3080/webapi/ping" >/dev/null
"${bin_dir}/tsh" version
printf 'Client T06 installé dans %s ; DNS et CA système/NSS validés. Ajouter %s au PATH si nécessaire.\n' \
  "${version_dir}" "${bin_dir}"
