#!/usr/bin/env bash
set -euo pipefail
run() { psql -v ON_ERROR_STOP=1 -v station_id="${STATION_ID:-0}" -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"; }
echo "[init] role=${NODE_ROLE:-master} db=$POSTGRES_DB"
for f in /db/common/*.sql; do run -f "$f"; done
for f in /db/${NODE_ROLE:-master}/*.sql; do
  [ -e "$f" ] || continue
  run -f "$f"
done
echo "[init] role=${NODE_ROLE:-master} ready"
