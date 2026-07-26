#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 || "${2:-}" != "" && "${2:-}" != "--push" ]]; then
  printf 'Usage: %s <image-reference> [--push]\n' "$0" >&2
  exit 2
fi

image_ref="$1"
push_mode="${2:-}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
record_file="${M15_NOTIFICATIONS_RECORD_FILE:-/tmp/asteria-m15-notifications-image.txt}"

if [[ ! "${image_ref}" =~ ^ghcr\.io/[a-z0-9._/-]+:[A-Za-z0-9._-]+$ ]]; then
  printf 'Error: expected a tagged lowercase ghcr.io image reference\n' >&2
  exit 2
fi

command -v docker >/dev/null
git_revision="$(git -C "${repo_root}" rev-parse HEAD)"

docker build \
  --label org.opencontainers.image.source=https://github.com/Boualili-Youcef/Asteria \
  --label "org.opencontainers.image.revision=${git_revision}" \
  --tag "${image_ref}" \
  "${repo_root}/apps/notifications-worker"

image_id="$(docker image inspect "${image_ref}" --format '{{.Id}}')"

if [[ "${push_mode}" == "--push" ]]; then
  docker push "${image_ref}"
  publication="pushed-manually"
else
  publication="built-locally"
fi

{
  printf 'image=%s\n' "${image_ref}"
  printf 'image_id=%s\n' "${image_id}"
  printf 'revision=%s\n' "${git_revision}"
  printf 'publication=%s\n' "${publication}"
} > "${record_file}"

printf 'Notifications manual image: %s\n' "${image_ref}"
printf 'Record: %s\n' "${record_file}"
