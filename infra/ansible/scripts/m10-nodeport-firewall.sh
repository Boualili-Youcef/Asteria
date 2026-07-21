#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/32$ ]]; then
  printf 'Usage: %s <bastion-ipv4/32>\n' "$0" >&2
  exit 2
fi

bastion_cidr="$1"
chain="ASTERIA_NODEPORTS"

iptables -w -t raw -N "${chain}" 2>/dev/null || true
iptables -w -t raw -F "${chain}"
iptables -w -t raw -A "${chain}" -s "${bastion_cidr}" -j RETURN
iptables -w -t raw -A "${chain}" -j DROP

if ! iptables -w -t raw -C PREROUTING \
  -p tcp -m multiport --dports 30080,30443 -j "${chain}" 2>/dev/null; then
  iptables -w -t raw -I PREROUTING 1 \
    -p tcp -m multiport --dports 30080,30443 -j "${chain}"
fi
