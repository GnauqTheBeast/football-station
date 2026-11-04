-- ============================================================================
-- PHẦN 1b: BẢNG PHÂN MẢNH CỤC BỘ (4 BẢNG) - Mảnh ngang theo CLB chủ nhà
-- __MA_DOI_NHA__: mã CLB chủ nhà của trạm (HNFC/CAHN/VTT/HPFC/NDFC/HAGL)
-- __MA_SAN__:     mã sân nhà của trạm
-- ============================================================================

-- 8. BẢNG TRẬN ĐẤU CHUYÊN MÔN (mảnh ngang: chỉ các trận sân nhà của __MA_DOI_NHA__)
--    Không có cột GiaVe/SoKhach (thuộc mảnh dọc tài chính trên MASTER)
CREATE TABLE TRAN_DAU_CHUYEN_MON (
    MaTran VARCHAR(10) PRIMARY KEY,
    MaVong INT NOT NULL REFERENCES VONG_DAU(MaVong) ON UPDATE CASCADE,
    MaDoiNha VARCHAR(10) NOT NULL REFERENCES DOI_BONG(MaDoi) ON UPDATE CASCADE CHECK (MaDoiNha = '__MA_DOI_NHA__'),
    MaDoiKhach VARCHAR(10) NOT NULL REFERENCES DOI_BONG(MaDoi) ON UPDATE CASCADE,
    MaSan VARCHAR(10) NOT NULL DEFAULT '__MA_SAN__' REFERENCES SAN_VAN_DONG(MaSan) ON UPDATE CASCADE,
    NgayGio TIMESTAMP NOT NULL,
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
    MaTran VARCHAR(10) NOT NULL REFERENCES TRAN_DAU_CHUYEN_MON(MaTran) ON DELETE CASCADE ON UPDATE CASCADE,
    VaiTro VARCHAR(20) NOT NULL CHECK (VaiTro IN ('Chinh', 'Bien1', 'Bien2', 'Ban')),
    MaTrongTai VARCHAR(10) NOT NULL REFERENCES TRONG_TAI(MaTrongTai) ON UPDATE CASCADE,
    PRIMARY KEY (MaTran, VaiTro),
    UNIQUE (MaTran, MaTrongTai)
);

-- 10. BẢNG ĐĂNG KÝ THI ĐẤU (Tối đa 18 cầu thủ mỗi đội trong trận)
CREATE TABLE DANG_KY_THI_DAU (
    MaTran VARCHAR(10) NOT NULL REFERENCES TRAN_DAU_CHUYEN_MON(MaTran) ON DELETE CASCADE ON UPDATE CASCADE,
    MaCauThu VARCHAR(10) NOT NULL REFERENCES CAU_THU(MaCauThu) ON UPDATE CASCADE,
    MaDoi VARCHAR(10) NOT NULL REFERENCES DOI_BONG(MaDoi) ON UPDATE CASCADE,
    VaiTroThiDau VARCHAR(20) NOT NULL CHECK (VaiTroThiDau IN ('ChinhThuc', 'DuBi')),
    SoAoDangKy INT NOT NULL CHECK (SoAoDangKy BETWEEN 1 AND 35),
    PRIMARY KEY (MaTran, MaCauThu),
    UNIQUE (MaTran, MaDoi, SoAoDangKy)
);

-- 11. BẢNG SỰ KIỆN TRẬN ĐẤU (chuẩn hóa BCNF: tham chiếu tổ hợp tới DANG_KY_THI_DAU)
CREATE TABLE SU_KIEN_TRAN_DAU (
    MaSuKien VARCHAR(15) PRIMARY KEY,
    MaTran VARCHAR(10) NOT NULL,
    MaCauThu VARCHAR(10) NOT NULL,
    LoaiSuKien VARCHAR(20) NOT NULL CHECK (LoaiSuKien IN ('BanThang', 'PhanLuoi', 'TheVang', 'TheDo')),
    PhutGhiNhan INT NOT NULL CHECK (PhutGhiNhan BETWEEN 1 AND 120),
    FOREIGN KEY (MaTran, MaCauThu) REFERENCES DANG_KY_THI_DAU(MaTran, MaCauThu) ON DELETE CASCADE ON UPDATE CASCADE
);

-- TẠO CHỈ MỤC (INDEX) ĐỂ TỐI ƯU TRUY VẤN
CREATE INDEX idx_hopdong_doihientai ON HOP_DONG_CAU_THU(MaDoiHienTai);
CREATE INDEX idx_tdc_vong ON TRAN_DAU_CHUYEN_MON(MaVong);
CREATE INDEX idx_tdc_san_ngaygio ON TRAN_DAU_CHUYEN_MON(MaSan, NgayGio);
CREATE INDEX idx_tdc_doinha ON TRAN_DAU_CHUYEN_MON(MaDoiNha);
CREATE INDEX idx_tdc_doikhach ON TRAN_DAU_CHUYEN_MON(MaDoiKhach);
CREATE INDEX idx_sukien_tran_cauthu ON SU_KIEN_TRAN_DAU(MaTran, MaCauThu);
CREATE INDEX idx_dangky_tran_doi ON DANG_KY_THI_DAU(MaTran, MaDoi);