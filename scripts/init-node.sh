#!/bin/bash
# scripts/init-node.sh - Chạy bởi postgres docker-entrypoint-initdb.d trên container đầu tiên.
# Phân luồng theo NODE_ROLE: master | station
# - master: chạy /db/master/10_local_data.sql (phần FDW tách riêng, chạy sau khi all station
#   healthy - xem scripts/setup-fdw.sh).
# - station: chọn file theo $STATION_ID (1..6) → /db/station_<ID>/00_init.sql
#   (verbatim từ BTL-CSDL: TRAN_DAU_CHUYEN_MON + SU_KIEN_TRAN_DAU cho 5 trận sân nhà của CLB đó)
set -e

ROLE="${NODE_ROLE:-master}"
STATION_ID="${STATION_ID:-0}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-vleague_master}"

echo "=== init-node.sh: role=$ROLE station_id=$STATION_ID db=$DB_NAME user=$DB_USER ==="

if [ "$ROLE" = "master" ]; then
  INIT_FILE="/db/master/10_local_data.sql"
  echo "--- Master init: chạy $INIT_FILE ---"
  psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -f "$INIT_FILE"
  echo "--- Master init: xong (FDW setup chạy sau khi stations healthy - xem scripts/setup-fdw.sh) ---"

elif [ "$ROLE" = "station" ] || [[ "$ROLE" = station* ]]; then
  if [ "$STATION_ID" -lt 1 ] || [ "$STATION_ID" -gt 6 ]; then
    echo "!!! STATION_ID '$STATION_ID' không hợp lệ. Phải 1..6."
    exit 1
  fi
  INIT_FILE="/db/station_${STATION_ID}/00_init.sql"
  echo "--- Station $STATION_ID init: chạy $INIT_FILE ---"
  if [ ! -f "$INIT_FILE" ]; then
    echo "!!! Không tìm thấy $INIT_FILE. Kiểm tra đã mount ./db hay chưa."
    exit 1
  fi
  psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -f "$INIT_FILE"
  echo "--- Station $STATION_ID init: xong ---"

else
  echo "!!! NODE_ROLE '$ROLE' không hợp lệ. Phải là: master | station"
  exit 1
fi

echo "=== init-node.sh hoàn tất ==="
