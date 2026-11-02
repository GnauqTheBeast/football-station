-- ============================================================================
-- TRẠM 3: CHI NHÁNH THỂ CÔNG VIETTEL (SÂN QUỐC GIA MỸ ĐÌNH)
-- Người phụ trách: NGUYỄN HOÀNG MẠNH DŨNG (Mã HV: B26CHHT026)
-- Địa chỉ IP ZeroTier: 10.147.17.13
-- Database: vleague_viettel | Port: 5432
-- Nhiệm vụ: Quản lý 5 trận sân nhà của CLB Thể Công Viettel (TR03, TR08, TR21, TR26, TR28)
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

-- 2. BẢNG PHÂN MẢNH CỤC BỘ TẠI TRẠM VIETTEL
CREATE TABLE TRAN_DAU_CHUYEN_MON (
    MaTran VARCHAR(10) PRIMARY KEY,
    MaVong INT NOT NULL,
    MaDoiNha VARCHAR(10) NOT NULL CHECK (MaDoiNha = 'VTT'),
    MaDoiKhach VARCHAR(10) NOT NULL,
    MaSan VARCHAR(10) NOT NULL DEFAULT 'SAN_MD',
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

-- 3. NẠP DỮ LIỆU CỤC BỘ 5 TRẬN SÂN NHÀ VIETTEL
INSERT INTO TRAN_DAU_CHUYEN_MON VALUES
('TR03', 1, 'VTT', 'NDFC', 'SAN_MD', '2026-03-01 18:00:00', 1, 2, 1, 1, 0, 0, 'DaKetThuc'),
('TR08', 3, 'VTT', 'HPFC', 'SAN_MD', '2026-03-15 18:00:00', 2, 0, 1, 1, 0, 0, 'DaKetThuc'),
('TR21', 7, 'VTT', 'HAGL', 'SAN_MD', '2026-04-12 18:00:00', 3, 1, 0, 1, 0, 0, 'DaKetThuc'),
('TR26', 9, 'VTT', 'CAHN', 'SAN_MD', '2026-04-26 18:00:00', 2, 1, 2, 1, 0, 0, 'DaKetThuc'),
('TR28', 10, 'VTT', 'HNFC', 'SAN_MD', '2026-05-03 18:00:00', 1, 1, 2, 2, 0, 0, 'DaKetThuc');

-- 4. NẠP SỰ KIỆN BÀN THẮNG & THẺ PHẠT CỦA 5 TRẬN NÀY
INSERT INTO SU_KIEN_TRAN_DAU VALUES
-- TR03: VTT 1 - 2 NDFC
('SK013', 'TR03', 'CT046', 'BanThang', 30),
('SK014', 'TR03', 'CT064', 'BanThang', 45),
('SK015', 'TR03', 'CT064', 'BanThang', 88),
('SK016', 'TR03', 'CT043', 'TheVang', 62),
('SK017', 'TR03', 'CT059', 'TheVang', 71),

-- TR08: VTT 2 - 0 HPFC
('SK048', 'TR08', 'CT046', 'BanThang', 22),
('SK049', 'TR08', 'CT045', 'BanThang', 76),
('SK050', 'TR08', 'CT039', 'TheVang', 50),
('SK051', 'TR08', 'CT076', 'TheVang', 80),

-- TR21: VTT 3 - 1 HAGL
('SK114', 'TR21', 'CT042', 'BanThang', 15),
('SK115', 'TR21', 'CT046', 'BanThang', 48),
('SK116', 'TR21', 'CT045', 'BanThang', 82),
('SK117', 'TR21', 'CT096', 'BanThang', 60),
('SK118', 'TR21', 'CT094', 'TheVang', 70),

-- TR26: VTT 2 - 1 CAHN
('SK141', 'TR26', 'CT042', 'BanThang', 25),
('SK142', 'TR26', 'CT046', 'BanThang', 80),
('SK143', 'TR26', 'CT024', 'BanThang', 60),
('SK144', 'TR26', 'CT038', 'TheVang', 35),
('SK145', 'TR26', 'CT044', 'TheVang', 75),
('SK146', 'TR26', 'CT025', 'TheVang', 50),

-- TR28: VTT 1 - 1 HNFC
('SK151', 'TR28', 'CT046', 'BanThang', 45),
('SK152', 'TR28', 'CT008', 'BanThang', 70),
('SK153', 'TR28', 'CT040', 'TheVang', 30),
('SK154', 'TR28', 'CT043', 'TheVang', 85),
('SK155', 'TR28', 'CT002', 'TheVang', 50),
('SK156', 'TR28', 'CT004', 'TheVang', 90);
