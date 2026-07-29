#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT:?set PROJECT}"
: "${INSTANCE:?set INSTANCE}"
: "${VOLUME:?set VOLUME}"
: "${STORAGE:?set STORAGE}"
: "${NETWORK:?set NETWORK}"
: "${ROOT_SIZE:?set ROOT_SIZE, for example 10GiB}"

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

lxc storage volume create "$STORAGE" "$VOLUME" --project "$PROJECT" size=10GiB
lxc init ubuntu:24.04 "$INSTANCE" --project "$PROJECT" --storage "$STORAGE" --network "$NETWORK" \
  -c limits.cpu=2 -c limits.memory=2048MiB -d root,size="$ROOT_SIZE"
lxc config device add "$INSTANCE" stirling-data disk pool="$STORAGE" source="$VOLUME" path=/var/lib/stirling-pdf --project "$PROJECT"
lxc start "$INSTANCE" --project "$PROJECT"
lxc exec "$INSTANCE" --project "$PROJECT" -- cloud-init status --wait
lxc file push "$root/recipes/provision.sh" "$INSTANCE/root/provision.sh" --project "$PROJECT" --mode=0755
lxc exec "$INSTANCE" --project "$PROJECT" -- /root/provision.sh </dev/null
