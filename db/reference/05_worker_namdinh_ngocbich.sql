-- ============================================================================
-- TRẠM 5: CHI NHÁNH THÉP XANH NAM ĐỊNH (SÂN THIÊN TRƯỜNG)
-- Người phụ trách: NGUYỄN THỊ NGỌC BÍCH (Mã HV: B26CHHT010)
-- Địa chỉ IP ZeroTier: 10.147.17.15
-- Database: vleague_namdinh | Port: 5432
-- Nhiệm vụ: Quản lý 5 trận sân nhà của CLB Nam Định (TR04, TR09, TR14, TR18, TR27)
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

-- 2. BẢNG PHÂN MẢNH CỤC BỘ TẠI TRẠM NAM ĐỊNH
CREATE TABLE TRAN_DAU_CHUYEN_MON (
    MaTran VARCHAR(10) PRIMARY KEY,
    MaVong INT NOT NULL,
    MaDoiNha VARCHAR(10) NOT NULL CHECK (MaDoiNha = 'NDFC'),
    MaDoiKhach VARCHAR(10) NOT NULL,
    MaSan VARCHAR(10) NOT NULL DEFAULT 'SAN_TT',
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

-- 3. NẠP DỮ LIỆU CỤC BỘ 5 TRẬN SÂN NHÀ NAM ĐỊNH
INSERT INTO TRAN_DAU_CHUYEN_MON VALUES
('TR04', 2, 'NDFC', 'HNFC', 'SAN_TT', '2026-03-08 18:00:00', 3, 2, 2, 2, 0, 0, 'DaKetThuc'),
('TR09', 3, 'NDFC', 'HAGL', 'SAN_TT', '2026-03-16 18:00:00', 4, 1, 0, 1, 0, 0, 'DaKetThuc'),
('TR14', 5, 'NDFC', 'CAHN', 'SAN_TT', '2026-03-29 18:00:00', 2, 1, 2, 1, 0, 0, 'DaKetThuc'),
('TR18', 6, 'NDFC', 'VTT',  'SAN_TT', '2026-04-06 18:00:00', 1, 0, 1, 1, 0, 0, 'DaKetThuc'),
('TR27', 9, 'NDFC', 'HPFC', 'SAN_TT', '2026-04-27 18:00:00', 2, 0, 1, 1, 0, 0, 'DaKetThuc');

-- 4. NẠP SỰ KIỆN BÀN THẮNG & THẺ PHẠT CỦA 5 TRẬN NÀY
INSERT INTO SU_KIEN_TRAN_DAU VALUES
-- TR04: NDFC 3 - 2 HNFC
('SK018', 'TR04', 'CT064', 'BanThang', 12),
('SK019', 'TR04', 'CT061', 'BanThang', 55),
('SK020', 'TR04', 'CT063', 'BanThang', 90),
('SK021', 'TR04', 'CT007', 'BanThang', 35),
('SK022', 'TR04', 'CT015', 'BanThang', 82),
('SK023', 'TR04', 'CT056', 'TheVang', 20),
('SK024', 'TR04', 'CT060', 'TheVang', 77),
('SK025', 'TR04', 'CT003', 'TheVang', 41),
('SK026', 'TR04', 'CT004', 'TheVang', 84),

-- TR09: NDFC 4 - 1 HAGL
('SK052', 'TR09', 'CT064', 'BanThang', 10),
('SK053', 'TR09', 'CT064', 'BanThang', 38),
('SK054', 'TR09', 'CT061', 'BanThang', 60),
('SK055', 'TR09', 'CT063', 'BanThang', 82),
('SK056', 'TR09', 'CT099', 'BanThang', 70),
('SK057', 'TR09', 'CT093', 'TheVang', 45),

-- TR14: NDFC 2 - 1 CAHN
('SK081', 'TR14', 'CT064', 'BanThang', 30),
('SK082', 'TR14', 'CT063', 'BanThang', 72),
('SK083', 'TR14', 'CT024', 'BanThang', 55),
('SK084', 'TR14', 'CT057', 'TheVang', 45),
('SK085', 'TR14', 'CT061', 'TheVang', 80),
('SK086', 'TR14', 'CT026', 'TheVang', 65),

-- TR18: NDFC 1 - 0 VTT
('SK101', 'TR18', 'CT064', 'BanThang', 60),
('SK102', 'TR18', 'CT059', 'TheVang', 45),
('SK103', 'TR18', 'CT043', 'TheVang', 80),

-- TR27: NDFC 2 - 0 HPFC
('SK147', 'TR27', 'CT064', 'BanThang', 40),
('SK148', 'TR27', 'CT061', 'BanThang', 75),
('SK149', 'TR27', 'CT058', 'TheVang', 30),
('SK150', 'TR27', 'CT080', 'TheVang', 65);
