-- ============================================================================
-- HỆ CƠ SỞ DỮ LIỆU QUẢN LÝ GIẢI BÓNG ĐÁ CHUYÊN NGHIỆP
-- MÔN HỌC: CÁC HỆ THỐNG CƠ SỞ DỮ LIỆU - MÃ LỚP: M26CQ02 (NHÓM 2)
-- PHẦN 1: DDL TẠO BẢNG, KHÓA CHÍNH, KHÓA NGOẠI VÀ RÀNG BUỘC TOÀN VẸN
-- HỆ QUẢN TRỊ: PostgreSQL
-- ============================================================================

-- Xóa các bảng cũ nếu đã tồn tại (theo thứ tự phụ thuộc khóa ngoại)
DROP TABLE IF EXISTS SU_KIEN_TRAN_DAU CASCADE;
DROP TABLE IF EXISTS DANG_KY_THI_DAU CASCADE;
DROP TABLE IF EXISTS PHAN_CONG_TRONG_TAI CASCADE;
DROP TABLE IF EXISTS TRAN_DAU CASCADE;
DROP TABLE IF EXISTS VONG_DAU CASCADE;
DROP TABLE IF EXISTS TRONG_TAI CASCADE;
DROP TABLE IF EXISTS HOP_DONG_CAU_THU CASCADE;
DROP TABLE IF EXISTS CAU_THU CASCADE;
DROP TABLE IF EXISTS MAU_AO_DOI_BONG CASCADE;
DROP TABLE IF EXISTS DOI_BONG CASCADE;
DROP TABLE IF EXISTS SAN_VAN_DONG CASCADE;

-- 1. BẢNG SÂN VẬN ĐỘNG
CREATE TABLE SAN_VAN_DONG (
    MaSan VARCHAR(10) PRIMARY KEY,
    TenSan VARCHAR(100) NOT NULL UNIQUE,
    DiaChi VARCHAR(200) NOT NULL,
    SucChua INT NOT NULL CHECK (SucChua > 0),
    KhuVuc VARCHAR(20) NOT NULL DEFAULT 'MienBac' CHECK (KhuVuc IN ('MienBac', 'MienNam'))
);

-- 2. BẢNG ĐỘI BÓNG
CREATE TABLE DOI_BONG (
    MaDoi VARCHAR(10) PRIMARY KEY,
    TenDoi VARCHAR(100) NOT NULL UNIQUE,
    HLV VARCHAR(100) NOT NULL,
    MaSanNha VARCHAR(10) NOT NULL REFERENCES SAN_VAN_DONG(MaSan) ON UPDATE CASCADE
);

-- 3. BẢNG MÀU ÁO ĐỘI BÓNG (Tối thiểu 2 màu áo mỗi đội)
CREATE TABLE MAU_AO_DOI_BONG (
    MaDoi VARCHAR(10) NOT NULL REFERENCES DOI_BONG(MaDoi) ON DELETE CASCADE ON UPDATE CASCADE,
    LoaiMauAo VARCHAR(20) NOT NULL CHECK (LoaiMauAo IN ('SanNha', 'SanKhach', 'Phu')),
    MoTaMau VARCHAR(50) NOT NULL,
    PRIMARY KEY (MaDoi, LoaiMauAo)
);

-- 4. BẢNG CẦU THỦ
CREATE TABLE CAU_THU (
    MaCauThu VARCHAR(10) PRIMARY KEY,
    HoTen VARCHAR(100) NOT NULL,
    NgaySinh DATE NOT NULL,
    ViTri VARCHAR(20) NOT NULL CHECK (ViTri IN ('ThuMon', 'HauVe', 'TienVe', 'TienDao')),
    QuocTich VARCHAR(50) NOT NULL DEFAULT 'Việt Nam'
);

-- 5. BẢNG HỢP ĐỒNG CẦU THỦ & ĐỘI BÓNG THI ĐẤU
-- Lưu trữ toàn bộ lịch sử hợp đồng (Chính thức, Cho mượn, Đã thanh lý)
CREATE TABLE HOP_DONG_CAU_THU (
    MaHD VARCHAR(10) PRIMARY KEY,
    MaCauThu VARCHAR(10) NOT NULL REFERENCES CAU_THU(MaCauThu) ON UPDATE CASCADE,
    MaDoiChuQuan VARCHAR(10) NOT NULL REFERENCES DOI_BONG(MaDoi) ON UPDATE CASCADE,
    MaDoiHienTai VARCHAR(10) NOT NULL REFERENCES DOI_BONG(MaDoi) ON UPDATE CASCADE,
    SoAo INT NOT NULL CHECK (SoAo BETWEEN 1 AND 35),
    NgayBatDau DATE NOT NULL,
    NgayKetThuc DATE NOT NULL,
    TrangThai VARCHAR(20) NOT NULL CHECK (TrangThai IN ('ChinhThuc', 'ChoMuon', 'TamDung', 'ThanhLy')),
    CHECK (NgayKetThuc >= NgayBatDau)
);

-- Chỉ mục duy nhất có điều kiện (Partial Unique Index) cho các hợp đồng đang hiệu lực:
-- 1. Tại một thời điểm, mỗi cầu thủ chỉ có tối đa 1 hợp đồng đang thi đấu ('ChinhThuc' hoặc 'ChoMuon')
CREATE UNIQUE INDEX idx_uq_cauthu_active_contract 
ON HOP_DONG_CAU_THU (MaCauThu) 
WHERE TrangThai IN ('ChinhThuc', 'ChoMuon');

-- 2. Trong cùng một đội bóng, không có 2 cầu thủ nào trùng số áo trong các hợp đồng đang hiệu lực
CREATE UNIQUE INDEX idx_uq_doihientai_soao_active 
ON HOP_DONG_CAU_THU (MaDoiHienTai, SoAo) 
WHERE TrangThai IN ('ChinhThuc', 'ChoMuon');

-- 6. BẢNG TRỌNG TÀI
CREATE TABLE TRONG_TAI (
    MaTrongTai VARCHAR(10) PRIMARY KEY,
    HoTen VARCHAR(100) NOT NULL,
    NgaySinh DATE NOT NULL,
    QueQuan VARCHAR(100) NOT NULL,
    CapBac VARCHAR(50) NOT NULL DEFAULT 'Quốc gia'
);

-- 7. BẢNG VÒNG ĐẤU (10 vòng đấu mùa giải)
CREATE TABLE VONG_DAU (
    MaVong INT PRIMARY KEY CHECK (MaVong BETWEEN 1 AND 10),
    TenVong VARCHAR(50) NOT NULL UNIQUE,
    ThuTu INT NOT NULL UNIQUE CHECK (ThuTu BETWEEN 1 AND 10)
);

-- 8. BẢNG TRẬN ĐẤU
CREATE TABLE TRAN_DAU (
    MaTran VARCHAR(10) PRIMARY KEY,
    MaVong INT NOT NULL REFERENCES VONG_DAU(MaVong) ON UPDATE CASCADE,
    MaDoiNha VARCHAR(10) NOT NULL REFERENCES DOI_BONG(MaDoi) ON UPDATE CASCADE,
    MaDoiKhach VARCHAR(10) NOT NULL REFERENCES DOI_BONG(MaDoi) ON UPDATE CASCADE,
    MaSan VARCHAR(10) NOT NULL REFERENCES SAN_VAN_DONG(MaSan) ON UPDATE CASCADE,
    NgayGio TIMESTAMP NOT NULL,
    GiaVe DECIMAL(12, 2) NOT NULL DEFAULT 50000 CHECK (GiaVe >= 0),
    SoKhach INT DEFAULT 0 CHECK (SoKhach >= 0),
    BanThangNha INT DEFAULT 0 CHECK (BanThangNha >= 0),
    BanThangKhach INT DEFAULT 0 CHECK (BanThangKhach >= 0),
    TheVangNha INT DEFAULT 0 CHECK (TheVangNha >= 0),
    TheVangKhach INT DEFAULT 0 CHECK (TheVangKhach >= 0),
    TheDoNha INT DEFAULT 0 CHECK (TheDoNha >= 0),
    TheDoKhach INT DEFAULT 0 CHECK (TheDoKhach >= 0),
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'ChuaDienRa' CHECK (TrangThai IN ('ChuaDienRa', 'DaKetThuc')),
    CHECK (MaDoiNha <> MaDoiKhach),
    UNIQUE (MaDoiNha, MaDoiKhach),
    UNIQUE (MaVong, MaDoiNha),
    UNIQUE (MaVong, MaDoiKhach)
);

-- 9. BẢNG PHÂN CÔNG TRỌNG TÀI (Đủ 4 trọng tài cho mỗi trận)
CREATE TABLE PHAN_CONG_TRONG_TAI (
    MaTran VARCHAR(10) NOT NULL REFERENCES TRAN_DAU(MaTran) ON DELETE CASCADE ON UPDATE CASCADE,
    VaiTro VARCHAR(20) NOT NULL CHECK (VaiTro IN ('Chinh', 'Bien1', 'Bien2', 'Ban')),
    MaTrongTai VARCHAR(10) NOT NULL REFERENCES TRONG_TAI(MaTrongTai) ON UPDATE CASCADE,
    PRIMARY KEY (MaTran, VaiTro),
    UNIQUE (MaTran, MaTrongTai)
);

-- 10. BẢNG ĐĂNG KÝ THI ĐẤU (Tối đa 18 cầu thủ mỗi đội trong trận)
CREATE TABLE DANG_KY_THI_DAU (
    MaTran VARCHAR(10) NOT NULL REFERENCES TRAN_DAU(MaTran) ON DELETE CASCADE ON UPDATE CASCADE,
    MaCauThu VARCHAR(10) NOT NULL REFERENCES CAU_THU(MaCauThu) ON UPDATE CASCADE,
    MaDoi VARCHAR(10) NOT NULL REFERENCES DOI_BONG(MaDoi) ON UPDATE CASCADE,
    VaiTroThiDau VARCHAR(20) NOT NULL CHECK (VaiTroThiDau IN ('ChinhThuc', 'DuBi')),
    SoAoDangKy INT NOT NULL CHECK (SoAoDangKy BETWEEN 1 AND 35),
    PRIMARY KEY (MaTran, MaCauThu),
    UNIQUE (MaTran, MaDoi, SoAoDangKy)
);

-- 11. BẢNG SỰ KIỆN TRẬN ĐẤU (Đã chuẩn hóa BCNF: Loại bỏ MaDoi dư thừa, tham chiếu tổ hợp tới DANG_KY_THI_DAU)
CREATE TABLE SU_KIEN_TRAN_DAU (
    MaSuKien VARCHAR(15) PRIMARY KEY,
    MaTran VARCHAR(10) NOT NULL,
    MaCauThu VARCHAR(10) NOT NULL,
    LoaiSuKien VARCHAR(20) NOT NULL CHECK (LoaiSuKien IN ('BanThang', 'PhanLuoi', 'TheVang', 'TheDo')),
    PhutGhiNhan INT NOT NULL CHECK (PhutGhiNhan BETWEEN 1 AND 120),
    FOREIGN KEY (MaTran, MaCauThu) REFERENCES DANG_KY_THI_DAU(MaTran, MaCauThu) ON DELETE CASCADE ON UPDATE CASCADE
);

-- TẠO CHỈ MỤC (INDEX) ĐỂ TỐI ƯU TRUY VẤN
CREATE INDEX idx_tran_dau_vong ON TRAN_DAU(MaVong);
CREATE INDEX idx_tran_dau_san_ngaygio ON TRAN_DAU(MaSan, NgayGio);
CREATE INDEX idx_tran_dau_doinha ON TRAN_DAU(MaDoiNha);
CREATE INDEX idx_tran_dau_doikhach ON TRAN_DAU(MaDoiKhach);
CREATE INDEX idx_hopdong_doihientai ON HOP_DONG_CAU_THU(MaDoiHienTai);
CREATE INDEX idx_sukien_tran_cauthu ON SU_KIEN_TRAN_DAU(MaTran, MaCauThu);
CREATE INDEX idx_dangky_tran_doi ON DANG_KY_THI_DAU(MaTran, MaDoi);
