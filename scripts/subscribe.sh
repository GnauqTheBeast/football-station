#!/usr/bin/env bash
set -euo pipefail
: "${STATION_HOST:?Set STATION_HOST in .env.master}"
: "${STATION_PORT:?Set STATION_PORT in .env.master}"
export PGPASSWORD="$POSTGRES_PASSWORD"
if psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
  "SELECT 1 FROM pg_subscription WHERE subname = 'station_subscription'" | grep -q 1; then
  echo "[subscribe] station_subscription already exists"
  exit 0
fi
# copy_data=true (the default): existing rows in demo.message are copied
# from the station to the master during the initial sync. After that, only
# new changes are streamed via the replication slot.
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<SQL
CREATE SUBSCRIPTION station_subscription
  CONNECTION 'host=$STATION_HOST port=$STATION_PORT dbname=${STATION_DB:-$POSTGRES_DB} user=$POSTGRES_USER password=$POSTGRES_PASSWORD'
  PUBLICATION station_publication
  WITH (slot_name = '${REPLICATION_SLOT:-station_slot}', create_slot = true, copy_data = true);
SQL
