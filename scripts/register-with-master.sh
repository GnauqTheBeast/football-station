#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/register-with-master.sh
#
# Chạy BÊN TRONG station container (qua `docker exec ... bash /register-with-master.sh`):
# station psql sang master và TẠO station_subscription trên master để master
# kéo demo.message từ station này (chiều station -> master).
#
# Mục đích: station "tự đăng ký" với master, đỡ phụ thuộc master phải chạy
# `make subscribe` thủ công. Yêu cầu station có thể psql tới master (LAN/VPN)
# và master phải reach lại được STATION_PUBLIC_HOST:STATION_PUBLIC_PORT.
#
# Idempotent: nếu station_subscription đã tồn tại trên master thì bỏ qua.
# ---------------------------------------------------------------------------
set -euo pipefail

: "${MASTER_HOST:?MASTER_HOST chưa đặt}"
: "${MASTER_PORT:?MASTER_PORT chưa đặt}"
: "${STATION_PUBLIC_HOST:?STATION_PUBLIC_HOST chưa đặt (IP master dùng để quay lại station)}"
: "${STATION_PUBLIC_PORT:?STATION_PUBLIC_PORT chưa đặt}"
: "${POSTGRES_USER:?}"
: "${POSTGRES_PASSWORD:?}"
: "${POSTGRES_DB:?}"

MASTER_DB="${MASTER_DB:-$POSTGRES_DB}"
STATION_PUBLIC_DB="${STATION_PUBLIC_DB:-$POSTGRES_DB}"
export PGPASSWORD="$POSTGRES_PASSWORD"

if psql -h "$MASTER_HOST" -p "$MASTER_PORT" -U "$POSTGRES_USER" -d "$MASTER_DB" -tAc \
  "SELECT 1 FROM pg_subscription WHERE subname = 'station_subscription'" | grep -q 1; then
  echo "[register] station_subscription đã có trên master — bỏ qua"
  exit 0
fi

# Kiểm tra master có reach lại được station không (để CREATE SUBSCRIPTION không treo).
if ! pg_isready -h "$MASTER_HOST" -p "$MASTER_PORT" -U "$POSTGRES_USER" -d "$MASTER_DB" >/dev/null 2>&1; then
  echo "[register:ERR] không kết nối được tới master $MASTER_HOST:$MASTER_PORT — kiểm tra VPN/firewall" >&2
  exit 1
fi

psql -h "$MASTER_HOST" -p "$MASTER_PORT" -U "$POSTGRES_USER" -d "$MASTER_DB" <<SQL
CREATE SUBSCRIPTION station_subscription
  CONNECTION 'host=${STATION_PUBLIC_HOST} port=${STATION_PUBLIC_PORT} dbname=${STATION_PUBLIC_DB} user=${POSTGRES_USER} password=${POSTGRES_PASSWORD}'
  PUBLICATION station_publication
  WITH (slot_name = 'station_slot', create_slot = true, copy_data = true);
SQL
echo "[register] station_subscription đã tạo trên master (master -> ${STATION_PUBLIC_HOST}:${STATION_PUBLIC_PORT})"
