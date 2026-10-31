#!/bin/bash
# scripts/station-test-insert.sh - Chạy TRÊN MÁY TRẠM (bạn bè).
# Test end-to-end postgres_fdw: station insert → master query qua FDW.
#
# An toàn chạy đồng thời 6 máy (1 master + 5 station) - mỗi máy:
#   - 1 STATION_ID riêng (auto-detect hoặc set env)
#   - 1 station DB riêng (vleague_hnfc / vleague_cahn / ...)
#   - 1 MaTran test riêng: T<N><hash-8> = 10 ký tự (fit VARCHAR(10))
#   - 1 cầu thủ-test riêng: CT99X (X = STATION_ID) - để master phân biệt ai
#   - 1 tỉ số riêng (random seeded theo host) - để mỗi máy giá trị khác nhau
#
# Cách chạy:
#   ./scripts/station-test-insert.sh             # auto-detect + commit (default)
#   ./scripts/station-test-insert.sh --rollback  # test dry-run, rollback
#   STATION_ID=3 ./scripts/station-test-insert.sh # override auto-detect
set -e

COMMIT_MODE=true
if [ "$1" = "--rollback" ]; then COMMIT_MODE=false; fi

DB_USER="${POSTGRES_USER:-postgres}"

# ----------------------------------------------------------------------------
# 1. AUTO-DETECT STATION_ID từ container đang chạy trên máy bạn
# ----------------------------------------------------------------------------
if [ -z "$STATION_ID" ]; then
  STATION_IDS=$(docker ps --filter "name=^football-station[0-9]$" --format '{{.Names}}' \
                | sed -E 's/^football-station([0-9])$/\1/' | sort -u)
  COUNT=$(echo "$STATION_IDS" | grep -c '[0-9]')
  if [ "$COUNT" = "0" ]; then
    echo "!!! KHÔNG tìm thấy container station (football-station<N>) đang chạy."
    echo "    Trước tiên chạy setup-station.ps1 hoặc:"
    echo "      docker compose -f docker-compose.station.yml --env-file .env.station -p football-station<N> up -d"
    exit 1
  elif [ "$COUNT" = "1" ]; then
    STATION_ID="$STATION_IDS"
    echo "Auto-detect: 1 station container running -> STATION_ID=$STATION_ID"
  else
    echo "!!! PHÁT HIỆN nhiều station containers đang chạy:"
    docker ps --filter "name=^football-station[0-9]$" --format '  {{.Names}}\t{{.Status}}'
    echo ""
    echo "    Set STATION_ID env để chọn:"
    echo "      STATION_ID=3 ./scripts/station-test-insert.sh"
    exit 1
  fi
fi

# Container name
CONTAINER="${STATION_CONTAINER:-football-station${STATION_ID}}"

# Map: STATION_ID -> mã CLB + sân + DB name + cầu thủ-test riêng
case "$STATION_ID" in
  1) MA_DOI="HNFC"; MA_SAN="SAN_HD"; TEN_CLB="Hà Nội FC";       DB_NAME="vleague_hnfc";     TEST_CAU_THU="CT991";;
  2) MA_DOI="CAHN"; MA_SAN="SAN_HD"; TEN_CLB="Công An Hà Nội"; DB_NAME="vleague_cahn";     TEST_CAU_THU="CT992";;
  3) MA_DOI="VTT";  MA_SAN="SAN_MD"; TEN_CLB="Viettel";        DB_NAME="vleague_viettel";  TEST_CAU_THU="CT993";;
  4) MA_DOI="HPFC"; MA_SAN="SAN_LT"; TEN_CLB="Hải Phòng";      DB_NAME="vleague_haiphong"; TEST_CAU_THU="CT994";;
  5) MA_DOI="NDFC"; MA_SAN="SAN_TT"; TEN_CLB="Nam Định";      DB_NAME="vleague_namdinh";  TEST_CAU_THU="CT995";;
  6) MA_DOI="HAGL"; MA_SAN="SAN_PK"; TEN_CLB="HAGL";           DB_NAME="vleague_hagl";     TEST_CAU_THU="CT996";;
  *) echo "!!! STATION_ID '$STATION_ID' không hợp lệ (1..6)"; exit 1;;
esac

# Override DB name nếu user set POSTGRES_DB
DB_NAME="${POSTGRES_DB:-$DB_NAME}"

# Seed random theo STATION_ID + PID + giây
SEED=$(( (STATION_ID * 17 + $$ + $(date +%S))  % 32768 ))
RANDOM=$SEED
HOME_GOALS=$(( (RANDOM % 4) + 1 ))   # 1..4
AWAY_GOALS=$(( (RANDOM >> 4) % 4 ))  # 0..3
MINUTE=$(( (RANDOM % 75) + 10 ))    # 10..84

TIMESTAMP=$(date +%Y%m%d%H%M%S)
# MaTran VARCHAR(10): T<N><hash-8> = 10 ký tự - UNIQUE + đủ short
MA_HASH=$(echo "${TIMESTAMP}-${HOST_NAME}-${STATION_ID}" | shasum -a 256 2>/dev/null | cut -c1-8)
MA_TRAN="T${STATION_ID}${MA_HASH}"

# Hash máy để admin master nhận biết
HOST_NAME=$(hostname 2>/dev/null || echo "unknown")
HOST_HASH=$(echo "${HOST_NAME}-${TIMESTAMP}" | shasum -a 256 2>/dev/null | cut -c1-8 || echo "n/a")

echo "=== station-test-insert.sh ==="
echo "  Station ID    : $STATION_ID ($TEN_CLB - mã CLB $MA_DOI)"
echo "  Container     : $CONTAINER"
echo "  Database      : $DB_NAME"
echo "  Host máy      : $HOST_NAME (hash $HOST_HASH)"
echo "  MaTran test   : $MA_TRAN"
echo "  Cầu thủ test  : $TEST_CAU_THU (riêng cho station $STATION_ID)"
echo "  Tỉ số         : $MA_DOI $HOME_GOALS-$AWAY_GOALS"
echo "  Mode          : $([ "$COMMIT_MODE" = true ] && echo 'COMMIT (lưu)' || echo 'ROLLBACK (test only)')"
echo ""

# Verify container healthy
if ! docker ps --filter "name=^${CONTAINER}\$" --filter "health=healthy" --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "!!! Container $CONTAINER chưa healthy."
  docker ps -a --filter "name=^${CONTAINER}\$"
  exit 1
fi

# ----------------------------------------------------------------------------
# Step 1: cleanup test cũ (chỉ test rows của STATION NÀY)
# ----------------------------------------------------------------------------
echo "--- Step 1: Xóa test rows cũ của station $STATION_ID (MaTran LIKE 'TEST_${STATION_ID}_%') ---"
docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" <<SQL
BEGIN;
DELETE FROM su_kien_tran_dau     WHERE MaTran LIKE 'TEST_${STATION_ID}_%';
DELETE FROM tran_dau_chuyen_mon  WHERE MaTran LIKE 'TEST_${STATION_ID}_%';
COMMIT;
SQL

# ----------------------------------------------------------------------------
# Step 2: insert test row mới
# ----------------------------------------------------------------------------
echo ""
echo "--- Step 2: Insert trận + $HOME_GOALS bàn thắng cho cầu thủ-test $TEST_CAU_THU ---"

# Tạo các dòng INSERT su_kien_tran_dau cho mỗi bàn thắng
# MaSuKien VARCHAR(15): S<N><i><hash-7> = 10 ký tự
EVENT_INSERTS=""
for i in $(seq 1 "$HOME_GOALS"); do
  minute=$(( (i * 17 + SEED) % 88 + 2 ))
  EVENT_INSERTS="${EVENT_INSERTS}INSERT INTO su_kien_tran_dau (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES ('S${STATION_ID}${i}${MA_HASH:0:7}', '${MA_TRAN}', '${TEST_CAU_THU}', 'BanThang', ${minute});"
done

docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" <<SQL
BEGIN;
INSERT INTO tran_dau_chuyen_mon (
  MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio,
  BanThangNha, BanThangKhach, TheVangNha, TheVangKhach,
  TheDoNha, TheDoKhach, TrangThai
) VALUES (
  '${MA_TRAN}',
  10,
  '${MA_DOI}',
  'P${STATION_ID}${HOST_HASH:0:7}',
  '${MA_SAN}',
  '${TIMESTAMP:0:4}-${TIMESTAMP:4:2}-${TIMESTAMP:6:2} ${TIMESTAMP:8:2}:${TIMESTAMP:10:2}:00',
  ${HOME_GOALS}, ${AWAY_GOALS},
  0, 0, 0, 0,
  'DaKetThuc'
);
${EVENT_INSERTS}
SELECT 'Inserted: ' || MaTran || ' .' || BanThangNha || '-' || BanThangKhach AS ok
FROM tran_dau_chuyen_mon WHERE MaTran = '${MA_TRAN}';
$(if [ "$COMMIT_MODE" = false ]; then echo "ROLLBACK;"; else echo "COMMIT;"; fi)
SQL

echo ""
if [ "$COMMIT_MODE" = true ]; then
  echo "=== ▼ KẾT QUẢ (data đã commit vào station $STATION_ID) ▼ ==="
  echo ""
  echo "  Vai trò  : Station $STATION_ID = $TEN_CLB (mã CLB $MA_DOI)"
  echo "  Trận test: $MA_TRAN  •  $MA_DOI $HOME_GOALS-$AWAY_GOALS MaDoiKhach"
  echo "  Cầu thủ  : $TEST_CAU_THU (RIÊNG cho station $STATION_ID) ghi $HOME_GOALS bàn"
  echo "  Host máy : $HOST_NAME"
  echo ""
  echo "=== Verify dữ liệu trên STATION (local) ==="
  docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c \
    "SELECT MaTran, MaDoiNha, MaDoiKhach, BanThangNha, BanThangKhach, TrangThai FROM tran_dau_chuyen_mon WHERE MaTran LIKE 'TEST_${STATION_ID}_%';"
  echo "=== Top sự kiện test của $TEST_CAU_THU ==="
  docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c \
    "SELECT MaCauThu, LoaiSuKien, COUNT(*) AS so_lan, STRING_AGG(PhutGhiNhan::TEXT, ', ' ORDER BY PhutGhiNhan) AS phut FROM su_kien_tran_dau WHERE MaCauThu='$TEST_CAU_THU' GROUP BY MaCauThu, LoaiSuKien;"
  echo ""
  echo "================================================================"
  echo " HƯỚNG DẪN SAU INSERT (gửi cho admin master)"
  echo "================================================================"
  echo " Từ máy bạn (Station $STATION_ID - $TEN_CLB):"
  echo "   - MaTran: $MA_TRAN"
  echo "   - Tỉ số : $MA_DOI $HOME_GOALS-$AWAY_GOALS"
  echo "   - Cầu thủ-test $TEST_CAU_THU ghi $HOME_GOALS bàn"
  echo "   - Host : $HOST_NAME"
  echo ""
  echo " Admin master chạy:  make check-fdw"
  echo " Kết quả mong đợi trên master:"
  echo "   - vw_global_tran_dau có 1 dòng MaTran=$MA_TRAN với MaDoiNha=$MA_DOI"
  echo "   - vw_global_su_kien_tran_dau có $HOME_GOALS dòng của $TEST_CAU_THU"
  echo "   - fn_top10_vua_pha_luoi() có thể thấy $TEST_CAU_THU với $HOME_GOALS bàn"
  echo "   - vw_bang_xep_hang: $MA_DOI tăng 1 trận (thắng/hòa/thua tùy tỉ số)"
  echo ""
  echo " Cleanup sau demo:"
  echo "   ./scripts/station-test-cleanup.sh"
  echo "================================================================"
else
  echo "=== Test rollback OK - không để lại data. Chạy --commit để test thật. ==="
fi
