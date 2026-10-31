#!/bin/bash
# scripts/station-fix-and-test.sh - Chạy TRÊN máy trạm.
#
# 2 việc:
#   1. FIX .env.station: ghi đè config cũ (hardcode các giá trị đúng, chỉ giữ
#      STATION_ID + POSTGRES_PORT của user). Khử lỗi như POSTGRES_USER sai,
#      POSTGRES_DB không khớp STATION_ID, password lệch master FDW mapping.
#   2. TEST: station còn healthy không + ping/pg_isready tới master hiện ra.
#
# Cách chạy (trên máy trạm):
#   ./scripts/station-fix-and-test.sh                # hỏi STATION_ID
#   STATION_ID=2 ./scripts/station-fix-and-test.sh   # set trước
#   MASTER_HOST=10.19.227.12 ./scripts/station-fix-and-test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env.station"

# Mapping STATION_ID -> metadata
get_clb()  { case "$1" in 1) echo HNFC;; 2) echo CAHN;; 3) echo VTT;; 4) echo HPFC;; 5) echo NDFC;; 6) echo HAGL;; esac; }
get_db()   { case "$1" in 1) echo vleague_hnfc;; 2) echo vleague_cahn;; 3) echo vleague_viettel;;
                       4) echo vleague_haiphong;; 5) echo vleague_namdinh;; 6) echo vleague_hagl;; esac; }
get_name() { case "$1" in 1) echo "Tuấn";; 2) echo "Thông";; 3) echo "Mạnh Dũng";;
                      4) echo "Quang Anh";; 5) echo "Ngọc Bích";; 6) echo "Minh Dũng";; esac; }

# Auto-detect STATION_ID từ container đang chạy nếu chưa set
if [ -z "${STATION_ID:-}" ]; then
  if [ -f "$ENV_FILE" ]; then
    DETECTED=$(grep -E "^STATION_ID=" "$ENV_FILE" | cut -d= -f2 | tr -d ' \r')
    if [ -n "$DETECTED" ]; then
      STATION_ID="$DETECTED"
    fi
  fi
fi
if [ -z "${STATION_ID:-}" ]; then
  for sid in 1 2 3 4 5 6; do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^football-station${sid}$"; then
      STATION_ID="$sid"
      break
    fi
  done
fi
if [ -z "${STATION_ID:-}" ]; then
  echo "ERROR: STATION_ID chưa xác định. Cách fix:"
  echo "  STATION_ID=2 ./scripts/station-fix-and-test.sh"
  echo "  (2=Thông/CAHN, 3=Mạnh Dũng/Viettel, ...xem HƯỚNG_DẪN_STATION.md)"
  exit 2
fi

case "$STATION_ID" in
  1|2|3|4|5|6) ;;
  *) echo "ERROR: STATION_ID phải 1..6, nhận được '$STATION_ID'"; exit 2 ;;
esac

CLB="$(get_clb "$STATION_ID")"
DB_NAME="$(get_db "$STATION_ID")"
NAME="$(get_name "$STATION_ID")"

# Giữ lại POSTGRES_PORT nếu user đã set trong .env.station cũ
OLD_PORT=""
if [ -f "$ENV_FILE" ]; then
  OLD_PORT=$(grep -E "^POSTGRES_PORT=" "$ENV_FILE" | cut -d= -f2 | tr -d ' \r')
fi
[ -z "$OLD_PORT" ] && OLD_PORT="5432"

# =============================================================================
# PHẦN 1: FIX .env.station (HARDCODE)
# =============================================================================
echo "=== PHẦN 1: GHI ĐÈ .env.station ==="
echo "  STATION_ID    : $STATION_ID"
echo "  Bạn là        : $NAME ($CLB)"
echo "  POSTGRES_DB   : $DB_NAME   (map cho STATION_ID $STATION_ID)"
echo "  POSTGRES_USER : postgres   (HARDCODE - phải khớp master FDW)"
echo "  POSTGRES_PASS : ******     (HARDCODE - phải khớp master FDW)"
echo "  POSTGRES_PORT : $OLD_PORT   (giữ giá trị cũ nếu có)"
echo "  File          : $ENV_FILE"
echo ""

# Backup file cũ nếu có
if [ -f "$ENV_FILE" ]; then
  BACKUP="$ENV_FILE.bak.$(date +%s)"
  cp "$ENV_FILE" "$BACKUP"
  echo "  Old .env.station đã backup: $BACKUP"
fi

# Ghi file mới HARDCODE
cat > "$ENV_FILE" <<EOF
# .env.station - auto-generated bởi scripts/station-fix-and-test.sh
# Hardcode các giá trị phải khớp master FDW (xem db/master/20_fdw_setup.sql).
# Đừng sửa trừ STATION_ID/POSTGRES_PORT. Khi sai, chạy lại script này.

STATION_ID=$STATION_ID
NODE_ROLE=station
POSTGRES_USER=postgres
POSTGRES_PASSWORD=123456
POSTGRES_DB=$DB_NAME
POSTGRES_PORT=$OLD_PORT
NETWORK_NAME=football-net
EOF

echo "  Đã ghi đè OK."
echo ""
# Show
echo "  --- nội dung ---"
grep -vE "^#|^$" "$ENV_FILE" | sed 's/^/    /'
echo "  ----------------"
echo ""

# =============================================================================
# PHẦN 2: TEST connection
# =============================================================================
echo "=== PHẦN 2: TEST CONNECTION ==="

# Load .env.station vừa tạo
set -a
. "$ENV_FILE"
set +a

printf "%-30s %-8s %-25s %s\n" "CHECK" "STATUS" "DETAIL" "HINT (nếu FAIL)"
printf "%-30s %-8s %-25s %s\n" "------------------------------" "------" "-------------------------" "-------------"

ALL_OK=1
ok()   { printf "%-30s %-8s %-25s %s\n" "$1" "OK"   "$2" ""; }
fail() { printf "%-30s %-8s %-25s %s\n" "$1" "FAIL" "$2" "${3:-}"; ALL_OK=0; }

# --- 2.1. Station Postgres (local) ---
echo "  [station internal]"
DOCKER_CONTAINER="football-station${STATION_ID}"
PSQL_LOCAL=""
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${DOCKER_CONTAINER}$"; then
  PSQL_LOCAL="docker exec $DOCKER_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -t -A -c"
  if docker exec "$DOCKER_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c "SELECT 1" 2>/dev/null | grep -q "^1$"; then
    TRAN=$(docker exec "$DOCKER_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c "SELECT COUNT(*) FROM tran_dau_chuyen_mon" 2>/dev/null || echo "?")
    ok "  2.1 Station Postgres (Docker)"  "Container OK, tran=$TRAN"
  else
    fail "  2.1 Station Postgres (Docker)" "psql fail" "docker logs $DOCKER_CONTAINER"
  fi
elif command -v psql >/dev/null 2>&1 || [ -x /usr/local/Cellar/libpq/*/bin/psql 2>/dev/null ]; then
  PSQL_BIN=$(command -v psql 2>/dev/null || ls /usr/local/Cellar/libpq/*/bin/psql 2>/dev/null | head -1)
  if PGPASSWORD="$POSTGRES_PASSWORD" "$PSQL_BIN" -h 127.0.0.1 -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c "SELECT 1" 2>/dev/null | grep -q "^1$"; then
    TRAN=$(PGPASSWORD="$POSTGRES_PASSWORD" "$PSQL_BIN" -h 127.0.0.1 -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c "SELECT COUNT(*) FROM tran_dau_chuyen_mon" 2>/dev/null || echo "?")
    ok "  2.1 Station Postgres (native)" "psql OK, tran=$TRAN"
    PSQL_LOCAL="PGPASSWORD=$POSTGRES_PASSWORD $PSQL_BIN -h 127.0.0.1 -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -t -A -c"
  else
    fail "  2.1 Station Postgres (native)" "psql fail" "Check service postgres chạy không: 'sudo service postgresql status'"
    PSQL_LOCAL=""
  fi
else
  fail "  2.1 Station Postgres" "không có Docker container lẫn native psql" "Chạy station container theo HƯỚNG_DẪN_STATION.md"
  PSQL_LOCAL=""
fi

# --- 2.2. Station DB đúng mapping ---
if [ -n "$PSQL_LOCAL" ]; then
  ACTUAL_DB=$(eval "$PSQL_LOCAL 'SELECT current_database();'" 2>/dev/null)
  if [ "$ACTUAL_DB" = "$POSTGRES_DB" ]; then
    ok "  2.2 Station DB khớp mapping" "current_database() = $ACTUAL_DB"
  else
    fail "  2.2 Station DB khớp mapping" "expected $POSTGRES_DB, actual $ACTUAL_DB" "down container, sửa .env.station, up lại với volume mới (down -v)"
  fi
fi
echo ""

# --- 2.3. Master reachability ---
echo "  [master reach from station]"
MASTER_HOST="${MASTER_HOST:-10.19.227.12}"
MASTER_PORT="${MASTER_PORT:-5430}"
echo "  Master host:port : $MASTER_HOST:$MASTER_PORT"

# Ping
echo -n "  2.3 Ping master..."
PING_OK=0
if command -v ping >/dev/null 2>&1; then
  if ping -c 2 -W 2 "$MASTER_HOST" >/dev/null 2>&1; then
    echo " OK"; PING_OK=1
  else
    echo " FAIL (timeout/no response)"
  fi
elif command -v Test-NetConnection >/dev/null 2>&1; then
  if Test-NetConnection -ComputerName "$MASTER_HOST" -Port "$MASTER_PORT" -InformationLevel Quiet >/dev/null 2>&1; then
    echo " OK (Windows)"; PING_OK=1
  else
    echo " FAIL (Windows)"
  fi
else
  echo " SKIP (no ping/Test-NetConnection)"
fi

if [ $PING_OK -eq 1 ]; then
  ok "  2.4 Ping master ($MASTER_HOST)" "reachable"
else
  fail "  2.4 Ping master ($MASTER_HOST)" "không ping được" "Check mạng: VPN/LAN có thông master không. Báo admin IP master có đúng không."
fi

# pg_isready tới master (mượn docker psql nếu có, hoặ) native)
PG_ISREADY_CMD=""
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${DOCKER_CONTAINER}$"; then
  PG_ISREADY_CMD="docker exec $DOCKER_CONTAINER pg_isready -h $MASTER_HOST -p $MASTER_PORT -t 5 -U postgres"
elif command -v pg_isready >/dev/null 2>&1; then
  PG_ISREADY_CMD="pg_isready -h $MASTER_HOST -p $MASTER_PORT -t 5 -U postgres"
elif [ -x /usr/local/Cellar/libpq/*/bin/pg_isready 2>/dev/null ]; then
  PG_ISREADY_CMD="$(ls /usr/local/Cellar/libpq/*/bin/pg_isready | head -1) -h $MASTER_HOST -p $MASTER_PORT -t 5 -U postgres"
fi

if [ -n "$PG_ISREADY_CMD" ]; then
  if eval "$PG_ISREADY_CMD" 2>/dev/null | grep -q "accepting connections"; then
    ok "  2.5 Master Postgres accept"  "$MASTER_HOST:$MASTER_PORT accepting"
  else
    fail "  2.5 Master Postgres accept" "$MASTER_HOST:$MASTER_PORT không accept" "Admin chạy 'make ps' check football-master healthy. Port forward 5430:5432 chưa?"
  fi
else
  echo "  2.5 Master Postgres accept : SKIP (no pg_isready available)"
fi

# --- 2.6. Station có listen + pg_hba cho master subnet không (master connect tới mình) ---
echo ""
echo "  [master connect tới station (mũi ngược)]"
if [ -n "$PSQL_LOCAL" ]; then
  LISTEN=$(eval "$PSQL_LOCAL 'SHOW listen_addresses;'" 2>/dev/null)
  if echo "$LISTEN" | grep -qE '^\*|0\.0\.0\.0|,'; then
    ok "  2.6 Station listen_addresses" "$LISTEN"
  else
    fail "  2.6 Station listen_addresses" "$LISTEN" "Cần listen_addresses='*' để master connect tới. Docker default = '*' nên thường OK."
  fi

  # pg_hba cho LAN/ZeroTier
  HBA=$(eval "$PSQL_LOCAL 'SELECT pg_read_file('"'"'pg_hba.conf'"'"');'" 2>/dev/null || echo "?")
  HBA_ACTIVE=$(echo "$HBA" | grep -E "^host" | grep -vE "127\.0\.0\.1/32|::1/128|^local" || true)
  if echo "$HBA_ACTIVE" | grep -qE "10\.(147|19|20|200)\.|10\.0\.0\.0/8|0\.0\.0\.0/0|all\s+all"; then
    ok "  2.7 Station pg_hba remote"  "đã accept remote subnet"
  else
    fail "  2.7 Station pg_hba remote" "chỉ localhost rule" "Thêm 'host all all 10.0.0.0/8 trust' vào pg_hba.conf + SELECT pg_reload_conf();"
  fi
fi

# =============================================================================
# Tổng kết
# =============================================================================
echo ""
echo "=== TỔNG KẾT ==="
if [ $ALL_OK -eq 1 ]; then
  echo "  STATION $STATION_ID ($CLB - $NAME) ĐÃ SẴN SÀNG VÀ CONNECT MASTER OK."
  echo ""
  echo "  Báo admin master:"
  echo "    \"Mình là $NAME - station $STATION_ID ($CLB)."
  echo "    Đã fix .env.station + verify xong. Master reach OK. Cậu setup-fdw nhé!\""
  echo ""
  echo "  Lấy IP máy bạn rồi gửi admin:"
  echo "    ip addr | grep -E 'inet 10\\.'"
  echo "    (hoặc: ifconfig | grep 'inet 10')"
else
  echo "  CÒN FAIL. Sửa các mục FAIL ở trên rồi chạy lại:"
  echo "    ./scripts/station-fix-and-test.sh"
  echo ""
  echo "  Nếu vẫn fail, hỏi admin hoặc xem HƯỚNG_DẪN_STATION.md mục 11 (Troubleshooting)."
fi
[ $ALL_OK -eq 1 ] && exit 0 || exit 1
