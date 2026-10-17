#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/start-station.sh
#
# Chỉ chạy trên MÁY TRẠM. Dựng station DB, áp dụng migration, tạo subscription
# kéo ref.* từ master (master -> station), rồi "listen" — theo dõi log của
# station container để xem dữ liệu tham chiếu từ master trôi về trạm trong
# thời gian thực.
#
# Cách dùng:
#   ./scripts/start-station.sh            # dùng .env.station mặc định
#   ENV_FILE=.env.station ./scripts/start-station.sh
#
# Yêu cầu: .env.station đã được sửa MASTER_HOST / MASTER_PORT trỏ tới máy chủ
# (VPN IP + host port nếu master ở laptop khác theo Tailscale/ZeroTier/LAN).
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env.station}"

# shellcheck disable=SC1090
if [ -f "$ENV_FILE" ]; then
  set -a; . "$ENV_FILE"; set +a
else
  echo "❌ không thấy env file: $ENV_FILE" >&2
  exit 1
fi

: "${POSTGRES_USER:?POSTGRES_USER chưa đặt trong $ENV_FILE}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD chưa đặt trong $ENV_FILE}"
: "${POSTGRES_DB:?POSTGRES_DB chưa đặt trong $ENV_FILE}"
: "${POSTGRES_PORT:?POSTGRES_PORT chưa đặt trong $ENV_FILE}"
: "${CONTAINER_NAME:?CONTAINER_NAME chưa đặt trong $ENV_FILE}"
: "${MASTER_HOST:?MASTER_HOST chưa đặt trong $ENV_FILE — sửa $ENV_FILE trỏ tới máy chủ}"
: "${MASTER_PORT:?MASTER_PORT chưa đặt trong $ENV_FILE}"
: "${STATION_PUBLIC_HOST:?STATION_PUBLIC_HOST chưa đặt trong $ENV_FILE — đây là IP master dùng để quay lại station}"
: "${STATION_PUBLIC_PORT:?STATION_PUBLIC_PORT chưa đặt trong $ENV_FILE}"

NETWORK_NAME="${NETWORK_NAME:-football-net}"
COMPOSE=(docker compose -f "$ROOT_DIR/docker-compose.yml" -p football-station --env-file "$ENV_FILE")

log()  { printf '\033[1;36m[start-station]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[start-station:ERR]\033[0m %s\n' "$*" >&2; }

# 1) Docker network ngoài (cần một lần mỗi máy).
#    Dùng subnet tĩnh 10.200.0.0/24 để không xung đột với dải LAN 172.x
#    (đặc biệt 172.18.x.x là subnet mặc định của Docker bridge). Nếu không
#    set subnet, container có thể route IP LAN sai và master không reach
#    được tới station.
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  log "tạo docker network: $NETWORK_NAME (subnet 10.200.0.0/24)"
  docker network create --subnet 10.200.0.0/24 "$NETWORK_NAME"
else
  log "docker network '$NETWORK_NAME' đã có sẵn"
  # Cảnh báo nếu subnet đang xung đột với LAN 172.18.x.x.
  SUBNET=$(docker network inspect "$NETWORK_NAME" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)
  case "$SUBNET" in
    172.18.*)
      err "CẢNH BÁO: network $NETWORK_NAME đang dùng subnet $SUBNET — xung đột với LAN 172.18.x.x."
      err "Master container có thể KHÔNG reach tới station. Drop và tạo lại:"
      err "    docker network rm $NETWORK_NAME && docker network create --subnet 10.200.0.0/24 $NETWORK_NAME"
      ;;
  esac
fi

# 2) docker compose up station.
log "khởi động station container..."
"${COMPOSE[@]}" up -d

# 3) Đợi postgres sẵn sàng.
log "đợi postgres sẵn sàng..."
for i in $(seq 1 60); do
  if docker exec "$CONTAINER_NAME" \
       pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
    break
  fi
  sleep 1
  if [ "$i" -eq 60 ]; then
    err "postgres chưa sẵn sàng sau 60s"
    exit 1
  fi
done
log "postgres sẵn sàng."

# 4) Migration: áp dụng lại /db/common + /db/station (đều IF NOT EXISTS, idempotent).
log "áp dụng migration (common + station)..."
docker exec "$CONTAINER_NAME" bash /docker-entrypoint-initdb.d/init-node.sh

# 5) Subscribe master -> station (ref.team, ref.match, ...). Idempotent.
log "tạo / kiểm tra master_subscription (ref.* master -> station)..."
docker exec "$CONTAINER_NAME" bash /subscribe-master.sh

# 5b) Tự đăng ký với master: station psql sang master và tạo station_subscription
#     (demo.message station -> master) ngay tại đây, không cần master chạy lệnh.
log "đăng ký station_subscription trên master (demo.message station -> master)..."
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" \
  -e STATION_PUBLIC_HOST="$STATION_PUBLIC_HOST" \
  -e STATION_PUBLIC_PORT="$STATION_PUBLIC_PORT" \
  -e STATION_PUBLIC_DB="$STATION_PUBLIC_DB" \
  "$CONTAINER_NAME" bash /register-with-master.sh

# 6) Trạng thái subscription (cả 2 phía).
log "trạng thái subscription trên station:"
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -c "SELECT subname, subenabled, subpublications FROM pg_subscription ORDER BY subname;"

log "trạng thái subscription trên master:"
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER_NAME" \
  psql -h "$MASTER_HOST" -p "$MASTER_PORT" -U "$POSTGRES_USER" -d "${MASTER_DB:-$POSTGRES_DB}" \
  -c "SELECT subname, subenabled, subpublications FROM pg_subscription ORDER BY subname;"

# 7) Listen: theo dõi log station để xem master -> station replication.
log "theo dõi log station (cả 2 chiều replication). Nhấn Ctrl-C để dừng."
log "ping master từ station container: ${MASTER_HOST}:${MASTER_PORT}"
docker exec "$CONTAINER_NAME" pg_isready -h "$MASTER_HOST" -p "$MASTER_PORT" \
  -U "$POSTGRES_USER" -d "${MASTER_DB:-$POSTGRES_DB}" || \
  err "không kết nối được tới master ${MASTER_HOST}:${MASTER_PORT} — kiểm tra VPN/firewall/port."

"${COMPOSE[@]}" logs -f --tail=50
