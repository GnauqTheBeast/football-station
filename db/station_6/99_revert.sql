-- ============================================================================
-- TRẠM 6: ROLLBACK db/station_6/00_init.sql
-- Xóa toàn bộ 11 bảng + 6 trigger function + 5 stored procedure mà 00_init.sql
-- đã tạo, trả về database TRỐNG (clean slate). Chạy idempotent (IF EXISTS).
--
-- Lưu ý: đây là cách "thoái lui" trong psql. Cách nhanh nhất trên trạm thật vẫn
-- là xóa volume + init lại:
--   docker compose -f docker-compose.station.yml --env-file .env.station down -v
--   docker compose -f docker-compose.station.yml --env-file .env.station up -d
-- ============================================================================

-- 1. Xóa 11 BẢNG trước (CASCADE kéo theo 6 trigger gắn trên bảng)
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

-- 2. Xóa 6 TRIGGER FUNCTION (sau khi đã drop bảng + trigger)
DROP FUNCTION IF EXISTS fn_check_quy_dinh_san_dau();
DROP FUNCTION IF EXISTS fn_check_hop_dong_va_so_ao();
DROP FUNCTION IF EXISTS fn_check_dang_ky_thi_dau_va_treo_gio();
DROP FUNCTION IF EXISTS fn_check_phan_cong_trong_tai();
DROP FUNCTION IF EXISTS fn_check_khop_ban_thang_va_the();
DROP FUNCTION IF EXISTS fn_prevent_modify_finished_events();

-- 3. Xóa 5 STORED PROCEDURE (đúng chữ ký tham số)
DROP PROCEDURE IF EXISTS sp_tao_lich_thi_dau(VARCHAR, INT, VARCHAR, VARCHAR, VARCHAR, TIMESTAMP);
DROP PROCEDURE IF EXISTS sp_phan_cong_to_trong_tai(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP PROCEDURE IF EXISTS sp_dang_ky_cau_thu_tran(VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP PROCEDURE IF EXISTS sp_ghi_nhan_ket_qua_tran_dau(VARCHAR, INT, INT, INT, INT, INT, INT);
DROP PROCEDURE IF EXISTS sp_chuyen_nhuong_cho_muon_cau_thu(VARCHAR, VARCHAR, VARCHAR, VARCHAR, INT, DATE, DATE, VARCHAR);

-- KIỂM TRA: sau rollback nên còn 0 bảng / 0 trigger / 0 SP
SELECT COUNT(*) AS so_bang_con_lai
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

SELECT COUNT(*) AS so_trigger_con_lai FROM pg_trigger WHERE NOT tgisinternal;

SELECT COUNT(*) AS so_sp_ham_con_lai FROM pg_proc
WHERE proname LIKE 'sp\_%' OR proname LIKE 'fn_check\_%' OR proname LIKE 'fn_prevent\_%';