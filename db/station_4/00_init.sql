-- ============================================================================
-- TRẠM 4: CHI NHÁNH HẢI PHÒNG FC (SÂN LẠCH TRAY)
-- Người phụ trách: HỒ QUANG ANH (Mã HV: B26CHHT005)
-- Địa chỉ IP ZeroTier: 10.147.17.14
-- Database: vleague_haiphong | Port: 5432
-- Nhiệm vụ: Quản lý 5 trận sân nhà của CLB Hải Phòng (TR05, TR12, TR15, TR16, TR23)
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

-- 2. BẢNG PHÂN MẢNH CỤC BỘ TẠI TRẠM HẢI PHÒNG
CREATE TABLE TRAN_DAU_CHUYEN_MON (
    MaTran VARCHAR(10) PRIMARY KEY,
    MaVong INT NOT NULL,
    MaDoiNha VARCHAR(10) NOT NULL CHECK (MaDoiNha = 'HPFC'),
    MaDoiKhach VARCHAR(10) NOT NULL,
    MaSan VARCHAR(10) NOT NULL DEFAULT 'SAN_LT',
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

-- 3. NẠP DỮ LIỆU CỤC BỘ 5 TRẬN SÂN NHÀ HẢI PHÒNG
INSERT INTO TRAN_DAU_CHUYEN_MON VALUES
('TR05', 2, 'HPFC', 'CAHN', 'SAN_LT', '2026-03-08 19:15:00', 0, 2, 3, 1, 0, 0, 'DaKetThuc'),
('TR12', 4, 'HPFC', 'NDFC', 'SAN_LT', '2026-03-23 18:00:00', 1, 3, 1, 2, 0, 0, 'DaKetThuc'),
('TR15', 5, 'HPFC', 'HAGL', 'SAN_LT', '2026-03-30 18:00:00', 2, 0, 1, 0, 0, 0, 'DaKetThuc'),
('TR16', 6, 'HPFC', 'HNFC', 'SAN_LT', '2026-04-05 18:00:00', 1, 2, 2, 2, 0, 0, 'DaKetThuc'),
('TR23', 8, 'HPFC', 'VTT',  'SAN_LT', '2026-04-19 18:00:00', 1, 1, 2, 2, 0, 0, 'DaKetThuc');

-- 4. NẠP SỰ KIỆN BÀN THẮNG & THẺ PHẠT CỦA 5 TRẬN NÀY
INSERT INTO SU_KIEN_TRAN_DAU VALUES
-- TR05: HPFC 0 - 2 CAHN
('SK027', 'TR05', 'CT024', 'BanThang', 28),
('SK028', 'TR05', 'CT029', 'BanThang', 64),
('SK029', 'TR05', 'CT074', 'TheVang', 30),
('SK030', 'TR05', 'CT078', 'TheVang', 50),
('SK031', 'TR05', 'CT080', 'TheVang', 73),
('SK032', 'TR05', 'CT020', 'TheVang', 60),

-- TR12: HPFC 1 - 3 NDFC
('SK068', 'TR12', 'CT082', 'BanThang', 50),
('SK069', 'TR12', 'CT064', 'BanThang', 15),
('SK070', 'TR12', 'CT064', 'BanThang', 65),
('SK071', 'TR12', 'CT068', 'BanThang', 90),
('SK072', 'TR12', 'CT081', 'TheVang', 35),
('SK073', 'TR12', 'CT058', 'TheVang', 40),
('SK074', 'TR12', 'CT062', 'TheVang', 88),

-- TR15: HPFC 2 - 0 HAGL
('SK087', 'TR15', 'CT082', 'BanThang', 40),
('SK088', 'TR15', 'CT083', 'BanThang', 68),
('SK089', 'TR15', 'CT077', 'TheVang', 52),

-- TR16: HPFC 1 - 2 HNFC
('SK090', 'TR16', 'CT083', 'BanThang', 25),
('SK091', 'TR16', 'CT007', 'BanThang', 50),
('SK092', 'TR16', 'CT008', 'BanThang', 85),
('SK093', 'TR16', 'CT074', 'TheVang', 30),
('SK094', 'TR16', 'CT079', 'TheVang', 70),
('SK095', 'TR16', 'CT002', 'TheVang', 40),
('SK096', 'TR16', 'CT003', 'TheVang', 88),

-- TR23: HPFC 1 - 1 VTT
('SK128', 'TR23', 'CT082', 'BanThang', 35),
('SK129', 'TR23', 'CT046', 'BanThang', 70),
('SK130', 'TR23', 'CT076', 'TheVang', 25),
('SK131', 'TR23', 'CT078', 'TheVang', 65),
('SK132', 'TR23', 'CT039', 'TheVang', 40),
('SK133', 'TR23', 'CT041', 'TheVang', 82);
