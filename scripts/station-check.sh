#!/bin/bash
# scripts/station-check.sh - Chạy TRÊN máy trạm (station - máy bạn của 5 bạn).
# Kiểm tra station đã config đủ để master có thể connect qua FDW chưa.
#
# 5 cấp độ check (đi từ local -> remote):
#   1. LOCAL  : Postgres (Docker container HOẶC native) đang chạy?
#   2. SEED   : DB name khớp STATION_ID + đã seed data (5 trận + 21-31 sự kiện)?
#   3. LISTEN : Postgres listen_addresses='*' (chấp nhận remote)?
#   4. PG_HBA : pg_hba.conf có rule cho phép master subnet connect?
#   5. IP     : Station có IP LAN/ZeroTier để báo cho admin master?
#   6. (optional) MASTER reach: ping được tới master host (nếu MASTER_HOST set)
#
# Cách chạy (trên máy trạm):
#   ./scripts/station-check.sh
#   STATION_ID=2 ./scripts/station-check.sh
#   MASTER_HOST=10.19.227.12 ./scripts/station-check.sh
#   ./scripts/station-check.sh -v   # verbose
set -u

VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

# Auto-detect STATION_ID từ container đang chạy nếu chưa set
if [ -z "${STATION_ID:-}" ]; then
  for sid in 1 2 3 4 5 6; do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^football-station${sid}$"; then
      STATION_ID="$sid"
      break
    fi
  done
fi

if [ -z "${STATION_ID:-}" ]; then
  echo "ERROR: STATION_ID không xác định được."
  echo "  Set env: STATION_ID=2 ./scripts/station-check.sh"
  echo "  Hoặc chạy station container 'football-station<N>' trước."
  exit 2
fi

# Mapping STATION_ID -> metadata
get_clb()  { case "$1" in 1) echo HNFC;; 2) echo CAHN;; 3) echo VTT;; 4) echo HPFC;; 5) echo NDFC;; 6) echo HAGL;; esac; }
get_db()   { case "$1" in 1) echo vleague_hnfc;; 2) echo vleague_cahn;; 3) echo vleague_viettel;;
                       4) echo vleague_haiphong;; 5) echo vleague_namdinh;; 6) echo vleague_hagl;; esac; }
get_name() { case "$1" in 1) echo "Tuấn";; 2) echo "Thông";; 3) echo "Mạnh Dũng";;
                      4) echo "Quang Anh";; 5) echo "Ngọc Bích";; 6) echo "Minh Dũng";; esac; }

CLB="$(get_clb "$STATION_ID")"
DB_NAME_EXPECTED="$(get_db "$STATION_ID")"
NAME="$(get_name "$STATION_ID")"

echo "=== station-check.sh ==="
echo "  Bạn là      : Station $STATION_ID ($CLB) - $NAME"
echo "  DB expected  : $DB_NAME_EXPECTED"
if [ -n "${STATION_HOST:-}" ] && [ "${STATION_HOST:-}" != "127.0.0.1" ]; then
  echo "  host test    : $STATION_HOST (override - test remote thay vì localhost)"
fi
echo ""

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-123456}"
STATION_PORT="${STATION_PORT:-5432}"

# Phát hiện mode: Docker (container football-station<N>) HAY native Postgres
DOCKER_CONTAINER="football-station${STATION_ID}"
CONTAINER_RUNNING=0
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${DOCKER_CONTAINER}$"; then
  CONTAINER_RUNNING=1
  MODE="docker"
  CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DOCKER_CONTAINER" 2>/dev/null)
  echo "  Mode         : Docker (container '$DOCKER_CONTAINER', IP ${CONTAINER_IP:-unknown})"
elif command -v psql >/dev/null 2>&1; then
  MODE="native"
  echo "  Mode         : Native Postgres (psql client ở \$PATH)"
else
  echo "ERROR: Không phát hiện Docker container '$DOCKER_CONTAINER' lẫn native psql."
  echo "  - Nếu dùng Docker: chạy 'docker compose ... up -d' trước (xem HƯỚNG_DẪN_STATION.md)."
  echo "  - Nếu dùng native Postgres: cài psql client (brew install libpq / apt install postgresql-client)."
  exit 2
fi
echo ""

# ============================================================================
# Helper: chạy psql theo mode phát hiện
# ============================================================================
psql_local() {
  local target_host="${STATION_HOST:-127.0.0.1}"
  if [ "$MODE" = "docker" ]; then
    docker exec "$DOCKER_CONTAINER" psql -U "$POSTGRES_USER" -d "$1" -t -A -c "$2"
  else
    # Native: mặc định localhost; có thể override qua STATION_HOST để test remote
    if [ "$target_host" = "127.0.0.1" ] || [ "$target_host" = "localhost" ]; then
      # Thử socket local trước (Homebrew Postgres on macOS default không listen TCP),
      # fallback sau đó TCP nếu socket fail
      if PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -d "$1" -t -A -c "$2" 2>/dev/null; then
        :
      else
        PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$target_host" -p "$STATION_PORT" -U "$POSTGRES_USER" -d "$1" -t -A -c "$2"
      fi
    else
      PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$target_host" -p "$STATION_PORT" -U "$POSTGRES_USER" -d "$1" -t -A -c "$2"
    fi
  fi
}

psql_exists_db() {
  psql_local "postgres" "SELECT 1 FROM pg_database WHERE datname='$1';" 2>/dev/null | grep -q "^1$"
}

printf "%-22s %-8s %-10s %s\n" "KIỂM TRA" "STATUS" "DETAIL" "HINT (nếu FAIL)"
printf "%-22s %-8s %-10s %s\n" "--------" "------" "------" "-------------"
ALL_OK=1
fail()  { printf "%-22s %-8s %-10s %s\n" "$1" "FAIL" "$2" "${3:-}"; ALL_OK=0; }
ok()    { printf "%-22s %-8s %-10s %s\n" "$1" "OK"   "$2" ""; }

# ----------------------------------------------------------------------------
# 1. LOCAL: Postgres chạy được không (SELECT 1)
# ----------------------------------------------------------------------------
if psql_local "postgres" "SELECT 1;" 2>/dev/null | grep -q "^1$"; then
  ok "1. POSTGRES RUNNING" "psql SELECT 1 = 1"
else
  fail "1. POSTGRES RUNNING" "tiếp connection" "Docker: 'docker logs $DOCKER_CONTAINER'. Native: 'sudo service postgresql status'"
  printf "%-22s %-8s %-10s %s\n" "" "-" "-" "Nếu native Postgres chưa start: 'sudo service postgresql start' (Linux) / 'brew services start postgresql' (Mac)"
  exit 1
fi

# ----------------------------------------------------------------------------
# 2. SEED: DB name khớp STATION_ID + đã seed (5 trận + 21-31 sự kiện)
# ----------------------------------------------------------------------------
if psql_exists_db "$DB_NAME_EXPECTED"; then
  ok "2. DB EXISTS" "DB '$DB_NAME_EXPECTED' OK"
else
  fail "2. DB EXISTS" "DB '$DB_NAME_EXPECTED' missing" "Chạy DB init script (xem HƯỚNG_DẪN_STATION.md mục 6). POSTGRES_DB phải = '$DB_NAME_EXPECTED'."
  [ $VERBOSE -eq 1 ] && echo "    DBs hiện có:" && psql_local "postgres" "SELECT datname FROM pg_database WHERE datname LIKE 'vleague%';" | sed 's/^/      - /'
  printf "%-22s %-8s %-10s %s\n" "" "-" "-" "Sau khi tạo DB, chạy seed SQL từ db/station_${STATION_ID}/00_init.sql"
  ALL_OK=0
  # Không continue, vẫn check tiếp các bước khác
fi

# Count rows
if psql_exists_db "$DB_NAME_EXPECTED" && psql_local "$DB_NAME_EXPECTED" "SELECT to_regclass('tran_dau_chuyen_mon');" 2>/dev/null | grep -q "tran_dau_chuyen_mon"; then
  TRAN_COUNT=$(psql_local "$DB_NAME_EXPECTED" "SELECT COUNT(*) FROM tran_dau_chuyen_mon;" 2>/dev/null || echo "?")
  SUKIEN_COUNT=$(psql_local "$DB_NAME_EXPECTED" "SELECT COUNT(*) FROM su_kien_tran_dau;" 2>/dev/null || echo "?")
  if [ "$TRAN_COUNT" = "5" ] && [ "$SUKIEN_COUNT" != "?" ] && [ "$SUKIEN_COUNT" -ge 20 ] 2>/dev/null; then
    ok "3. SEED DATA"        "tran=$TRAN_COUNT, su_kien=$SUKIEN_COUNT (OK)"
  else
    fail "3. SEED DATA" "tran=$TRAN_COUNT, su_kien=$SUKIEN_COUNT" "Cần tran=5, su_kien=21-31. Re-run seed script (xem HƯỚNG_DẪN_STATION.md mục 2-3)."
  fi
else
  fail "3. SEED DATA" "bảng tran_dau_chuyen_mon không tồn tại" "Chạy SQL seed trong DB '$DB_NAME_EXPECTED'."
fi

# ----------------------------------------------------------------------------
# 4. LISTEN: Postgres listen_addresses có chấp nhận remote không
# ----------------------------------------------------------------------------
LISTEN_ADDRESSES=$(psql_local "postgres" "SHOW listen_addresses;" 2>/dev/null || echo "?")
if echo "$LISTEN_ADDRESSES" | grep -qE '^\*|0\.0\.0\.0|,'; then
  ok "4. LISTEN_ADDRESSES" "$LISTEN_ADDRESSES"
else
  fail "4. LISTEN_ADDRESSES" "$LISTEN_ADDRESSES" "Cần listen_addresses = '*' (postgresql.conf). Docker: ALTER SYSTEM SET listen_addresses='*'; SELECT pg_reload_conf();"
  [ $VERBOSE -eq 1 ] && echo "    -> Native: sửa postgresql.conf + reload. Docker default thường là '*' trong image postgres:16-alpine."
fi

# ----------------------------------------------------------------------------
# 5. PG_HBA: có rule cho phép master subnet remote connect không
# ----------------------------------------------------------------------------
PG_HBA_CONTENT=$(psql_local "postgres" "SELECT pg_read_file('pg_hba.conf');" 2>/dev/null || echo "?")
# Match các subnet LAN/ZeroTier/Docker. Bất kỳ rule nào 'host all all <IP>/mask' remote
# (không phải 127.0.0.1/32 hay ::1) đều được.
PG_HBA_REMOTE=0
PG_HBA_MATCH="không có"
# Lọc chỉ dòng active (bắt đầu 'host'), loại localhost-only
HBA_ACTIVE=$(echo "$PG_HBA_CONTENT" | grep -E "^host" | grep -vE "127\.0\.0\.1/32|::1/128|^local" || true)
if echo "$HBA_ACTIVE" | grep -qE "10\.(147|19|20|200)\.|10\.0\.0\.0/8|0\.0\.0\.0/0"; then
  PG_HBA_REMOTE=1
  PG_HBA_MATCH=$(echo "$HBA_ACTIVE" | grep -oE "10\.[0-9.]+/[0-9]+|0\.0\.0\.0/0" | head -1)
  PG_HBA_MATCH="match $PG_HBA_MATCH"
elif echo "$HBA_ACTIVE" | grep -qE "host\s+all\s+all\s+all\b"; then
  PG_HBA_REMOTE=1
  PG_HBA_MATCH="'all' (Docker postgres default)"
fi
if [ $PG_HBA_REMOTE -eq 1 ]; then
  ok "5. PG_HBA REMOTE" "$PG_HBA_MATCH"
else
  fail "5. PG_HBA REMOTE" "chỉ có localhost rule" 
  printf "%-22s %-8s %-10s %s\n" "" "-" "-" "Thêm vào pg_hba.conf:"
  printf "%-22s %-8s %-10s %s\n" "" "-" "-" "  host all all 10.19.227.0/24 trust   (LAN subnet của máy master)"
  printf "%-22s %-8s %-10s %s\n" "" "-" "-" "  host all all 10.147.17.0/24 trust  (ZeroTier subnet nếu dùng)"
  printf "%-22s %-8s %-10s %s\n" "" "-" "-" "Sau đó: SELECT pg_reload_conf();"
  [ $VERBOSE -eq 1 ] && echo "    pg_hba active lines:" && echo "$HBA_ACTIVE" | sed 's/^/      /'
fi

# ----------------------------------------------------------------------------
# 6. STATION IP: IP LAN/ZeroTier để báo admin master
# ----------------------------------------------------------------------------
echo ""
echo "=== IP của máy bạn (gửi IP này cho admin master) ==="
IPS_FOUND=0

# ZeroTier (nếu có interface zt*)
echo "  ZeroTier interface (nếu có cài ZeroTier):"
ZT_IPS=$(ip -4 addr show 2>/dev/null | grep -E "^[0-9]+: zt" -A2 | grep "inet " | awk '{print $2}' | cut -d/ -f1 || true)
if [ -n "$ZT_IPS" ]; then
  echo "$ZT_IPS" | sed 's/^/    /'
  IPS_FOUND=1
else
  echo "    (không có interface zt* - có thể chưa cài ZeroTier, dùng IP LAN cũng được)"
fi

# LAN IPs (loại bỏ localhost + Docker internal)
echo "  LAN IPs (loại bỏ 127.x, 172.17-31.x Docker, 10.200.x Docker trong repo này):"
LAN_IPS=$(ip -4 addr show 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 \
  | grep -vE "^127\.|^172\.(1[6-9]|2[0-9]|3[01])\.|^10\.200\.|^192\.168\.|^169\.254" || true)
if [ -n "$LAN_IPS" ]; then
  echo "$LAN_IPS" | sed 's/^/    /'
  IPS_FOUND=1
else
  echo "    (không thấy - thử 'ifconfig | grep inet' trên Mac, hoặc 'ip addr' trên Linux)"
fi

# macOS ifconfig fallback
if [ "$IPS_FOUND" -eq 0 ] && command -v ifconfig >/dev/null 2>&1; then
  echo "  ifconfig (macOS fallback):"
  ifconfig 2>/dev/null | grep "inet " | awk '{print $2}' \
    | grep -vE "^127\.|^172\.|^10\.200\.|^192\.168\." | head -5 | sed 's/^/    /'
fi

# ----------------------------------------------------------------------------
# 7. (Optional) MASTER reach: ping được tới master không (nếu MASTER_HOST set)
# ----------------------------------------------------------------------------
if [ -n "${MASTER_HOST:-}" ]; then
  echo ""
  echo "=== 7. MASTER reach (test ping tới admin master) ==="
  if command -v ping >/dev/null 2>&1; then
    if ping -c 2 -W 2 "$MASTER_HOST" >/dev/null 2>&1; then
      ok "7. MASTER PING" "$MASTER_HOST reachable"
    else
      fail "7. MASTER PING" "$MASTER_HOST không ping được" "Kiểm tra mạng VPN/LAN có thông tới master không"
    fi
  else
    echo "  SKIP: lệnh 'ping' không có (Windows: dùng 'Test-NetConnection $MASTER_HOST -Port 5430')"
  fi
else
  echo ""
  echo "  (SKIP 7. Để test ping master: MASTER_HOST=10.x.x.x ./scripts/station-check.sh)"
fi

# ----------------------------------------------------------------------------
# Tổng kết
# ----------------------------------------------------------------------------
echo ""
echo "=== TỔNG KẾT ==="
if [ $ALL_OK -eq 1 ]; then
  echo "  STATION $STATION_ID ($CLB) SẴN SÀNG. Gửi IP này cho admin master:"
  echo ""
  echo "  > \"Quang ơi, mình là $NAME (station $STATION_ID - $CLB)."
  echo "  > IP máy mình là: <dán IP từ list trên>"
  echo "  > Đã check:(local OK, seed OK, listen OK). Cậu setup-fdw nhé.\""
  echo ""
  echo "  ADMIN sẽ chạy:"
  echo "    - Sửa .env.master: STATION${STATION_ID}_HOST=<IP của bạn>"
  echo "    - make check-stations   (verify từ master)"
  echo "    - make setup-fdw"
else
  echo "  CÒN CHECK FAIL. Sửa các mục FAIL ở trên rồi chạy lại:"
  echo "    ./scripts/station-check.sh"
fi
[ $ALL_OK -eq 1 ] && exit 0 || exit 1
