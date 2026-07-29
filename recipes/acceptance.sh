#!/usr/bin/env bash
set -euo pipefail

deadline=$((SECONDS + 300))
status_file=$(mktemp)
trap 'rm -f "$status_file"' EXIT
while (( SECONDS < deadline )); do
  if curl --fail --silent --show-error --max-time 10 http://127.0.0.1:8080/api/v1/info/status >"$status_file" && \
     python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("status") == "UP"' "$status_file"; then
    break
  fi
  sleep 5
done
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("status") == "UP"' "$status_file"
curl --fail --silent --show-error --max-time 15 http://127.0.0.1:8080/api/v1/info \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d, dict) and d'
curl --fail --silent --show-error --max-time 15 http://127.0.0.1:8080/ | grep -qi '<html'
systemctl is-active --quiet stirling-pdf
printf 'orca-persistence-probe\n' >/var/lib/stirling-pdf/orca-persistence-probe
