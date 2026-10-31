-- ============================================================================
-- TRẠM 0: TRẠM TRUNG TÂM (LIÊN ĐOÀN BÓNG ĐÁ VFF & BAN TỔ CHỨC GIẢI)
-- Người phụ trách: NGUYỄN NGỌC QUANG (Mã HV: B26CHHT086) - MÁY CHỦ MASTER
-- Địa chỉ IP ZeroTier: 10.147.17.10
-- Database: vleague_master | Port: 5432
-- Nhiệm vụ:
--   1. Quản lý bản Master danh mục toàn giải & Mảnh dọc tài chính (TRAN_DAU_DOANH_THU)
--   2. Cấu hình postgres_fdw kết nối 6 máy khách (Site 1 -> Site 6)
--   3. Tạo các View toàn cục tái thiết hệ thống thời gian thực
-- ============================================================================

-- Kích hoạt tiện ích mở rộng postgres_fdw
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- 1. BẢNG PHÂN MẢNH DỌC: TRAN_DAU_DOANH_THU (LƯU ĐỘC QUYỀN TẠI MÁY QUANG)
DROP TABLE IF EXISTS TRAN_DAU_DOANH_THU CASCADE;
CREATE TABLE TRAN_DAU_DOANH_THU (
    MaTran VARCHAR(10) PRIMARY KEY,
    GiaVe DECIMAL(12, 2) NOT NULL CHECK (GiaVe >= 0),
    SoKhach INT NOT NULL DEFAULT 0 CHECK (SoKhach >= 0)
);

-- Nạp dữ liệu doanh thu vé và khán giả của 30 trận toàn giải
INSERT INTO TRAN_DAU_DOANH_THU (MaTran, GiaVe, SoKhach) VALUES
('TR01', 80000, 15200), ('TR02', 80000, 12000), ('TR03', 60000, 18500), ('TR04', 70000, 22000),
('TR05', 70000, 19500), ('TR06', 50000, 9800),  ('TR07', 100000, 21500),('TR08', 60000, 14000),
('TR09', 70000, 18000), ('TR10', 50000, 10500), ('TR11', 90000, 17000), ('TR12', 70000, 16000),
('TR13', 90000, 18000), ('TR14', 80000, 24000), ('TR15', 60000, 13000), ('TR16', 80000, 17500),
('TR17', 50000, 11000), ('TR18', 70000, 21000), ('TR19', 90000, 19000), ('TR20', 80000, 14500),
('TR21', 60000, 12000), ('TR22', 100000, 22000),('TR23', 70000, 15000), ('TR24', 50000, 9500),
('TR25', 80000, 14000), ('TR26', 80000, 16500), ('TR27', 70000, 23000), ('TR28', 90000, 20000),
('TR29', 90000, 21000), ('TR30', 50000, 10000);

-- 2. BẢNG DANH MỤC CẦU THỦ GỐC (DÙNG ĐỂ TRA CỨU VUA PHÁ LƯỚI TẠI TRUNG TÂM)
DROP TABLE IF EXISTS CAU_THU CASCADE;
CREATE TABLE CAU_THU (
    MaCauThu VARCHAR(10) PRIMARY KEY,
    HoTen VARCHAR(100) NOT NULL,
    ViTri VARCHAR(20) NOT NULL
);

INSERT INTO CAU_THU (MaCauThu, HoTen, ViTri) VALUES
('CT007', 'Nguyễn Văn Quyết', 'TienDao'),
('CT008', 'Phạm Tuấn Hải', 'TienDao'),
('CT009', 'Đỗ Hùng Dũng', 'TienVe'),
('CT010', 'Nguyễn Thành Chung', 'HauVe'),
('CT015', 'Hai Long', 'TienVe'),
('CT016', 'Denilson Junior', 'TienDao'),
('CT024', 'Nguyễn Quang Hải', 'TienVe'),
('CT027', 'Phan Văn Đức', 'TienDao'),
('CT028', 'Geovane Magno', 'TienDao'),
('CT029', 'Jeferson Elias', 'TienDao'),
('CT042', 'Nguyễn Hoàng Đức', 'TienVe'),
('CT045', 'Trần Danh Trung', 'TienDao'),
('CT046', 'Nhâm Mạnh Dũng', 'TienDao'),
('CT061', 'Lâm Anh Quang', 'HauVe'),
('CT063', 'Nguyễn Văn Toàn', 'TienDao'),
('CT064', 'Rafaelson Bezerra', 'TienDao'),
('CT068', 'Trần Văn Kiên', 'HauVe'),
('CT082', 'Lucao do Break', 'TienDao'),
('CT083', 'Joseph Mpande', 'TienDao'),
('CT096', 'Trần Minh Vương', 'TienVe'),
('CT099', 'Nguyễn Quốc Việt', 'TienDao'),
('CT100', 'Gabriel Ferreira', 'TienDao');

-- 3. CẤU HÌNH LIÊN KẾT TỪ XA TỚI 6 MÁY KHÁCH QUA ZEROTIER
-- Xóa cấu hình cũ nếu có
DROP SCHEMA IF EXISTS site1_hnfc CASCADE;
DROP SCHEMA IF EXISTS site2_cahn CASCADE;
DROP SCHEMA IF EXISTS site3_viettel CASCADE;
DROP SCHEMA IF EXISTS site4_hpfc CASCADE;
DROP SCHEMA IF EXISTS site5_ndfc CASCADE;
DROP SCHEMA IF EXISTS site6_hagl CASCADE;

DROP SERVER IF EXISTS srv_tuan_hnfc CASCADE;
DROP SERVER IF EXISTS srv_thong_cahn CASCADE;
DROP SERVER IF EXISTS srv_dung_viettel CASCADE;
DROP SERVER IF EXISTS srv_quanganh_hpfc CASCADE;
DROP SERVER IF EXISTS srv_bich_ndfc CASCADE;
DROP SERVER IF EXISTS srv_minhdung_hagl CASCADE;

-- Tạo Foreign Server
CREATE SERVER srv_tuan_hnfc FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '10.147.17.11', port '5432', dbname 'vleague_hnfc');
CREATE SERVER srv_thong_cahn FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '10.147.17.12', port '5432', dbname 'vleague_cahn');
CREATE SERVER srv_dung_viettel FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '10.147.17.13', port '5432', dbname 'vleague_viettel');
CREATE SERVER srv_quanganh_hpfc FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '10.147.17.14', port '5432', dbname 'vleague_haiphong');
CREATE SERVER srv_bich_ndfc FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '10.147.17.15', port '5432', dbname 'vleague_namdinh');
CREATE SERVER srv_minhdung_hagl FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '10.147.17.16', port '5432', dbname 'vleague_hagl');

-- Tạo User Mapping (Giả sử mật khẩu mặc định 123456)
CREATE USER MAPPING FOR postgres SERVER srv_tuan_hnfc OPTIONS (user 'postgres', password '123456');
CREATE USER MAPPING FOR postgres SERVER srv_thong_cahn OPTIONS (user 'postgres', password '123456');
CREATE USER MAPPING FOR postgres SERVER srv_dung_viettel OPTIONS (user 'postgres', password '123456');
CREATE USER MAPPING FOR postgres SERVER srv_quanganh_hpfc OPTIONS (user 'postgres', password '123456');
CREATE USER MAPPING FOR postgres SERVER srv_bich_ndfc OPTIONS (user 'postgres', password '123456');
CREATE USER MAPPING FOR postgres SERVER srv_minhdung_hagl OPTIONS (user 'postgres', password '123456');

-- Tạo 6 schema đại diện cho 6 trạm ngoại lai
CREATE SCHEMA site1_hnfc;
CREATE SCHEMA site2_cahn;
CREATE SCHEMA site3_viettel;
CREATE SCHEMA site4_hpfc;
CREATE SCHEMA site5_ndfc;
CREATE SCHEMA site6_hagl;

-- Kéo cấu trúc bảng từ xa về 6 Schema
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_tuan_hnfc INTO site1_hnfc;
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_thong_cahn INTO site2_cahn;
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_dung_viettel INTO site3_viettel;
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_quanganh_hpfc INTO site4_hpfc;
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_bich_ndfc INTO site5_ndfc;
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_minhdung_hagl INTO site6_hagl;

-- 4. TÁI THIẾT VIEW TOÀN CỤC HỢP NHẤT TẤT CẢ CÁC TRẠM
CREATE OR REPLACE VIEW vw_global_tran_dau AS
SELECT 
    cm.MaTran, cm.MaVong, cm.MaDoiNha, cm.MaDoiKhach, cm.MaSan, cm.NgayGio,
    dt.GiaVe, dt.SoKhach,
    cm.BanThangNha, cm.BanThangKhach, cm.TheVangNha, cm.TheVangKhach, cm.TheDoNha, cm.TheDoKhach, cm.TrangThai
FROM (
    SELECT * FROM site1_hnfc.tran_dau_chuyen_mon
    UNION ALL
    SELECT * FROM site2_cahn.tran_dau_chuyen_mon
    UNION ALL
    SELECT * FROM site3_viettel.tran_dau_chuyen_mon
    UNION ALL
    SELECT * FROM site4_hpfc.tran_dau_chuyen_mon
    UNION ALL
    SELECT * FROM site5_ndfc.tran_dau_chuyen_mon
    UNION ALL
    SELECT * FROM site6_hagl.tran_dau_chuyen_mon
) cm
JOIN TRAN_DAU_DOANH_THU dt ON cm.MaTran = dt.MaTran;

CREATE OR REPLACE VIEW vw_global_su_kien_tran_dau AS
SELECT * FROM site1_hnfc.su_kien_tran_dau
UNION ALL
SELECT * FROM site2_cahn.su_kien_tran_dau
UNION ALL
SELECT * FROM site3_viettel.su_kien_tran_dau
UNION ALL
SELECT * FROM site4_hpfc.su_kien_tran_dau
UNION ALL
SELECT * FROM site5_ndfc.su_kien_tran_dau
UNION ALL
SELECT * FROM site6_hagl.su_kien_tran_dau;
