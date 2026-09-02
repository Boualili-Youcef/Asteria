#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s <repertoire-prive-absolu> <nom-dns> <ip-proxy>\n' "$0" >&2
}

if [[ "$#" -ne 3 ]]; then
  usage
  exit 2
fi

pki_dir="$1"
proxy_dns="$2"
proxy_ip="$3"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/.." && pwd)"

if [[ "${pki_dir}" != /* ]]; then
  printf 'STOP: le repertoire PKI doit etre absolu.\n' >&2
  exit 1
fi
if [[ "${pki_dir}" == "${repo_root}" || "${pki_dir}" == "${repo_root}/"* ]]; then
  printf 'STOP: la PKI T06 doit rester hors du depot.\n' >&2
  exit 1
fi
if ! [[ "${proxy_ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'STOP: adresse IPv4 du proxy invalide.\n' >&2
  exit 1
fi

for command_name in openssl sha256sum; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf 'STOP: commande requise absente: %s\n' "${command_name}" >&2
    exit 1
  }
done

umask 077
mkdir -p "${pki_dir}"
chmod 0700 "${pki_dir}"

required_files=(ca.key ca.crt proxy.key proxy.crt)
existing_count=0
for required_file in "${required_files[@]}"; do
  [[ -e "${pki_dir}/${required_file}" ]] && existing_count=$((existing_count + 1))
done

if [[ "${existing_count}" -ne 0 && "${existing_count}" -ne "${#required_files[@]}" ]]; then
  printf 'STOP: PKI partielle detectee ; restaurer ou retirer explicitement le repertoire.\n' >&2
  exit 1
fi

if [[ "${existing_count}" -eq 0 ]]; then
  openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 365 \
    -subj '/CN=Asteria T06 Lab Root CA' \
    -keyout "${pki_dir}/ca.key" \
    -out "${pki_dir}/ca.crt"

  openssl req -newkey rsa:3072 -sha256 -nodes \
    -subj "/CN=${proxy_dns}" \
    -addext "subjectAltName=DNS:${proxy_dns},IP:${proxy_ip}" \
    -keyout "${pki_dir}/proxy.key" \
    -out "${pki_dir}/proxy.csr"

  extension_file="$(mktemp)"
  trap 'rm -f "${extension_file}"' EXIT
  printf 'subjectAltName=DNS:%s,IP:%s\nextendedKeyUsage=serverAuth\n' \
    "${proxy_dns}" "${proxy_ip}" >"${extension_file}"
  openssl x509 -req -sha256 -days 90 \
    -in "${pki_dir}/proxy.csr" \
    -CA "${pki_dir}/ca.crt" \
    -CAkey "${pki_dir}/ca.key" \
    -CAcreateserial \
    -extfile "${extension_file}" \
    -out "${pki_dir}/proxy.crt"
  rm -f "${pki_dir}/proxy.csr" "${pki_dir}/ca.srl"
fi

openssl verify -CAfile "${pki_dir}/ca.crt" "${pki_dir}/proxy.crt"
openssl x509 -in "${pki_dir}/proxy.crt" -noout -checkend 604800
chmod 0600 "${pki_dir}/ca.key" "${pki_dir}/proxy.key"
chmod 0644 "${pki_dir}/ca.crt" "${pki_dir}/proxy.crt"
(
  cd "${pki_dir}"
  sha256sum ca.crt proxy.crt > SHA256SUMS
)
chmod 0600 "${pki_dir}/SHA256SUMS"

printf 'PKI T06 valide dans %s ; cle CA et cle proxy restent hors Git.\n' "${pki_dir}"
