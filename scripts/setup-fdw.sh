#!/bin/bash
# scripts/setup-fdw.sh - Chạy SAU khi master + (một số) station healthy.
#
# Đặc tính:
#   - Tolerant: nếu 1 station unreachable, IMPORT bỏ qua nhưng vẫn tiếp tục
#     với các station khác. Cuối cùng CREATE VIEW chỉ gộp những station
#     đã IMPORT OK.
#   - Idempotent: DROP + CREATE lại mỗi lần chạy (an toàn chạy nhiều lần).
#
# Luồng:
#   1. Auto-load .env.master (load STATION<N>_HOST + POSTGRES_PASSWORD)
#   2. DROP schemas/servers/user mappings cũ
#   3. CREATE SERVER + USER MAPPING + SCHEMA (6 cái, luôn OK)
#   4. Loop 6 station: IMPORT FOREIGN SCHEMA. Capture từng result.
#   5. Build CREATE VIEW động (UNION chỉ các schema có foreign tables)
#
# Cách chạy:
#   make setup-fdw
#   ./scripts/setup-fdw.sh
#   ./scripts/setup-fdw.sh -v   # verbose
set -u

VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Auto-load .env.master
ENV_FILE="$PROJECT_DIR/.env.master"
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
  echo "=== Loaded $ENV_FILE ==="
fi

CONTAINER="${MASTER_CONTAINER:-football-master}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-vleague_master}"
DB_PASS="${POSTGRES_PASSWORD:-123456}"
DB_PORT="${STATION_PORT:-5432}"

# Mapping STATION_ID -> metadata
get_index()  { echo "$1"; }
get_srv()    { case "$1" in 1) echo srv_tuan_hnfc;; 2) echo srv_thong_cahn;; 3) echo srv_dung_viettel;; 4) echo srv_quanganh_hpfc;; 5) echo srv_bich_ndfc;; 6) echo srv_minhdung_hagl;; esac; }
get_schema() { case "$1" in 1) echo site1_hnfc;; 2) echo site2_cahn;; 3) echo site3_viettel;; 4) echo site4_hpfc;; 5) echo site5_ndfc;; 6) echo site6_hagl;; esac; }
get_db()     { case "$1" in 1) echo vleague_hnfc;; 2) echo vleague_cahn;; 3) echo vleague_viettel;; 4) echo vleague_haiphong;; 5) echo vleague_namdinh;; 6) echo vleague_hagl;; esac; }
get_name()   { case "$1" in 1) echo "Tuấn";; 2) echo "Thông";; 3) echo "Mạnh Dũng";; 4) echo "Quang Anh";; 5) echo "Ngọc Bích";; 6) echo "Minh Dũng";; esac; }

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: Master container '$CONTAINER' chưa chạy. Chạy 'make up' trước."
  exit 2
fi

echo "=== setup-fdw.sh: master container=$CONTAINER  db=$DB_NAME ==="
for sid in 1 2 3 4 5 6; do
  host_var="STATION${sid}_HOST"
  port_var="STATION${sid}_PORT"
  host="${!host_var:-station${sid}}"
  port="${!port_var:-5432}"
  echo "  Station $sid ($(get_name "$sid")): host=$host  port=$port  db=$(get_db "$sid")"
done
echo ""

# ============================================================================
# Bước 1-3: DROP + CREATE SERVER + USER MAPPING + SCHEMA (luôn thành công)
# ============================================================================
echo "=== Bước 1-3: DROP + CREATE SERVER + USER MAPPING + SCHEMA ==="

# Build SQL phần đầu - dùng template có sẵn
TEMPLATE_FILE="$PROJECT_DIR/db/master/20_fdw_setup.sql"

# Generate file tạm + substitute host + port
TMP_SQL_FULL="/tmp/fdw_setup_full_$(date +%s).sql"
S1="${STATION1_HOST:-station1}"; P1="${STATION1_PORT:-5432}"
S2="${STATION2_HOST:-station2}"; P2="${STATION2_PORT:-5432}"
S3="${STATION3_HOST:-station3}"; P3="${STATION3_PORT:-5432}"
S4="${STATION4_HOST:-station4}"; P4="${STATION4_PORT:-5432}"
S5="${STATION5_HOST:-station5}"; P5="${STATION5_PORT:-5432}"
S6="${STATION6_HOST:-station6}"; P6="${STATION6_PORT:-5432}"

sed \
  -e "s|__STATION1_HOST__|$S1|g" -e "s|__STATION1_PORT__|$P1|g" \
  -e "s|__STATION2_HOST__|$S2|g" -e "s|__STATION2_PORT__|$P2|g" \
  -e "s|__STATION3_HOST__|$S3|g" -e "s|__STATION3_PORT__|$P3|g" \
  -e "s|__STATION4_HOST__|$S4|g" -e "s|__STATION4_PORT__|$P4|g" \
  -e "s|__STATION5_HOST__|$S5|g" -e "s|__STATION5_PORT__|$P5|g" \
  -e "s|__STATION6_HOST__|$S6|g" -e "s|__STATION6_PORT__|$P6|g" \
  "$TEMPLATE_FILE" > "$TMP_SQL_FULL"

# Tách phần DROP + CREATE SERVER + USER MAPPING + SCHEMA (line 1-46) ra chạy trước
TMP_SQL_INIT="/tmp/fdw_setup_init_$(date +%s).sql"
sed -n '1,46p' "$TMP_SQL_FULL" > "$TMP_SQL_INIT"

docker exec -i -e PGPASSWORD="$DB_PASS" "$CONTAINER" \
  psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < "$TMP_SQL_INIT" 2>&1 | grep -E "DROP|CREATE" | head -25
rm -f "$TMP_SQL_INIT"

echo ""

# ============================================================================
# Bước 4: IMPORT FOREIGN SCHEMA từng station (tolerant)
# ============================================================================
echo "=== Bước 4: IMPORT FOREIGN SCHEMA (mỗi station riêng - tolerant) ==="
IMPORTED_SCHEMAS=""  # danh sách schema đã IMPORT thành công, cách nhau bởi space
for sid in 1 2 3 4 5 6; do
  srv="$(get_srv "$sid")"
  schema="$(get_schema "$sid")"
  name="$(get_name "$sid")"
  host_var="STATION${sid}_HOST"
  host="${!host_var:-station${sid}}"

  # Skip nếu host = docker alias = nghĩa là chưa set IP
  if [[ "$host" == "station${sid}" ]]; then
    echo "  Station $sid ($name): SKIP  (host=default 'station${sid}' chưa set IP trong .env.master)"
    continue
  fi

  echo -n "  Station $sid ($name) [$host]: "
  OUT=$(docker exec -e PGPASSWORD="$DB_PASS" "$CONTAINER" \
    psql -t -A -U "$DB_USER" -d "$DB_NAME" -c "
      IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau)
      FROM SERVER $srv INTO $schema;
    " 2>&1)
  if echo "$OUT" | grep -qi "ERROR"; then
    echo "FAIL - $(echo "$OUT" | grep -i error | head -1 | sed 's/ERROR: *//;s/ *$//')"
    [ $VERBOSE -eq 1 ] && echo "    $OUT" | head -5
  else
    echo "OK"
    IMPORTED_SCHEMAS="$IMPORTED_SCHEMAS $schema"
  fi
done
echo ""
echo "  Schemas imported: [$IMPORTED_SCHEMAS ]"
echo ""

# ============================================================================
# Bước 5: CREATE VIEW động (chỉ gộp schemas đã import)
# ============================================================================
if [ -z "$IMPORTED_SCHEMAS" ]; then
  echo "WARNING: Không station nào IMPORT OK - bỏ qua CREATE VIEW. Chạy lại sau khi set IP cho station."
  exit 1
fi

echo "=== Bước 5: CREATE VIEW vw_global_tran_dau + vw_global_su_kien_tran_dau ==="

# Build UNION ALL cho tran_dau_chuyen_mon + su_kien_tran_dau
UNION_TRAN=""
UNION_SUKIEN=""
for schema in $IMPORTED_SCHEMAS; do
  UNION_TRAN="${UNION_TRAN}SELECT * FROM ${schema}.tran_dau_chuyen_mon UNION ALL "
  UNION_SUKIEN="${UNION_SUKIEN}SELECT * FROM ${schema}.su_kien_tran_dau UNION ALL "
done
# Strip trailing "UNION ALL "
UNION_TRAN="${UNION_TRAN%UNION ALL }"
UNION_SUKIEN="${UNION_SUKIEN%UNION ALL }"

# Tạo view vw_global_tran_dau + vw_global_su_kien_tran_dau
docker exec -e PGPASSWORD="$DB_PASS" "$CONTAINER" \
  psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "
CREATE OR REPLACE VIEW vw_global_tran_dau AS
SELECT
    cm.MaTran, cm.MaVong, cm.MaDoiNha, cm.MaDoiKhach, cm.MaSan, cm.NgayGio,
    dt.GiaVe, dt.SoKhach,
    cm.BanThangNha, cm.BanThangKhach, cm.TheVangNha, cm.TheVangKhach, cm.TheDoNha, cm.TheDoKhach, cm.TrangThai
FROM (${UNION_TRAN}) cm
LEFT JOIN TRAN_DAU_DOANH_THU dt ON cm.MaTran = dt.MaTran;

CREATE OR REPLACE VIEW vw_global_su_kien_tran_dau AS
${UNION_SUKIEN};
" 2>&1 | grep -E "CREATE VIEW" | head -5

echo ""

# ============================================================================
# Bước 6: Rebuild BXH view + fn_top10_vua_pha_luoi
# (lấy từ template, không phụ thuộc schema cụ thể - dựa vw_global_tran_dau)
# ============================================================================
echo "=== Bước 6: Recreate vw_bang_xep_hang + fn_top10_vua_pha_luoi ==="
TMP_SQL_VIEWS="/tmp/fdw_views_$(date +%s).sql"
sed -n '93,201p' "$TMP_SQL_FULL" > "$TMP_SQL_VIEWS"
docker exec -i -e PGPASSWORD="$DB_PASS" "$CONTAINER" \
  psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < "$TMP_SQL_VIEWS" 2>&1 \
  | grep -E "CREATE VIEW|CREATE FUNCTION" | head -3
rm -f "$TMP_SQL_VIEWS"

# ============================================================================
# Verify final
# ============================================================================
echo ""
echo "=== setup-fdw.sh xong ==="
echo "Test views toàn cục:"
docker exec -e PGPASSWORD="$DB_PASS" "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
  SELECT
    (SELECT COUNT(*) FROM vw_global_tran_dau)       AS tong_tran,
    (SELECT COUNT(*) FROM vw_global_su_kien_tran_dau) AS tong_su_kien;
"
rm -f "$TMP_SQL_FULL"
