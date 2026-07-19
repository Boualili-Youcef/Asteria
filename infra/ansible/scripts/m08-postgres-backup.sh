#!/usr/bin/env bash
set -euo pipefail

umask 077

backup_root="/var/backups/asteria-postgresql"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="${backup_root}/${timestamp}"

install -d -m 0700 "${backup_dir}"

pg_dumpall --globals-only | gzip -9 >"${backup_dir}/globals.sql.gz"

for database in identity_db orders_db notifications_db; do
  pg_dump --format=custom --file="${backup_dir}/${database}.dump" "${database}"
done

sha256sum "${backup_dir}"/* >"${backup_dir}/SHA256SUMS"
printf '%s\n' "${backup_dir}"
