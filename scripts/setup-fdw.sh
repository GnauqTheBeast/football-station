#!/bin/bash
# scripts/setup-fdw.sh - Chạy SAU khi master + 6 stations đều healthy.
# Substitute __STATION<N>_HOST__ template trong 20_fdw_setup.sql bằng env var
# STATION<N>_HOST (mặc định: station<N> = docker service alias khi chạy chung
# docker compose; cho ZeroTier thực tế, set STATION<N>_HOST=10.147.17.N trong .env).
#
# Cách chạy:
# - Local dev (all trên 1 máy, docker compose): make setup-fdw
# - ZeroTier thực tế: đặt STATION1_HOST=10.147.17.11 ... STATION6_HOST=10.147.17.16
#   trong .env.master, rồi: make setup-fdw
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_FILE="$PROJECT_DIR/db/master/20_fdw_setup.sql"

# Auto-load .env.master nếu có (chứa STATION<N>_HOST + POSTGRES_*)
ENV_FILE="$PROJECT_DIR/.env.master"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ENV_FILE"
  set +a
  echo "=== Loaded $ENV_FILE ==="
else
  echo "=== WARNING: .env.master not found - dùng giá trị default từ shell env ==="
fi

CONTAINER="${MASTER_CONTAINER:-football-master}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-vleague_master}"

# Lấy host của từng station từ env (default = docker service alias khi chạy chung 1 máy)
S1="${STATION1_HOST:-station1}"
S2="${STATION2_HOST:-station2}"
S3="${STATION3_HOST:-station3}"
S4="${STATION4_HOST:-station4}"
S5="${STATION5_HOST:-station5}"
S6="${STATION6_HOST:-station6}"

echo "=== setup-fdw.sh: master container=$CONTAINER ==="
echo "  Station1 host: $S1"
echo "  Station2 host: $S2"
echo "  Station3 host: $S3"
echo "  Station4 host: $S4"
echo "  Station5 host: $S5"
echo "  Station6 host: $S6"

# Substitute template
TMP_SQL="/tmp/fdw_setup_$(date +%s).sql"
sed \
  -e "s|__STATION1_HOST__|$S1|g" \
  -e "s|__STATION2_HOST__|$S2|g" \
  -e "s|__STATION3_HOST__|$S3|g" \
  -e "s|__STATION4_HOST__|$S4|g" \
  -e "s|__STATION5_HOST__|$S5|g" \
  -e "s|__STATION6_HOST__|$S6|g" \
  "$TEMPLATE_FILE" > "$TMP_SQL"

echo "=== Generated SQL (first 20 lines): ==="
head -20 "$TMP_SQL"

echo "=== Chạy fdw setup trong container $CONTAINER ==="
docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < "$TMP_SQL"

rm -f "$TMP_SQL"
echo "=== setup-fdw.sh xong ==="
echo "Test view toàn cục:"
docker exec -e ON_ERROR_STOP=1 "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
  SELECT COUNT(*) AS tong_tran FROM vw_global_tran_dau;
  SELECT COUNT(*) AS tong_su_kien FROM vw_global_su_kien_tran_dau;
"
