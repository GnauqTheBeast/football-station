#!/bin/bash
# ============================================================================
# station-rebuild-remote.sh - Rebuild station REMOTE qua psql (ZeroTier)
# Chay TREN MAY MASTER (admin). Khong can SSH/docker tren may tram.
#
# Cach hoat dong:
#   - Doc STATION<N>_HOST + STATION<N>_PORT tu .env.master
#   - Test connectivity tung station (psql SELECT 1)
#   - Station ONLINE: chay db/station_<N>/00_init.sql trong 1 transaction
#     (init idempotent: DROP truoc CREATE; loi la rollback, DB giu nguyen)
#   - Station OFFLINE: bo qua (bao thong bao)
#
# Cach dung:
#   ./scripts/station-rebuild-remote.sh              # rebuild tat ca station online
#   ./scripts/station-rebuild-remote.sh 2 6          # chi rebuild station 2, 6
#   ./scripts/station-rebuild-remote.sh --check      # chi check connectivity
# ============================================================================
set -e

cd "$(dirname "$0")/.."

# Load .env.master (STATION<N>_HOST, STATION<N>_PORT)
if [ -f .env.master ]; then
  set -a
  # . .env.master  (source)
  . ./.env.master
  set +a
fi

# Mapping station N -> ten DB
db_name() {
  case "$1" in
    1) echo "vleague_hnfc" ;;
    2) echo "vleague_cahn" ;;
    3) echo "vleague_viettel" ;;
    4) echo "vleague_haiphong" ;;
    5) echo "vleague_namdinh" ;;
    6) echo "vleague_hagl" ;;
    *) echo "" ;;
  esac
}

# Lay host/port cua station N
get_host() { eval echo "\$STATION${1}_HOST"; }
get_port() { eval echo "\$STATION${1}_PORT"; }

# Test connectivity (tra ve 0 neu online)
test_conn() {
  local n="$1"
  local host=$(get_host "$n") port=$(get_port "$n") db=$(db_name "$n")
  local out
  out=$(docker exec -e PGPASSWORD=123456 football-master psql \
    "host=$host port=$port user=postgres dbname=$db connect_timeout=4" \
    -t -A -c "SELECT 1;" 2>&1)
  echo "$out" | grep -q "^1$"
}

# Chay init tren station N (trong 1 transaction)
run_init() {
  local n="$1"
  local host=$(get_host "$n") port=$(get_port "$n") db=$(db_name "$n")
  local init_file="db/station_$n/00_init.sql"
  if [ ! -f "$init_file" ]; then
    echo ">>> STATION $n: KHONG TAY $init_file"
    return 1
  fi
  echo "===== STATION $n ($host:$port/$db) ====="
  local out
  out=$( { echo "BEGIN;"; cat "$init_file"; echo "COMMIT;"; } | \
    docker exec -i -e PGPASSWORD=123456 football-master psql \
      "host=$host port=$port user=postgres dbname=$db connect_timeout=20" \
      -v ON_ERROR_STOP=1 2>&1 )
  if echo "$out" | grep -qE "^ERROR"; then
    echo ">>> STATION $n: THAT BAI (da rollback, DB giu nguyen)"
    echo "$out" | grep -E "^ERROR|^DETAIL" | head -6
    return 1
  fi
  echo ">>> STATION $n: OK (da commit)"
  docker exec -e PGPASSWORD=123456 football-master psql \
    "host=$host port=$port user=postgres dbname=$db connect_timeout=10" \
    -t -A -c "
      SELECT 'tables='||(SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE')
        || ' tdc='||(SELECT COUNT(*) FROM tran_dau_chuyen_mon)
        || ' dk='||(SELECT COUNT(*) FROM dang_ky_thi_dau)
        || ' sk='||(SELECT COUNT(*) FROM su_kien_tran_dau)
        || ' triggers='||(SELECT COUNT(*) FROM pg_trigger WHERE NOT tgisinternal);
    " 2>&1
  return 0
}

# --- Main ---
if [ "$1" = "--check" ]; then
  echo "=== Check connectivity 6 station ==="
  for n in 1 2 3 4 5 6; do
    if test_conn "$n"; then
      echo "ST $n: ONLINE"
    else
      echo "ST $n: OFFLINE"
    fi
  done
  exit 0
fi

# Xac dinh station can rebuild (co tham so = chi chay nhung do, khong co = tat ca)
if [ $# -gt 0 ]; then
  STATIONS=("$@")
else
  STATIONS=(1 2 3 4 5 6)
fi

echo "=== Rebuild remote: station ${STATIONS[*]} ==="
for n in "${STATIONS[@]}"; do
  if test_conn "$n"; then
    run_init "$n"
  else
    echo "===== STATION $n: OFFLINE (bo qua) ====="
  fi
  echo ""
done
echo "=== XONG ==="