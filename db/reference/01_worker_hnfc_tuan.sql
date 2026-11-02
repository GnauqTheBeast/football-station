-- ============================================================================
-- TRẠM 1: CHI NHÁNH HÀ NỘI FC (SÂN HÀNG ĐẪY)
-- Người phụ trách: HOÀNG ANH TUẤN (Mã HV: B26CHHT102)
-- Địa chỉ IP ZeroTier: 10.147.17.11
-- Database: vleague_hnfc | Port: 5432
-- Nhiệm vụ: Quản lý 5 trận sân nhà của CLB Hà Nội FC (TR01, TR07, TR13, TR19, TR25)
-- ============================================================================

DROP TABLE IF EXISTS SU_KIEN_TRAN_DAU CASCADE;
DROP TABLE IF EXISTS TRAN_DAU_CHUYEN_MON CASCADE;
DROP TABLE IF EXISTS VONG_DAU CASCADE;
DROP TABLE IF EXISTS TRONG_TAI CASCADE;
DROP TABLE IF EXISTS CAU_THU CASCADE;
DROP TABLE IF EXISTS DOI_BONG CASCADE;
DROP TABLE IF EXISTS SAN_VAN_DONG CASCADE;

-- 1. BẢNG DANH MỤC DÙNG CHUNG (BẢN SAO READ-ONLY REPLICA)
CREATE TABLE SAN_VAN_DONG (
    MaSan VARCHAR(10) PRIMARY KEY,
    TenSan VARCHAR(100) NOT NULL,
    DiaChi VARCHAR(200) NOT NULL,
    SucChua INT NOT NULL,
    KhuVuc VARCHAR(20) NOT NULL
);

CREATE TABLE DOI_BONG (
    MaDoi VARCHAR(10) PRIMARY KEY,
    TenDoi VARCHAR(100) NOT NULL,
    HLV VARCHAR(100) NOT NULL,
    MaSanNha VARCHAR(10) NOT NULL
);

CREATE TABLE CAU_THU (
    MaCauThu VARCHAR(10) PRIMARY KEY,
    HoTen VARCHAR(100) NOT NULL,
    NgaySinh DATE NOT NULL,
    ViTri VARCHAR(20) NOT NULL,
    QuocTich VARCHAR(50) NOT NULL
);

CREATE TABLE TRONG_TAI (
    MaTrongTai VARCHAR(10) PRIMARY KEY,
    HoTen VARCHAR(100) NOT NULL,
    NgaySinh DATE NOT NULL,
    QueQuan VARCHAR(100) NOT NULL,
    CapBac VARCHAR(50) NOT NULL
);

CREATE TABLE VONG_DAU (
    MaVong INT PRIMARY KEY,
    TenVong VARCHAR(50) NOT NULL,
    ThuTu INT NOT NULL
);

-- 2. BẢNG PHÂN MẢNH CỤC BỘ TẠI TRẠM HÀ NỘI FC
CREATE TABLE TRAN_DAU_CHUYEN_MON (
    MaTran VARCHAR(10) PRIMARY KEY,
    MaVong INT NOT NULL,
    MaDoiNha VARCHAR(10) NOT NULL CHECK (MaDoiNha = 'HNFC'),
    MaDoiKhach VARCHAR(10) NOT NULL,
    MaSan VARCHAR(10) NOT NULL DEFAULT 'SAN_HD',
    NgayGio TIMESTAMP NOT NULL,
    BanThangNha INT NOT NULL DEFAULT 0,
    BanThangKhach INT NOT NULL DEFAULT 0,
    TheVangNha INT NOT NULL DEFAULT 0,
    TheVangKhach INT NOT NULL DEFAULT 0,
    TheDoNha INT NOT NULL DEFAULT 0,
    TheDoKhach INT NOT NULL DEFAULT 0,
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'DaKetThuc'
);

CREATE TABLE SU_KIEN_TRAN_DAU (
    MaSuKien VARCHAR(10) PRIMARY KEY,
    MaTran VARCHAR(10) NOT NULL REFERENCES TRAN_DAU_CHUYEN_MON(MaTran),
    MaCauThu VARCHAR(10) NOT NULL,
    LoaiSuKien VARCHAR(20) NOT NULL,
    PhutGhiNhan INT NOT NULL
);

-- 3. NẠP DỮ LIỆU CỤC BỘ 5 TRẬN SÂN NHÀ HÀ NỘI FC
INSERT INTO TRAN_DAU_CHUYEN_MON VALUES
('TR01', 1, 'HNFC', 'HPFC', 'SAN_HD', '2026-03-01 19:15:00', 2, 1, 2, 1, 0, 0, 'DaKetThuc'),
('TR07', 3, 'HNFC', 'CAHN', 'SAN_HD', '2026-03-15 19:15:00', 2, 2, 2, 3, 1, 0, 'DaKetThuc'),
('TR13', 5, 'HNFC', 'VTT',  'SAN_HD', '2026-03-29 19:15:00', 2, 1, 1, 2, 0, 0, 'DaKetThuc'),
('TR19', 7, 'HNFC', 'NDFC', 'SAN_HD', '2026-04-12 19:15:00', 1, 1, 1, 2, 0, 0, 'DaKetThuc'),
('TR25', 9, 'HNFC', 'HAGL', 'SAN_HD', '2026-04-26 19:15:00', 3, 0, 0, 1, 0, 0, 'DaKetThuc');

-- 4. NẠP SỰ KIỆN BÀN THẮNG & THẺ PHẠT CỦA 5 TRẬN NÀY
INSERT INTO SU_KIEN_TRAN_DAU VALUES
-- TR01: HNFC 2 - 1 HPFC
('SK001', 'TR01', 'CT007', 'BanThang', 23),
('SK002', 'TR01', 'CT008', 'BanThang', 67),
('SK003', 'TR01', 'CT082', 'BanThang', 81),
('SK004', 'TR01', 'CT002', 'TheVang', 44),
('SK005', 'TR01', 'CT006', 'TheVang', 75),
('SK006', 'TR01', 'CT075', 'TheVang', 89),

-- TR07: HNFC 2 - 2 CAHN
('SK038', 'TR07', 'CT008', 'BanThang', 18),
('SK039', 'TR07', 'CT016', 'BanThang', 70),
('SK040', 'TR07', 'CT027', 'BanThang', 35),
('SK041', 'TR07', 'CT024', 'BanThang', 89),
('SK042', 'TR07', 'CT002', 'TheVang', 25),
('SK043', 'TR07', 'CT006', 'TheVang', 60),
('SK044', 'TR07', 'CT009', 'TheDo', 85),
('SK045', 'TR07', 'CT021', 'TheVang', 44),
('SK046', 'TR07', 'CT025', 'TheVang', 66),
('SK047', 'TR07', 'CT028', 'TheVang', 90),

-- TR13: HNFC 2 - 1 VTT
('SK075', 'TR13', 'CT008', 'BanThang', 20),
('SK076', 'TR13', 'CT015', 'BanThang', 75),
('SK077', 'TR13', 'CT046', 'BanThang', 85),
('SK078', 'TR13', 'CT005', 'TheVang', 60),
('SK079', 'TR13', 'CT038', 'TheVang', 30),
('SK080', 'TR13', 'CT047', 'TheVang', 70),

-- TR19: HNFC 1 - 1 NDFC
('SK104', 'TR19', 'CT008', 'BanThang', 33),
('SK105', 'TR19', 'CT064', 'BanThang', 75),
('SK106', 'TR19', 'CT004', 'TheVang', 50),
('SK107', 'TR19', 'CT056', 'TheVang', 25),
('SK108', 'TR19', 'CT060', 'TheVang', 85),

-- TR25: HNFC 3 - 0 HAGL
('SK137', 'TR25', 'CT007', 'BanThang', 15),
('SK138', 'TR25', 'CT008', 'BanThang', 42),
('SK139', 'TR25', 'CT015', 'BanThang', 78),
('SK140', 'TR25', 'CT095', 'TheVang', 60);
