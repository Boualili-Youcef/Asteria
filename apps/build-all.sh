#!/usr/bin/env bash
set -euo pipefail

apps_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
services=(identity-api orders-api notifications-worker)

for service in "${services[@]}"; do
  image="asteria/${service}:m13"
  printf 'Building %s\n' "${image}"
  docker build \
    --label "org.opencontainers.image.title=${service}" \
    --label "org.opencontainers.image.version=m13" \
    --tag "${image}" \
    "${apps_root}/${service}"
done

printf 'M13 image builds passed\n'
