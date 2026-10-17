#!/usr/bin/env bash
# Run on a STATION container: subscribe to the master's master_publication
# so reference/lookup data (ref.team, ref.match, ...) flows master -> station.
# Idempotent: exits early if master_subscription already exists.
set -euo pipefail
: "${MASTER_HOST:?Set MASTER_HOST in .env.station}"
: "${MASTER_PORT:?Set MASTER_PORT in .env.station}"
export PGPASSWORD="$POSTGRES_PASSWORD"
if psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
  "SELECT 1 FROM pg_subscription WHERE subname = 'master_subscription'" | grep -q 1; then
  echo "[subscribe-master] master_subscription already exists"
  exit 0
fi
# copy_data=true: existing ref rows on the master are copied to this station
# during the initial sync; afterwards only new changes are streamed.
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<SQL
CREATE SUBSCRIPTION master_subscription
  CONNECTION 'host=$MASTER_HOST port=$MASTER_PORT dbname=${MASTER_DB:-$POSTGRES_DB} user=$POSTGRES_USER password=$POSTGRES_PASSWORD'
  PUBLICATION master_publication
  WITH (slot_name = '${REPLICATION_SLOT:-master_slot}', create_slot = true, copy_data = true);
SQL
echo "[subscribe-master] done"
