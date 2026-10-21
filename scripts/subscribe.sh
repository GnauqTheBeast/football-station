#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/subscribe.sh
#
# Chạy BÊN TRONG master container (qua `make subscribe` hoặc `make subscribe-all`):
# master TẠO station${STATION_ID}_subscription để kéo match.* từ station đó.
#
# Đây là đường "master chủ động tạo sub". Với thiết kế hiện tại, station tự
# đăng ký qua register-with-master.sh khi nó up, nên script này chỉ dùng làm
# fallback khi station chưa tự đăng ký được.
#
# Tên subscription & slot parameterize theo STATION_ID (mặc định 1) để hỗ trợ
# nhiều stations. Đặt STATION_ID + STATION_HOST + STATION_PORT trong .env.master
# để đăng ký cho station tương ứng.
#
# Idempotent: nếu subscription đã tồn tại thì bỏ qua.
# ---------------------------------------------------------------------------
set -euo pipefail
: "${STATION_HOST:?Set STATION_HOST in .env.master}"
: "${STATION_PORT:?Set STATION_PORT in .env.master}"
: "${STATION_ID:=1}"  # default = 1 nếu .env.master không khai báo
export PGPASSWORD="$POSTGRES_PASSWORD"

SUBNAME="station${STATION_ID}_subscription"
SLOTNAME="${REPLICATION_SLOT:-station${STATION_ID}_slot}"

if psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
  "SELECT 1 FROM pg_subscription WHERE subname = '${SUBNAME}'" | grep -q 1; then
  echo "[subscribe] ${SUBNAME} already exists"
  exit 0
fi

# copy_data=true: existing rows in match.* are copied from the station to the
# master during the initial sync. After that, only new changes are streamed.
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<SQL
CREATE SUBSCRIPTION ${SUBNAME}
  CONNECTION 'host=$STATION_HOST port=$STATION_PORT dbname=${STATION_DB:-$POSTGRES_DB} user=$POSTGRES_USER password=$POSTGRES_PASSWORD'
  PUBLICATION station_publication
  WITH (slot_name = '${SLOTNAME}', create_slot = true, copy_data = true);
SQL
echo "[subscribe] ${SUBNAME} created (master -> $STATION_HOST:$STATION_PORT, slot=${SLOTNAME})"
