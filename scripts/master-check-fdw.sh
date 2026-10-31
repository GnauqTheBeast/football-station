#!/bin/bash
# scripts/master-check-fdw.sh - Chạy TRÊN MASTER (máy admin).
# Kiểm tra FDW đang hoạt động + xem test rows do các station insert (5-6 máy riêng).
#
# Cách chạy:
#   make check-fdw
set -e

CONTAINER="${MASTER_CONTAINER:-football-master}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-vleague_master}"

echo "=== master-check-fdw.sh ==="
echo "Container: $CONTAINER  DB: $DB_NAME"
echo ""

psql_exec() {
  docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "$1"
}

# ----------------------------------------------------------------------------
# 1. Phân mảnh: rows trên từng station DB
# ----------------------------------------------------------------------------
echo "--- 1. Phân mảnh: rows trên từng station DB (test rows mới nổi bật) ---"
psql_exec "
SELECT 'Station1 (HNFC)'    AS tram,
       COUNT(*) AS tran_cho_phep,
       COUNT(*) FILTER (WHERE MaTran LIKE 'TEST_1_%' OR MaTran LIKE 'T1%') AS test_rows
  FROM site1_hnfc.tran_dau_chuyen_mon
UNION ALL SELECT 'Station2 (CAHN)',
       COUNT(*),
       COUNT(*) FILTER (WHERE MaTran LIKE 'TEST_2_%' OR MaTran LIKE 'T2%')
  FROM site2_cahn.tran_dau_chuyen_mon
UNION ALL SELECT 'Station3 (Viettel)',
       COUNT(*),
       COUNT(*) FILTER (WHERE MaTran LIKE 'TEST_3_%' OR MaTran LIKE 'T3%')
  FROM site3_viettel.tran_dau_chuyen_mon
UNION ALL SELECT 'Station4 (HPFC)',
       COUNT(*),
       COUNT(*) FILTER (WHERE MaTran LIKE 'TEST_4_%' OR MaTran LIKE 'T4%')
  FROM site4_hpfc.tran_dau_chuyen_mon
UNION ALL SELECT 'Station5 (NDFC)',
       COUNT(*),
       COUNT(*) FILTER (WHERE MaTran LIKE 'TEST_5_%' OR MaTran LIKE 'T5%')
  FROM site5_ndfc.tran_dau_chuyen_mon
UNION ALL SELECT 'Station6 (HAGL)',
       COUNT(*),
       COUNT(*) FILTER (WHERE MaTran LIKE 'TEST_6_%' OR MaTran LIKE 'T6%')
  FROM site6_hagl.tran_dau_chuyen_mon
ORDER BY 1;"

# ----------------------------------------------------------------------------
# 2. Tổng union toàn cục
# ----------------------------------------------------------------------------
echo ""
echo "--- 2. Tổng trên master (30 tran goc + N test rows do 5-6 station insert) ---"
psql_exec "
SELECT
  (SELECT COUNT(*) FROM vw_global_tran_dau)                                       AS tong_tran,
  (SELECT COUNT(*) FROM vw_global_tran_dau
     WHERE MaTran LIKE 'TEST_%' OR substr(MaTran,1,2) IN ('T1','T2','T3','T4','T5','T6')) AS test_tran,
  (SELECT COUNT(*) FROM vw_global_su_kien_tran_dau)                                AS tong_su_kien,
  (SELECT COUNT(*) FROM vw_global_su_kien_tran_dau
     WHERE MaTran LIKE 'TEST_%' OR substr(MaTran,1,2) IN ('T1','T2','T3','T4','T5','T6')) AS test_su_kien;"

# ----------------------------------------------------------------------------
# 3. Bảng tổng hợp test rows theo từng station
# ----------------------------------------------------------------------------
echo ""
echo "--- 3. Test rows đã arrive master qua FDW (gộp theo station) ---"
psql_exec "
SELECT
  CASE
    WHEN MaTran LIKE 'TEST_1_%' OR MaTran LIKE 'T1%' THEN 'Station1 (HNFC)'
    WHEN MaTran LIKE 'TEST_2_%' OR MaTran LIKE 'T2%' THEN 'Station2 (CAHN)'
    WHEN MaTran LIKE 'TEST_3_%' OR MaTran LIKE 'T3%' THEN 'Station3 (Viettel)'
    WHEN MaTran LIKE 'TEST_4_%' OR MaTran LIKE 'T4%' THEN 'Station4 (HPFC)'
    WHEN MaTran LIKE 'TEST_5_%' OR MaTran LIKE 'T5%' THEN 'Station5 (NDFC)'
    WHEN MaTran LIKE 'TEST_6_%' OR MaTran LIKE 'T6%' THEN 'Station6 (HAGL)'
  END AS trang,
  COUNT(*)                                AS so_tran_test,
  STRING_AGG(MaTran, ', ' ORDER BY MaTran) AS danh_sach_ma_tran
FROM vw_global_tran_dau
WHERE MaTran LIKE 'TEST_%' OR substr(MaTran,1,2) IN ('T1','T2','T3','T4','T5','T6')
GROUP BY 1
ORDER BY 1;"

echo ""
echo "--- 4. Chi tiết test row (FDW view) ---"
psql_exec "
  SELECT MaTran, MaDoiNha, MaDoiKhach,
         (BanThangNha || '-' || BanThangKhach) AS ti_so,
         TrangThai, GiaVe, SoKhach
  FROM vw_global_tran_dau
  WHERE MaTran LIKE 'TEST_%' OR substr(MaTran,1,2) IN ('T1','T2','T3','T4','T5','T6')
  ORDER BY MaTran;"

echo ""
echo "--- 5. Sự kiện test (CT991..CT996 - cầu thủ-test riêng mỗi station) ---"
psql_exec "
  SELECT sk.MaTran,
         sk.MaCauThu,
         CASE sk.MaCauThu
           WHEN 'CT991' THEN 'Station1 HNFC test-player'
           WHEN 'CT992' THEN 'Station2 CAHN test-player'
           WHEN 'CT993' THEN 'Station3 Viettel test-player'
           WHEN 'CT994' THEN 'Station4 HPFC test-player'
           WHEN 'CT995' THEN 'Station5 NDFC test-player'
           WHEN 'CT996' THEN 'Station6 HAGL test-player'
           ELSE sk.MaCauThu
         END AS station,
         sk.LoaiSuKien, sk.PhutGhiNhan
  FROM vw_global_su_kien_tran_dau sk
  WHERE sk.MaCauThu IN ('CT991','CT992','CT993','CT994','CT995','CT996')
  ORDER BY sk.MaTran, sk.PhutGhiNhan;"

# ----------------------------------------------------------------------------
# 6. Top scorer overall
# ----------------------------------------------------------------------------
echo ""
echo "--- 6. Top scorer overall (CT991..CT996 có HoTen=NULL - test players) ---"
psql_exec "
  SELECT MaCauThu, HoTen, SoBanThang
  FROM fn_top10_vua_pha_luoi()
  ORDER BY SoBanThang DESC, MaCauThu;"

# ----------------------------------------------------------------------------
# 7. BXH mới
# ----------------------------------------------------------------------------
echo ""
echo "--- 7. BXH sau test insert (test rows cộng điểm cho MaDoiNha của mỗi station) ---"
psql_exec "
  SELECT ViTri, MaDoi, SoTranDaDau, SoTranThang, SoTranHoa, SoTranThua, DiemSo
  FROM vw_bang_xep_hang
  ORDER BY ViTri;"

# ----------------------------------------------------------------------------
# 8. Tổng kết
# ----------------------------------------------------------------------------
echo ""
echo "=== TỔNG KẾT ==="
TEST_STATIONS=$(docker exec "$CONTAINER" psql -t -U "$DB_USER" -d "$DB_NAME" -c "
  SELECT COUNT(DISTINCT substr(MaTran,1,2))
  FROM vw_global_tran_dau
  WHERE MaTran LIKE 'TEST_%' OR substr(MaTran,1,2) IN ('T1','T2','T3','T4','T5','T6');")
echo "  Số station đã insert test row: $TEST_STATIONS"
echo ""
echo "Để clear test rows, báo mỗi station chay:"
echo "  ./scripts/station-test-cleanup.sh"
echo "Sau đó master chạy lại:  make check-fdw  -> count sẽ giảm về 30."
