#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage:
  t02-collect-openstack-inventory.sh <logical-label> [output-directory]

Examples:
  ./scripts/t02-collect-openstack-inventory.sh source
  ./scripts/t02-collect-openstack-inventory.sh target /tmp/asteria-t02/target

The OpenStack environment must already be loaded with an OpenRC file or
OS_CLOUD. The report is private working material and must not be committed.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 64
fi

label=$1
if [[ ! $label =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  printf 'ERROR: logical-label must match ^[a-z0-9][a-z0-9_-]*$\n' >&2
  exit 64
fi

if ! command -v openstack >/dev/null 2>&1; then
  printf 'ERROR: openstack CLI is not installed.\n' >&2
  exit 69
fi

if [[ -z ${OS_CLOUD:-} && -z ${OS_AUTH_URL:-} ]]; then
  printf 'ERROR: load the intended OpenRC or OS_CLOUD before collection.\n' >&2
  exit 78
fi

output_dir=${2:-/tmp/asteria-t02/$label}
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
repo_root=$(realpath -m "$repo_root")
output_dir=$(realpath -m "$output_dir")

case "$output_dir/" in
  "$repo_root"/*)
    printf 'ERROR: inventory output must stay outside the Git repository.\n' >&2
    printf 'Use a path such as /tmp/asteria-t02/%s.\n' "$label" >&2
    exit 73
    ;;
esac

umask 077
mkdir -p "$output_dir"
report=$output_dir/${label}-inventory.md
manifest=$output_dir/${label}-manifest.tsv
: >"$report"
: >"$manifest"

sanitize() {
  sed -E \
    -e 's/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/[REDACTED_UUID]/g' \
    -e 's/[0-9a-fA-F]{32}/[REDACTED_HEX_ID]/g' \
    -e 's#https?://[^[:space:]"<>]+#[REDACTED_ENDPOINT]#g' \
    -e 's/(project_id|tenant_id|user_id)([[:space:]]*[:=|][[:space:]]*)[^ |]+/\1\2[REDACTED]/Ig'
}

command_text() {
  printf 'openstack'
  printf ' %q' "$@"
}

record_result() {
  local slug=$1
  local title=$2
  local rc=$3
  printf '%s\t%s\t%s\n' "$slug" "$rc" "$title" >>"$manifest"
}

run_section() {
  local slug=$1
  local title=$2
  shift 2
  local output rc status

  set +e
  output=$(openstack "$@" 2>&1)
  rc=$?
  set -e

  if ((rc == 0)); then
    status=SUCCESS
  else
    status=UNAVAILABLE_OR_DENIED
  fi

  {
    printf '\n## %s\n\n' "$title"
    printf -- '- Status: `%s`\n' "$status"
    printf -- '- Commande: `'
    command_text "$@"
    printf '`\n\n```text\n'
    printf '%s\n' "$output" | sanitize
    printf '```\n'
  } >>"$report"

  record_result "$slug" "$title" "$rc"
}

run_count() {
  local slug=$1
  local title=$2
  local column=$3
  shift 3
  local output rc count status

  set +e
  output=$(openstack "$@" -f value -c "$column" 2>&1)
  rc=$?
  set -e

  if ((rc == 0)); then
    count=$(printf '%s\n' "$output" | sed '/^[[:space:]]*$/d' | wc -l)
    output="count=$count"
    status=SUCCESS
  else
    status=UNAVAILABLE_OR_DENIED
  fi

  {
    printf '\n## %s\n\n' "$title"
    printf -- '- Status: `%s`\n' "$status"
    printf -- '- Commande logique: `'
    command_text "$@"
    printf '` puis comptage local de la colonne `%s`\n\n```text\n' "$column"
    printf '%s\n' "$output" | sanitize
    printf '```\n'
  } >>"$report"

  record_result "$slug" "$title" "$rc"
}

run_network_details() {
  local ids output rc id status aggregate_rc=0
  set +e
  ids=$(openstack network list -f value -c ID 2>&1)
  rc=$?
  set -e

  {
    printf '\n## Propriétés des réseaux visibles\n\n'
    printf -- '- Commande logique: `openstack network show <network>` avec colonnes non sensibles\n\n'
    printf '```text\n'
  } >>"$report"

  if ((rc != 0)); then
    printf '%s\n' "$ids" | sanitize >>"$report"
  elif [[ -z $ids ]]; then
    printf 'Aucun réseau visible.\n' >>"$report"
  else
    while IFS= read -r id; do
      [[ -z $id ]] && continue
      set +e
      output=$(openstack network show "$id" -f yaml \
        -c name -c status -c admin_state_up -c router:external -c shared \
        -c mtu -c port_security_enabled -c availability_zones 2>&1)
      rc=$?
      set -e
      ((rc != 0)) && aggregate_rc=$rc
      printf '%s\n' "$output" | sanitize >>"$report"
      printf '%s\n' '---' >>"$report"
    done <<<"$ids"
  fi
  printf '```\n' >>"$report"

  ((rc != 0)) && aggregate_rc=$rc
  if ((aggregate_rc == 0)); then status=SUCCESS; else status=UNAVAILABLE_OR_DENIED; fi
  record_result network_details "Propriétés des réseaux visibles" "$aggregate_rc"
}

run_subnet_details() {
  local ids output rc id status aggregate_rc=0
  set +e
  ids=$(openstack subnet list -f value -c ID 2>&1)
  rc=$?
  set -e

  {
    printf '\n## DHCP, DNS et CIDR des subnets visibles\n\n'
    printf -- '- Commande logique: `openstack subnet show <subnet>` avec colonnes non sensibles\n\n'
    printf '```text\n'
  } >>"$report"

  if ((rc != 0)); then
    printf '%s\n' "$ids" | sanitize >>"$report"
  elif [[ -z $ids ]]; then
    printf 'Aucun subnet visible.\n' >>"$report"
  else
    while IFS= read -r id; do
      [[ -z $id ]] && continue
      set +e
      output=$(openstack subnet show "$id" -f yaml \
        -c name -c cidr -c gateway_ip -c enable_dhcp -c dns_nameservers \
        -c allocation_pools -c host_routes 2>&1)
      rc=$?
      set -e
      ((rc != 0)) && aggregate_rc=$rc
      printf '%s\n' "$output" | sanitize >>"$report"
      printf '%s\n' '---' >>"$report"
    done <<<"$ids"
  fi
  printf '```\n' >>"$report"

  ((rc != 0)) && aggregate_rc=$rc
  if ((aggregate_rc == 0)); then status=SUCCESS; else status=UNAVAILABLE_OR_DENIED; fi
  record_result subnet_details "DHCP, DNS et CIDR des subnets visibles" "$aggregate_rc"
}

run_config_drive_details() {
  local ids output rc id status aggregate_rc=0
  set +e
  ids=$(openstack server list -f value -c ID 2>&1)
  rc=$?
  set -e

  {
    printf '\n## Config-drive des instances existantes\n\n'
    printf -- '- Commande logique: `openstack server show <server>` sans afficher son UUID\n\n'
    printf '```text\n'
  } >>"$report"

  if ((rc != 0)); then
    printf '%s\n' "$ids" | sanitize >>"$report"
  elif [[ -z $ids ]]; then
    printf 'Aucune instance : config-drive non vérifiable sans création contrôlée.\n' >>"$report"
  else
    while IFS= read -r id; do
      [[ -z $id ]] && continue
      set +e
      output=$(openstack server show "$id" -f yaml \
        -c name -c config_drive -c OS-EXT-AZ:availability_zone 2>&1)
      rc=$?
      set -e
      ((rc != 0)) && aggregate_rc=$rc
      printf '%s\n' "$output" | sanitize >>"$report"
      printf '%s\n' '---' >>"$report"
    done <<<"$ids"
  fi
  printf '```\n' >>"$report"

  ((rc != 0)) && aggregate_rc=$rc
  if ((aggregate_rc == 0)); then status=SUCCESS; else status=UNAVAILABLE_OR_DENIED; fi
  record_result config_drive "Config-drive des instances existantes" "$aggregate_rc"
}

generated_at=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
cli_version=$(openstack --version 2>&1 | sanitize)

{
  printf '# Inventaire OpenStack privé T02 — %s\n\n' "$label"
  printf -- '- Généré en UTC : %s\n' "$generated_at"
  printf -- '- Label logique : %s\n' "$label"
  printf -- '- Client : %s\n' "$cli_version"
  cat <<'EOF'
- Contenu : collecte en lecture seule, UUID et endpoints neutralisés
- Interdit : ne pas committer ce rapport brut dans le dépôt

Le statut `UNAVAILABLE_OR_DENIED` ne signifie pas automatiquement que le
service cloud est absent : il peut aussi signaler un plugin CLI manquant, une
API non publiée ou une policy qui refuse l'appel. L'erreur neutralisée permet
de distinguer ces cas lors de l'analyse.
EOF
} >"$report"

run_section auth "Authentification et expiration du token" \
  token issue -f table -c expires
run_section catalog "Types de services du catalogue" \
  catalog list -f value -c Type
run_section compute_quota "Quota compute et consommation" \
  quota show --compute --usage -f yaml
run_section network_quota "Quota réseau et consommation" \
  quota show --network --usage -f yaml
run_section volume_quota "Quota volume et consommation" \
  quota show --volume --usage -f yaml
run_section absolute_limits "Limites absolues compute et volume" \
  limits show --absolute -f yaml

run_section flavors "Flavors disponibles" \
  flavor list --long -f table
run_section images "Images disponibles" \
  image list -f table -c Name -c Status -c Visibility -c Size
run_section servers "Instances et zones de disponibilité" \
  server list --long -f table -c Name -c Status -c Image -c Flavor \
  -c "Availability Zone"
run_section compute_az "Zones de disponibilité compute" \
  availability zone list --compute --long -f table
run_section server_groups "Groupes et politiques de placement" \
  server group list --long -f table
run_count keypairs "Nombre de keypairs" Name keypair list
run_config_drive_details

run_section network_extensions "Extensions Neutron" \
  extension list --network -f table -c Alias -c Name
run_section networks "Réseaux visibles" \
  network list --long -f table
run_network_details
run_section subnets "Subnets visibles" \
  subnet list --long -f table
run_subnet_details
run_count ports "Nombre de ports" ID port list
run_section security_groups "Security groups" \
  security group list -f table -c Name -c Description
run_count security_group_rules "Nombre de règles de security group" ID \
  security group rule list
run_count rbac_policies "Nombre de politiques RBAC réseau" ID \
  network rbac list
run_section routers "Routeurs L3" router list --long -f table
run_count floating_ips "Nombre de Floating IP" ID floating ip list
run_section network_agents "Agents réseau visibles" network agent list -f table
run_section network_az "Zones de disponibilité réseau" \
  availability zone list --network --long -f table

run_section volumes "Volumes" volume list --long -f table
run_section volume_snapshots "Snapshots de volume" volume snapshot list -f table
run_section volume_backups "Backups de volume" volume backup list -f table
run_section volume_types "Types de volume" volume type list -f table
run_section volume_az "Zones de disponibilité volume" \
  availability zone list --volume --long -f table

run_section swift_account "Compte Swift / Object Storage" \
  object store account show -f yaml
run_count swift_containers "Nombre de conteneurs Swift" Name container list
run_section octavia "Providers Octavia" loadbalancer provider list -f table
run_count designate_zones "Nombre de zones DNS Designate" ID zone list

core_failures=$(awk -F '\t' '
  $1 ~ /^(auth|catalog|compute_quota|network_quota|flavors|images|servers|networks)$/ && $2 != 0 {count++}
  END {print count+0}
' "$manifest")

{
  printf '\n## Résumé de collecte\n\n'
  printf -- '- Sections enregistrées : %s\n' "$(wc -l <"$manifest")"
  printf -- '- Échecs des sections cœur : %s\n' "$core_failures"
  printf -- '- Manifest privé : `%s`\n' "$manifest"
  printf -- '- Connectivité inter-projets : non testée par ce script en lecture seule.\n'
} >>"$report"

printf 'Inventory report: %s\n' "$report"
printf 'Command manifest: %s\n' "$manifest"

if ((core_failures > 0)); then
  printf 'ERROR: one or more core inventory calls failed; inspect the report.\n' >&2
  exit 2
fi
