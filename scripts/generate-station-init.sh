#!/bin/bash
# ============================================================================
# scripts/generate-station-init.sh
# Sinh ra db/station_N/00_init.sql HOÀN CHỈNH cho 1 trạm (11 bảng + data + 6
# trigger + 5 SP, idempotent). Chạy:
#   bash scripts/generate-station-init.sh <station_id 1-6>
#
# Nguồn dữ liệu:
#   - db/master/40_full_schema.sql : schema + data 7 bảng danh mục (dùng chung)
#   - master DB (vleague_master)    : data 4 bảng phân mảnh của 5 trận sân nhà
#   - db/station_common/*.sql       : template fragment schema / triggers / sps
#
# Lưu ý: script này là công cụ build. File 00_init.sql sinh ra là self-contained
# (chạy độc lập trên trạm, không cần master).
# ============================================================================
set -e

REPO="$(cd "$(dirname "$0")/.." && pwd)"
MASTER_SQL="$REPO/db/master/40_full_schema.sql"
COMMON="$REPO/db/station_common"
MASTER_CONTAINER="football-master"
MASTER_DB="vleague_master"

# ----------------------------------------------------------------------------
# Metadata 6 trạm (khớp db/station_N/00_init.sql gốc + docker-compose.station.yml)
# Dùng case (tương thích bash 3.2 trên macOS)
# ----------------------------------------------------------------------------
meta() {
  case "$1" in
    1) CLUB=HNFC;  SAN=SAN_HD; DBNAME=vleague_hnfc;     CLUBNAME="HÀ NỘI FC";          SANNAME="SÂN HÀNG ĐẪY";          PERSON="HOÀNG ANH TUẤN (Mã HV: B26CHHT102)";        IP=10.147.17.11; MATCHES="'TR01','TR07','TR13','TR19','TR25'"; MDISPLAY="TR01, TR07, TR13, TR19, TR25" ;;
    2) CLUB=CAHN;  SAN=SAN_HD; DBNAME=vleague_cahn;     CLUBNAME="CÔNG AN HÀ NỘI";     SANNAME="SÂN HÀNG ĐẪY";          PERSON="ĐÀO DUY THÔNG (Mã HV: B26CHHT095)";           IP=10.147.17.12; MATCHES="'TR02','TR11','TR20','TR22','TR29'"; MDISPLAY="TR02, TR11, TR20, TR22, TR29" ;;
    3) CLUB=VTT;   SAN=SAN_MD; DBNAME=vleague_viettel;  CLUBNAME="THỂ CÔNG VIETTEL";   SANNAME="SÂN QUỐC GIA MỸ ĐÌNH";  PERSON="NGUYỄN HOÀNG MẠNH DŨNG (Mã HV: B26CHHT026)"; IP=10.147.17.13; MATCHES="'TR03','TR08','TR21','TR26','TR28'"; MDISPLAY="TR03, TR08, TR21, TR26, TR28" ;;
    4) CLUB=HPFC;  SAN=SAN_LT; DBNAME=vleague_haiphong; CLUBNAME="HẢI PHÒNG FC";       SANNAME="SÂN LẠCH TRAY";         PERSON="HỒ QUANG ANH (Mã HV: B26CHHT005)";           IP=10.147.17.14; MATCHES="'TR05','TR12','TR15','TR16','TR23'"; MDISPLAY="TR05, TR12, TR15, TR16, TR23" ;;
    5) CLUB=NDFC;  SAN=SAN_TT; DBNAME=vleague_namdinh;  CLUBNAME="THÉP XANH NAM ĐỊNH"; SANNAME="SÂN THIÊN TRƯỜNG";      PERSON="NGUYỄN THỊ NGỌC BÍCH (Mã HV: B26CHHT010)";   IP=10.147.17.15; MATCHES="'TR04','TR09','TR14','TR18','TR27'"; MDISPLAY="TR04, TR09, TR14, TR18, TR27" ;;
    6) CLUB=HAGL;  SAN=SAN_PK; DBNAME=vleague_hagl;     CLUBNAME="HOÀNG ANH GIA LAI";  SANNAME="SÂN PLEIKU";            PERSON="HOÀNG MINH DŨNG (Mã HV: B26CHHT027)";       IP=10.147.17.16; MATCHES="'TR06','TR10','TR17','TR24','TR30'"; MDISPLAY="TR06, TR10, TR17, TR24, TR30" ;;
    *) echo "Invalid station_id: $1 (1-6)" >&2; exit 1 ;;
  esac
}

STATION_ID="$1"
if [ -z "$STATION_ID" ]; then
  echo "Usage: $0 <station_id 1-6>" >&2
  exit 1
fi
meta "$STATION_ID"
OUT="$REPO/db/station_$STATION_ID/00_init.sql"
mkdir -p "$(dirname "$OUT")"

# psql helper: chạy query trên master DB, trả về raw text
master_psql() {
  docker exec -e PGPASSWORD=123456 "$MASTER_CONTAINER" psql -U postgres -d "$MASTER_DB" -t -A -c "$1"
}

# ----------------------------------------------------------------------------
# 1. HEADER
# ----------------------------------------------------------------------------
cat > "$OUT" <<EOF
-- ============================================================================
-- TRẠM $STATION_ID: CHI NHÁNH $CLUBNAME ($SANNAME)
-- Người phụ trách: $PERSON
-- Địa chỉ IP ZeroTier: $IP
-- Database: $DBNAME | Port: 5432
-- Nhiệm vụ: Quản lý 5 trận sân nhà của CLB $CLUBNAME ($MDISPLAY)
--
-- KẾT CẤU (11 bảng theo báo cáo):
--   7 bảng danh mục (replica read-only, đủ data):
--     SAN_VAN_DONG, DOI_BONG, MAU_AO_DOI_BONG, CAU_THU, HOP_DONG_CAU_THU,
--     TRONG_TAI, VONG_DAU
--   4 bảng phân mảnh cục bộ (mảnh ngang theo CLB $CLUB):
--     TRAN_DAU_CHUYEN_MON, PHAN_CONG_TRONG_TAI, DANG_KY_THI_DAU, SU_KIEN_TRAN_DAU
--   6 trigger + 5 stored procedure (thích ứng TRAN_DAU -> TRAN_DAU_CHUYEN_MON)
--
-- File này IDMPOTENT (DROP trước khi CREATE) - chạy lại an toàn.
-- Rollback: db/station_$STATION_ID/99_revert.sql
-- ============================================================================

EOF

# ----------------------------------------------------------------------------
# 2. DROP (thứ tự ngược khóa ngoại)
# ----------------------------------------------------------------------------
cat >> "$OUT" <<'EOF'
DROP TABLE IF EXISTS SU_KIEN_TRAN_DAU CASCADE;
DROP TABLE IF EXISTS DANG_KY_THI_DAU CASCADE;
DROP TABLE IF EXISTS PHAN_CONG_TRONG_TAI CASCADE;
DROP TABLE IF EXISTS TRAN_DAU_CHUYEN_MON CASCADE;
DROP TABLE IF EXISTS VONG_DAU CASCADE;
DROP TABLE IF EXISTS TRONG_TAI CASCADE;
DROP TABLE IF EXISTS HOP_DONG_CAU_THU CASCADE;
DROP TABLE IF EXISTS CAU_THU CASCADE;
DROP TABLE IF EXISTS MAU_AO_DOI_BONG CASCADE;
DROP TABLE IF EXISTS DOI_BONG CASCADE;
DROP TABLE IF EXISTS SAN_VAN_DONG CASCADE;

-- ----------------------------------------------------------------------------
-- PHẦN 1: DDL 7 BẢNG DANH MỤC (replica read-only - verbatim từ BTL tập trung)
-- ----------------------------------------------------------------------------
EOF

# ----------------------------------------------------------------------------
# 3. CATALOG SCHEMA (7 bảng) - trích từ master 40_full_schema.sql dòng 34-106
# ----------------------------------------------------------------------------
sed -n '34,106p' "$MASTER_SQL" >> "$OUT"

# ----------------------------------------------------------------------------
# 4. FRAGMENT SCHEMA (4 bảng) - từ template, thay placeholder
# ----------------------------------------------------------------------------
echo "" >> "$OUT"
sed -e "s/__MA_DOI_NHA__/$CLUB/g" -e "s/__MA_SAN__/$SAN/g" "$COMMON/fragment_schema.sql" >> "$OUT"

# ----------------------------------------------------------------------------
# 5. TRIGGERS (6) + SPs (5)
# ----------------------------------------------------------------------------
echo "" >> "$OUT"
cat "$COMMON/triggers.sql" >> "$OUT"
echo "" >> "$OUT"
cat "$COMMON/sps.sql" >> "$OUT"

# ----------------------------------------------------------------------------
# 6. CATALOG DATA (7 bảng, đủ data) - trích từ master 40_full_schema.sql
#    (dòng 872-1200: SAN_VAN_DONG -> VONG_DAU, không gồm 30 trận tập trung)
# ----------------------------------------------------------------------------
cat >> "$OUT" <<'EOF'

-- ============================================================================
-- PHẦN 5: DỮ LIỆU 7 BẢNG DANH MỤC (đủ data - dùng chung cho mọi trạm)
-- Thứ tự nạp đúng BTL: sân -> đội -> màu áo -> trọng tài -> cầu thủ + hợp đồng -> vòng
-- ============================================================================
EOF
sed -n '872,1200p' "$MASTER_SQL" >> "$OUT"

# ----------------------------------------------------------------------------
# 7. FRAGMENT DATA (4 bảng, 5 trận sân nhà) - sinh từ master DB
# ----------------------------------------------------------------------------
cat >> "$OUT" <<EOF

-- ============================================================================
-- PHẦN 5b: DỮ LIỆU PHÂN MẢNH CỤC BỘ - 5 trận sân nhà $CLUB ($MDISPLAY)
-- Thứ tự nạp đúng BTL: trận (ChuaDienRa) -> phân công TT -> đăng ký -> sự kiện
-- -> chốt DaKetThuc (kích hoạt trigger đối soát bàn thắng / thẻ)
-- ============================================================================
EOF

# 7a. TRAN_DAU_CHUYEN_MON (bỏ GiaVe/SoKhach, ChuaDienRa)
cat >> "$OUT" <<'EOF'
INSERT INTO TRAN_DAU_CHUYEN_MON (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
EOF
master_psql "SELECT '(' || quote_literal(MaTran) || ', ' || MaVong || ', ' || quote_literal(MaDoiNha) || ', ' || quote_literal(MaDoiKhach) || ', ' || quote_literal(MaSan) || ', ' || quote_literal(to_char(NgayGio,'YYYY-MM-DD HH24:MI:SS')) || ', ' || BanThangNha || ', ' || BanThangKhach || ', ' || TheVangNha || ', ' || TheVangKhach || ', ' || TheDoNha || ', ' || TheDoKhach || ', ' || quote_literal('ChuaDienRa') || ')' FROM TRAN_DAU WHERE MaTran IN ($MATCHES) ORDER BY MaTran;" | sed '$!s/$/,/' >> "$OUT"
echo ";" >> "$OUT"

# 7b. PHAN_CONG_TRONG_TAI
cat >> "$OUT" <<'EOF'

INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
EOF
master_psql "SELECT '(' || quote_literal(MaTran) || ', ' || quote_literal(VaiTro) || ', ' || quote_literal(MaTrongTai) || ')' FROM PHAN_CONG_TRONG_TAI WHERE MaTran IN ($MATCHES) ORDER BY MaTran, CASE VaiTro WHEN 'Chinh' THEN 1 WHEN 'Bien1' THEN 2 WHEN 'Bien2' THEN 3 ELSE 4 END;" | sed '$!s/$/,/' >> "$OUT"
echo ";" >> "$OUT"

# 7c. DANG_KY_THI_DAU
cat >> "$OUT" <<'EOF'

INSERT INTO DANG_KY_THI_DAU (MaTran, MaCauThu, MaDoi, VaiTroThiDau, SoAoDangKy) VALUES
EOF
master_psql "SELECT '(' || quote_literal(MaTran) || ', ' || quote_literal(MaCauThu) || ', ' || quote_literal(MaDoi) || ', ' || quote_literal(VaiTroThiDau) || ', ' || SoAoDangKy || ')' FROM DANG_KY_THI_DAU WHERE MaTran IN ($MATCHES) ORDER BY MaTran, MaDoi, SoAoDangKy;" | sed '$!s/$/,/' >> "$OUT"
echo ";" >> "$OUT"

# 7d. SU_KIEN_TRAN_DAU
cat >> "$OUT" <<'EOF'

INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
EOF
master_psql "SELECT '(' || quote_literal(MaSuKien) || ', ' || quote_literal(MaTran) || ', ' || quote_literal(MaCauThu) || ', ' || quote_literal(LoaiSuKien) || ', ' || PhutGhiNhan || ')' FROM SU_KIEN_TRAN_DAU WHERE MaTran IN ($MATCHES) ORDER BY MaSuKien;" | sed '$!s/$/,/' >> "$OUT"
echo ";" >> "$OUT"

# ----------------------------------------------------------------------------
# 8. FINAL UPDATE DaKetThuc + VERIFICATION
# ----------------------------------------------------------------------------
cat >> "$OUT" <<'EOF'

-- Chốt trạng thái DaKetThuc cho 5 trận (kích hoạt trigger đối soát bàn thắng / thẻ)
UPDATE TRAN_DAU_CHUYEN_MON SET TrangThai = 'DaKetThuc';

-- ============================================================================
-- KIỂM TRA KẾT QUẢ (chạy xong nên thấy: 11 bảng, 6 trigger, 5 SP)
-- ============================================================================
SELECT 'SAN_VAN_DONG' AS bang, COUNT(*) AS so_dong FROM SAN_VAN_DONG
UNION ALL SELECT 'DOI_BONG', COUNT(*) FROM DOI_BONG
UNION ALL SELECT 'MAU_AO_DOI_BONG', COUNT(*) FROM MAU_AO_DOI_BONG
UNION ALL SELECT 'CAU_THU', COUNT(*) FROM CAU_THU
UNION ALL SELECT 'HOP_DONG_CAU_THU', COUNT(*) FROM HOP_DONG_CAU_THU
UNION ALL SELECT 'TRONG_TAI', COUNT(*) FROM TRONG_TAI
UNION ALL SELECT 'VONG_DAU', COUNT(*) FROM VONG_DAU
UNION ALL SELECT 'TRAN_DAU_CHUYEN_MON', COUNT(*) FROM TRAN_DAU_CHUYEN_MON
UNION ALL SELECT 'PHAN_CONG_TRONG_TAI', COUNT(*) FROM PHAN_CONG_TRONG_TAI
UNION ALL SELECT 'DANG_KY_THI_DAU', COUNT(*) FROM DANG_KY_THI_DAU
UNION ALL SELECT 'SU_KIEN_TRAN_DAU', COUNT(*) FROM SU_KIEN_TRAN_DAU
ORDER BY bang;

SELECT COUNT(*) AS so_trigger FROM pg_trigger WHERE NOT tgisinternal;

SELECT proname AS sp_hoac_ham FROM pg_proc
WHERE proname LIKE 'sp\_%' OR proname LIKE 'fn_check\_%' OR proname LIKE 'fn_prevent\_%'
ORDER BY proname;
EOF

echo "=== Generated: $OUT ($(wc -l < "$OUT") lines) ==="