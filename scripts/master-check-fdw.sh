#!/bin/bash
# scripts/master-check-fdw.sh - Chạy TRÊN MASTER (máy admin).
# Kiểm tra FDW đang hoạt động + xem test rows do các station insert.
# Tolerant: station chưa có foreign tables sẽ được SKIP (hiện "(not imported)").
#
# Cách chạy:
#   make check-fdw
set -e

CONTAINER="${MASTER_CONTAINER:-football-master}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-vleague_master}"
DB_PASS="${POSTGRES_PASSWORD:-123456}"

# Auto-load .env.master (cho STATION<N>_HOST info hiển thị)
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env.master"
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

# Mapping
get_srv()    { case "$1" in 1) echo srv_tuan_hnfc;; 2) echo srv_thong_cahn;; 3) echo srv_dung_viettel;; 4) echo srv_quanganh_hpfc;; 5) echo srv_bich_ndfc;; 6) echo srv_minhdung_hagl;; esac; }
get_schema() { case "$1" in 1) echo site1_hnfc;; 2) echo site2_cahn;; 3) echo site3_viettel;; 4) echo site4_hpfc;; 5) echo site5_ndfc;; 6) echo site6_hagl;; esac; }
get_clb()    { case "$1" in 1) echo HNFC;; 2) echo CAHN;; 3) echo VTT;; 4) echo HPFC;; 5) echo NDFC;; 6) echo HAGL;; esac; }
get_name()   { case "$1" in 1) echo "Tuấn";; 2) echo "Thông";; 3) echo "Mạnh Dũng";; 4) echo "Quang Anh";; 5) echo "Ngọc Bích";; 6) echo "Minh Dũng";; esac; }

echo "=== master-check-fdw.sh ==="
echo "Container: $CONTAINER  DB: $DB_NAME"
echo ""

# Lấy danh sách schema đã có foreign tables thành công
HAS_FOREIGN=$(docker exec -e PGPASSWORD="$DB_PASS" "$CONTAINER" \
  psql -t -A -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT DISTINCT table_schema
    FROM information_schema.tables
    WHERE table_schema LIKE 'site%' AND table_type = 'FOREIGN'
    ORDER BY 1;")
IMPORTED_LIST=$(echo "$HAS_FOREIGN" | tr '\n' ' ')

has_schema() {
  echo "$IMPORTED_LIST" | grep -qw "$1"
}

# ----------------------------------------------------------------------------
# 1. Per-station status
# ----------------------------------------------------------------------------
echo "--- 1. Phân mảnh: rows trên từng station DB (test rows mới nổi bật) ---"
echo ""
printf "%-3s %-12s %-22s %-22s %-10s %-10s\n" "ID" "STATION" "HOST (.env.master)" "SCHEMA" "TRAN/SUKIEN" "TEST_ROWS"
printf "%-3s %-12s %-22s %-22s %-10s %-10s\n" "--" "-------" "------------------" "------" "----------" "---------"

TOTAL_TRAN=0
TOTAL_SUKIEN=0
TOTAL_TEST=0
for sid in 1 2 3 4 5 6; do
  clb="$(get_clb "$sid")"
  schema="$(get_schema "$sid")"
  name="$(get_name "$sid")"
  host_var="STATION${sid}_HOST"
  host="${!host_var:-(not set)}"
  if [[ "$host" == "station${sid}" ]]; then host="(not set)"; fi

  if ! has_schema "$schema"; then
    printf "%-3s %-12s %-22s %-22s %-10s %-10s\n" "$sid" "$clb ($name)" "$host" "$schema" "-" "NOT IMPORTED"
    continue
  fi

  # Query rows of this station (test rows: MaTran like 'T<N>%' or 'TEST_<N>_%')
  ROWS=$(docker exec -e PGPASSWORD="$DB_PASS" "$CONTAINER" \
    psql -t -A -U "$DB_USER" -d "$DB_NAME" -c "
      SELECT
        (SELECT COUNT(*) FROM ${schema}.tran_dau_chuyen_mon) || '/' ||
        (SELECT COUNT(*) FROM ${schema}.su_kien_tran_dau),
        (SELECT COUNT(*) FROM ${schema}.tran_dau_chuyen_mon
          WHERE MaTran LIKE 'TEST_${sid}_%' OR MaTran LIKE 'T${sid}%')
      ;")
  tran_sukien=$(echo "$ROWS" | cut -d'|' -f1)
  test_rows=$(echo "$ROWS" | cut -d'|' -f2)
  printf "%-3s %-12s %-22s %-22s %-10s %-10s\n" "$sid" "$clb ($name)" "$host" "$schema" "$tran_sukien" "$test_rows"
  TOTAL_TRAN=$((TOTAL_TRAN + $(echo "$tran_sukien" | cut -d/ -f1)))
  TOTAL_SUKIEN=$((TOTAL_SUKIEN + $(echo "$tran_sukien" | cut -d/ -f2)))
  TOTAL_TEST=$((TOTAL_TEST + test_rows))
done

echo ""
echo "  TỔNG (imported stations): tran=$TOTAL_TRAN  su_kien=$TOTAL_SUKIEN  test_rows=$TOTAL_TEST"
echo ""

# ----------------------------------------------------------------------------
# 2-6. Global views queries (chạy nếu có ít nhất 1 station đã import)
# ----------------------------------------------------------------------------
if [ -z "$IMPORTED_LIST" ]; then
  echo "(Không station nào được IMPORT. Chạy 'make setup-fdw' trước.)"
  exit 1
fi

echo "--- 2. Tổng trên master (vw_global_*) ---"
docker exec -e PGPASSWORD="$DB_PASS" "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT
  (SELECT COUNT(*) FROM vw_global_tran_dau) AS tong_tran,
  (SELECT COUNT(*) FROM vw_global_tran_dau
    WHERE MaTran LIKE 'TEST_%' OR substr(MaTran,1,2) IN ('T1','T2','T3','T4','T5','T6')) AS test_tran,
  (SELECT COUNT(*) FROM vw_global_su_kien_tran_dau) AS tong_su_kien,
  (SELECT COUNT(*) FROM vw_global_su_kien_tran_dau
    WHERE MaTran LIKE 'TEST_%' OR substr(MaTran,1,2) IN ('T1','T2','T3','T4','T5','T6')) AS test_su_kien;"

echo ""
echo "--- 3. Test rows đã arrive master qua FDW (gộp theo station) ---"
docker exec -e PGPASSWORD="$DB_PASS" "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT
  CASE
    WHEN MaTran LIKE 'TEST_1_%' OR MaTran LIKE 'T1%' THEN 'Station1 (HNFC)'
    WHEN MaTran LIKE 'TEST_2_%' OR MaTran LIKE 'T2%' THEN 'Station2 (CAHN)'
    WHEN MaTran LIKE 'TEST_3_%' OR MaTran LIKE 'T3%' THEN 'Station3 (Viettel)'
    WHEN MaTran LIKE 'TEST_4_%' OR MaTran LIKE 'T4%' THEN 'Station4 (HPFC)'
    WHEN MaTran LIKE 'TEST_5_%' OR MaTran LIKE 'T5%' THEN 'Station5 (NDFC)'
    WHEN MaTran LIKE 'TEST_6_%' OR MaTran LIKE 'T6%' THEN 'Station6 (HAGL)'
  END AS trang,
  COUNT(*) AS so_tran_test,
  STRING_AGG(MaTran, ', ' ORDER BY MaTran) AS danh_sach_ma_tran
FROM vw_global_tran_dau
WHERE MaTran LIKE 'TEST_%' OR substr(MaTran,1,2) IN ('T1','T2','T3','T4','T5','T6')
GROUP BY 1 ORDER BY 1;"

echo ""
echo "--- 4. Chi tiết test row (FDW view) ---"
docker exec -e PGPASSWORD="$DB_PASS" "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
  SELECT MaTran, MaDoiNha, MaDoiKhach,
         (BanThangNha || '-' || BanThangKhach) AS ti_so,
         TrangThai, GiaVe, SoKhach
  FROM vw_global_tran_dau
  WHERE MaTran LIKE 'TEST_%' OR substr(MaTran,1,2) IN ('T1','T2','T3','T4','T5','T6')
  ORDER BY MaTran;"

echo ""
echo "--- 5. Sự kiện test (CT991..CT996 - cầu thủ-test riêng mỗi station) ---"
docker exec -e PGPASSWORD="$DB_PASS" "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
  SELECT sk.MaTran, sk.MaCauThu,
    CASE sk.MaCauThu
      WHEN 'CT991' THEN 'St1 HNFC'
      WHEN 'CT992' THEN 'St2 CAHN'
      WHEN 'CT993' THEN 'St3 Viettel'
      WHEN 'CT994' THEN 'St4 HPFC'
      WHEN 'CT995' THEN 'St5 NDFC'
      WHEN 'CT996' THEN 'St6 HAGL'
      ELSE sk.MaCauThu
    END AS station,
    sk.LoaiSuKien, sk.PhutGhiNhan
  FROM vw_global_su_kien_tran_dau sk
  WHERE sk.MaCauThu IN ('CT991','CT992','CT993','CT994','CT995','CT996')
  ORDER BY sk.MaTran, sk.PhutGhiNhan;"

echo ""
echo "--- 6. BXH (từ vw_bang_xep_hang) ---"
docker exec -e PGPASSWORD="$DB_PASS" "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
  SELECT ViTri, MaDoi, SoTranDaDau, SoTranThang, SoTranHoa, SoTranThua, DiemSo
  FROM vw_bang_xep_hang ORDER BY ViTri;"

echo ""
echo "--- 7. Top scorer (fn_top10_vua_pha_luoi) ---"
docker exec -e PGPASSWORD="$DB_PASS" "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
  SELECT MaCauThu, HoTen, SoBanThang
  FROM fn_top10_vua_pha_luoi()
  ORDER BY SoBanThang DESC, MaCauThu;"

echo ""
echo "=== TỔNG KẾT ==="
echo "  Station đã IMPORT: $(echo "$IMPORTED_LIST" | tr ' ' '\n' | grep -c site)"
echo "  Tổng station dự kiến: 6 (xem $(dirname "$ENV_FILE")/.env.master)"
echo ""
echo "Để clear test rows, báo mỗi station chay:"
echo "  ./scripts/station-test-cleanup.sh"
echo "Sau đó master chạy lại: make check-fdw"
