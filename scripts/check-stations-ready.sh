#!/bin/bash
# scripts/check-stations-ready.sh - Kiểm tra 6 station có sẵn sàng cho
# master FDW connect chưa. Chạy TRÊN máy admin (master).
#
# 3 cấp độ check:
#   1. ENV   : .env.master có dòng STATION<N>_HOST=<IP/hostname> không?
#              (giá trị default 'station<N>' = chưa set = FAIL)
#   2. NETWORK: master container có ping/tcp tới host:port đó không?
#   3. PG    : Postgres trên station đó có accepting connection + SELECT 1?
#
# Cách chạy:
#   make check-stations
#   ./scripts/check-stations-ready.sh
#   ./scripts/check-stations-ready.sh -v   # verbose
set -u

CONTAINER="${MASTER_CONTAINER:-football-master}"
DB_PORT="${STATION_PORT:-5432}"
VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

# Mapping STATION_ID -> metadata (dùng case thay cho declare -A để tương
# thích bash 3.2 /bin/sh trên macOS native).
get_clb()  { case "$1" in 1) echo HNFC;; 2) echo CAHN;; 3) echo VTT;; 4) echo HPFC;; 5) echo NDFC;; 6) echo HAGL;; esac; }
get_db()   { case "$1" in 1) echo vleague_hnfc;; 2) echo vleague_cahn;; 3) echo vleague_viettel;; 4) echo vleague_haiphong;; 5) echo vleague_namdinh;; 6) echo vleague_hagl;; esac; }
get_name() { case "$1" in 1) echo "Tuấn";; 2) echo "Thông";; 3) echo "Mạnh Dũng";; 4) echo "Quang Anh";; 5) echo "Ngọc Bích";; 6) echo "Minh Dũng";; esac; }

# Load .env.master (nếu có)
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env.master"
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: Master container '$CONTAINER' chưa chạy. Chạy 'make up' trước."
  exit 2
fi

echo "=== check-stations-ready.sh ==="
echo "Master container: $CONTAINER"
echo "Env file       : $ENV_FILE  ($([ -f "$ENV_FILE" ] && echo 'found' || echo 'MISSING'))"
echo ""
printf "%-3s %-10s %-12s %-22s %-10s %-10s %-15s\n" \
       ID CLB DB HOST ENV NET PG
printf "%-3s %-10s %-12s %-22s %-10s %-10s %-15s\n" \
       -- --- -- ---- --- --- --

ALL_OK=1
for sid in 1 2 3 4 5 6; do
  clb="$(get_clb "$sid")"
  db="$(get_db "$sid")"
  name="$(get_name "$sid")"
  host_var="STATION${sid}_HOST"
  host="${!host_var:-}"

  # Cấp 1: ENV check
  if [ -z "$host" ] || [ "$host" = "station${sid}" ]; then
    printf "%-3s %-10s %-12s %-22s %-10s %-10s %-15s\n" \
      "$sid" "$clb" "$db" "(missing)" "FAIL" "-" "-"
    [ $VERBOSE -eq 1 ] && echo "    -> Sửa .env.master: ${host_var}=<IP máy ${name}>"
    ALL_OK=0
    continue
  fi

  # Cấp 1 OK
  ENV_STATUS="OK"

  # Cấp 2: network reachability (pg_isready trong container master)
  if ! docker exec "$CONTAINER" pg_isready -h "$host" -p "$DB_PORT" -t 3 -U postgres >/dev/null 2>&1; then
    printf "%-3s %-10s %-12s %-22s %-10s %-10s %-15s\n" \
      "$sid" "$clb" "$db" "$host ($name)" "$ENV_STATUS" "FAIL" "-"
    [ $VERBOSE -eq 1 ] && echo "    -> Master container không ping được $host:$DB_PORT. Báo ${name} kiểm tra IP/Postgres."
    ALL_OK=0
    continue
  fi
  NET_STATUS="OK"

  # Cấp 3: SELECT 1 tới station DB
  result=$(docker exec "$CONTAINER" psql -h "$host" -p "$DB_PORT" -U postgres -d "$db" \
           -t -A -c "SELECT 1;" 2>/dev/null || echo "ERR")
  if [ "$result" = "1" ]; then
    PG_STATUS="OK"
  else
    PG_STATUS="FAIL"
    ALL_OK=0
    [ $VERBOSE -eq 1 ] && echo "    -> DB '$db' trên $host không query được. Có thể sai POSTGRES_DB hoặc chưa seed."
    printf "%-3s %-10s %-12s %-22s %-10s %-10s %-15s\n" \
      "$sid" "$clb" "$db" "$host ($name)" "$ENV_STATUS" "$NET_STATUS" "$PG_STATUS"
    continue
  fi

  # Bonus: count rows (chỉ nếu verbose hoặc OK để thay thế)
  tran=$(docker exec "$CONTAINER" psql -h "$host" -p "$DB_PORT" -U postgres -d "$db" \
         -t -A -c "SELECT COUNT(*) FROM tran_dau_chuyen_mon;" 2>/dev/null || echo "?")
  sukien=$(docker exec "$CONTAINER" psql -h "$host" -p "$DB_PORT" -U postgres -d "$db" \
         -t -A -c "SELECT COUNT(*) FROM su_kien_tran_dau;" 2>/dev/null || echo "?")
  printf "%-3s %-10s %-12s %-22s %-10s %-10s %-15s\n" \
    "$sid" "$clb" "$db" "$host ($name)" "$ENV_STATUS" "$NET_STATUS" "$PG_STATUS ($tran/$sukien)"
done

echo ""
echo "=== TỔNG KẾT ==="
if [ $ALL_OK -eq 1 ]; then
  echo "  TẤT CẢ 6 STATION SẴN SÀNG. Có thể chạy: make setup-fdw"
else
  echo "  CÒN STATION FAIL (xem bảng). Cần: "
  echo "    1. Báo bạn có STATION_ID fail sửa/trường IP Postgres healthy rồi báo lại IP"
  echo "    2. Sửa .env.master: STATION<N>_HOST=<IP báo lại>"
  echo "    3. Chạy lại: make check-stations"
  echo "  Khi tất cả OK -> make setup-fdw"
fi
[ $ALL_OK -eq 1 ] && exit 0 || exit 1
