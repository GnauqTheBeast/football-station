#!/bin/bash
# scripts/station-test-cleanup.sh - Xóa test rows (MaTran LIKE 'TEST_<STATION_ID>_%') khỏi station.
# Chạy TRÊN MÁY TRẠM sau khi demo xong.
# Mỗi station chỉ xóa test rows của chính nó, không ảnh hưởng station khác.
set -e

DB_USER="${POSTGRES_USER:-postgres}"

# Auto-detect STATION_ID (giống station-test-insert.sh)
if [ -z "$STATION_ID" ]; then
  STATION_IDS=$(docker ps --filter "name=^football-station[0-9]$" --format '{{.Names}}' \
                | sed -E 's/^football-station([0-9])$/\1/' | sort -u)
  COUNT=$(echo "$STATION_IDS" | grep -c '[0-9]')
  if [ "$COUNT" = "0" ]; then
    echo "!!! KHÔNG tìm thấy container station (football-station<N>) đang chạy."
    exit 1
  elif [ "$COUNT" = "1" ]; then
    STATION_ID="$STATION_IDS"
  else
    echo "!!! Nhiều station containers đang chạy. Set STATION_ID env:"
    docker ps --filter "name=^football-station[0-9]$" --format '  {{.Names}}'
    echo "   Ví dụ:  STATION_ID=3 ./scripts/station-test-cleanup.sh"
    exit 1
  fi
fi

CONTAINER="${STATION_CONTAINER:-football-station${STATION_ID}}"
case "$STATION_ID" in
  1) DB_NAME="vleague_hnfc";;
  2) DB_NAME="vleague_cahn";;
  3) DB_NAME="vleague_viettel";;
  4) DB_NAME="vleague_haiphong";;
  5) DB_NAME="vleague_namdinh";;
  6) DB_NAME="vleague_hagl";;
  *) echo "!!! STATION_ID '$STATION_ID' không hợp lệ"; exit 1;;
esac
DB_NAME="${POSTGRES_DB:-$DB_NAME}"

echo "=== station-test-cleanup.sh ==="
echo "  Station $STATION_ID  Container: $CONTAINER  DB: $DB_NAME"
docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" <<SQL
BEGIN;
-- Hỗ trợ cả 2 pattern cũ + mới (TEST_<station>_ vs T<station>+hash)
DELETE FROM su_kien_tran_dau     WHERE MaTran LIKE 'TEST_${STATION_ID}_%' OR MaTran LIKE 'T${STATION_ID}%';
DELETE FROM tran_dau_chuyen_mon  WHERE MaTran LIKE 'TEST_${STATION_ID}_%' OR MaTran LIKE 'T${STATION_ID}%';
COMMIT;
SQL
echo "=== Đã xóa test rows của station $STATION_ID. Đề nghị master chạy lại 'make check-fdw' để confirm count giảm về 30. ==="
