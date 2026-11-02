-- ============================================================================
-- TRẠM 2: CHI NHÁNH CÔNG AN HÀ NỘI (SÂN HÀNG ĐẪY)
-- Người phụ trách: ĐÀO DUY THÔNG (Mã HV: B26CHHT095)
-- Địa chỉ IP ZeroTier: 10.147.17.12
-- Database: vleague_cahn | Port: 5432
-- Nhiệm vụ: Quản lý 5 trận sân nhà của CLB Công An Hà Nội (TR02, TR11, TR20, TR22, TR29)
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

-- 2. BẢNG PHÂN MẢNH CỤC BỘ TẠI TRẠM CAHN
CREATE TABLE TRAN_DAU_CHUYEN_MON (
    MaTran VARCHAR(10) PRIMARY KEY,
    MaVong INT NOT NULL,
    MaDoiNha VARCHAR(10) NOT NULL CHECK (MaDoiNha = 'CAHN'),
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

-- 3. NẠP DỮ LIỆU CỤC BỘ 5 TRẬN SÂN NHÀ CAHN
INSERT INTO TRAN_DAU_CHUYEN_MON VALUES
('TR02', 1, 'CAHN', 'HAGL', 'SAN_HD', '2026-03-02 19:15:00', 3, 0, 1, 2, 0, 0, 'DaKetThuc'),
('TR11', 4, 'CAHN', 'VTT',  'SAN_HD', '2026-03-22 19:15:00', 1, 1, 2, 2, 0, 0, 'DaKetThuc'),
('TR20', 7, 'CAHN', 'HPFC', 'SAN_HD', '2026-04-13 19:15:00', 2, 1, 1, 1, 0, 0, 'DaKetThuc'),
('TR22', 8, 'CAHN', 'HNFC', 'SAN_HD', '2026-04-19 19:15:00', 1, 2, 3, 2, 0, 1, 'DaKetThuc'),
('TR29', 10, 'CAHN', 'NDFC', 'SAN_HD', '2026-05-03 18:00:00', 1, 1, 1, 2, 0, 0, 'DaKetThuc');

-- 4. NẠP SỰ KIỆN BÀN THẮNG & THẺ PHẠT CỦA 5 TRẬN NÀY
INSERT INTO SU_KIEN_TRAN_DAU VALUES
-- TR02: CAHN 3 - 0 HAGL
('SK007', 'TR02', 'CT024', 'BanThang', 15),
('SK008', 'TR02', 'CT028', 'BanThang', 52),
('SK009', 'TR02', 'CT029', 'BanThang', 78),
('SK010', 'TR02', 'CT023', 'TheVang', 33),
('SK011', 'TR02', 'CT094', 'TheVang', 40),
('SK012', 'TR02', 'CT096', 'TheVang', 85),

-- TR11: CAHN 1 - 1 VTT
('SK062', 'TR11', 'CT029', 'BanThang', 42),
('SK063', 'TR11', 'CT042', 'BanThang', 68),
('SK064', 'TR11', 'CT022', 'TheVang', 25),
('SK065', 'TR11', 'CT024', 'TheVang', 75),
('SK066', 'TR11', 'CT040', 'TheVang', 50),
('SK067', 'TR11', 'CT044', 'TheVang', 85),

-- TR20: CAHN 2 - 1 HPFC
('SK109', 'TR20', 'CT024', 'BanThang', 22),
('SK110', 'TR20', 'CT027', 'BanThang', 65),
('SK111', 'TR20', 'CT082', 'BanThang', 80),
('SK112', 'TR20', 'CT020', 'TheVang', 40),
('SK113', 'TR20', 'CT075', 'TheVang', 60),

-- TR22: CAHN 1 - 2 HNFC
('SK119', 'TR22', 'CT029', 'BanThang', 30),
('SK120', 'TR22', 'CT007', 'BanThang', 55),
('SK121', 'TR22', 'CT016', 'BanThang', 90),
('SK122', 'TR22', 'CT022', 'TheVang', 20),
('SK123', 'TR22', 'CT023', 'TheVang', 45),
('SK124', 'TR22', 'CT028', 'TheVang', 75),
('SK125', 'TR22', 'CT006', 'TheVang', 35),
('SK126', 'TR22', 'CT014', 'TheVang', 80),
('SK127', 'TR22', 'CT010', 'TheDo', 88),

-- TR29: CAHN 1 - 1 NDFC
('SK157', 'TR29', 'CT024', 'BanThang', 35),
('SK158', 'TR29', 'CT064', 'BanThang', 82),
('SK159', 'TR29', 'CT021', 'TheVang', 60),
('SK160', 'TR29', 'CT057', 'TheVang', 40),
('SK161', 'TR29', 'CT062', 'TheVang', 75);
