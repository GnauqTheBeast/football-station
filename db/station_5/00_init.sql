-- ============================================================================
-- TRẠM 5: CHI NHÁNH THÉP XANH NAM ĐỊNH (SÂN THIÊN TRƯỜNG)
-- Người phụ trách: NGUYỄN THỊ NGỌC BÍCH (Mã HV: B26CHHT010)
-- Địa chỉ IP ZeroTier: 10.147.17.15
-- Database: vleague_namdinh | Port: 5432
-- Nhiệm vụ: Quản lý 5 trận sân nhà của CLB THÉP XANH NAM ĐỊNH (TR04, TR09, TR14, TR18, TR27)
--
-- KẾT CẤU (11 bảng theo báo cáo):
--   7 bảng danh mục (replica read-only, đủ data):
--     SAN_VAN_DONG, DOI_BONG, MAU_AO_DOI_BONG, CAU_THU, HOP_DONG_CAU_THU,
--     TRONG_TAI, VONG_DAU
--   4 bảng phân mảnh cục bộ (mảnh ngang theo CLB NDFC):
--     TRAN_DAU_CHUYEN_MON, PHAN_CONG_TRONG_TAI, DANG_KY_THI_DAU, SU_KIEN_TRAN_DAU
--   6 trigger + 5 stored procedure (thích ứng TRAN_DAU -> TRAN_DAU_CHUYEN_MON)
--
-- File này IDMPOTENT (DROP trước khi CREATE) - chạy lại an toàn.
-- Rollback: db/station_5/99_revert.sql
-- ============================================================================

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

-- ----------------------------------------------------------------------------
-- PHẦN 1: DDL 7 BẢNG DANH MỤC (replica read-only - verbatim từ BTL tập trung)
-- ----------------------------------------------------------------------------
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

-- ============================================================================
-- PHẦN 1b: BẢNG PHÂN MẢNH CỤC BỘ (4 BẢNG) - Mảnh ngang theo CLB chủ nhà
-- NDFC: mã CLB chủ nhà của trạm (HNFC/CAHN/VTT/HPFC/NDFC/HAGL)
-- SAN_TT:     mã sân nhà của trạm
-- ============================================================================

-- 8. BẢNG TRẬN ĐẤU CHUYÊN MÔN (mảnh ngang: chỉ các trận sân nhà của NDFC)
--    Không có cột GiaVe/SoKhach (thuộc mảnh dọc tài chính trên MASTER)
CREATE TABLE TRAN_DAU_CHUYEN_MON (
    MaTran VARCHAR(10) PRIMARY KEY,
    MaVong INT NOT NULL REFERENCES VONG_DAU(MaVong) ON UPDATE CASCADE,
    MaDoiNha VARCHAR(10) NOT NULL REFERENCES DOI_BONG(MaDoi) ON UPDATE CASCADE CHECK (MaDoiNha = 'NDFC'),
    MaDoiKhach VARCHAR(10) NOT NULL REFERENCES DOI_BONG(MaDoi) ON UPDATE CASCADE,
    MaSan VARCHAR(10) NOT NULL DEFAULT 'SAN_TT' REFERENCES SAN_VAN_DONG(MaSan) ON UPDATE CASCADE,
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
-- ============================================================================
-- PHẦN 2: 6 TRIGGER (bản trạm - thích ứng TRAN_DAU -> TRAN_DAU_CHUYEN_MON)
-- Khác biệt so với bản tập trung (db/centralized/02_triggers.sql):
--   - Trigger 1: bỏ kiểm tra SoKhach (bảng trạm không có cột SoKhach)
--   - Trigger 3, 4, 6: tham chiếu TRAN_DAU -> TRAN_DAU_CHUYEN_MON
--   - Trigger 5: ON TRAN_DAU -> ON TRAN_DAU_CHUYEN_MON
--   - Trigger 2: giữ nguyên (bảng HOP_DONG_CAU_THU là replica danh mục)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1: KIỂM TRA QUY ĐỊNH SÂN ĐẤU VÀ THỜI GIAN THI ĐẤU
-- Bảng áp dụng: TRAN_DAU_CHUYEN_MON
-- Nghiệp vụ: trận kết thúc không ở tương lai; hai trận cùng sân cách nhau >= 4 giờ.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_quy_dinh_san_dau()
RETURNS TRIGGER AS $$
DECLARE
    v_so_tran_trung_gio INT;
BEGIN
    -- Khóa dòng sân vận động (Row-level lock) để tuần tự hóa các giao dịch xếp lịch đồng thời
    PERFORM 1 FROM SAN_VAN_DONG WHERE MaSan = NEW.MaSan FOR NO KEY UPDATE;

    -- 1. Kiểm tra tính hợp lệ về thời gian khi kết thúc trận
    IF NEW.TrangThai = 'DaKetThuc' AND NEW.NgayGio > CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'Lỗi nghiệp vụ: Trận đấu có thời điểm diễn ra ở tương lai không thể có trạng thái DaKetThuc!';
    END IF;

    -- 2. Kiểm tra khoảng cách 4 giờ trên cùng sân vận động
    SELECT COUNT(*) INTO v_so_tran_trung_gio
    FROM TRAN_DAU_CHUYEN_MON
    WHERE MaSan = NEW.MaSan
      AND MaTran <> NEW.MaTran
      AND NgayGio > NEW.NgayGio - INTERVAL '4 hours'
      AND NgayGio < NEW.NgayGio + INTERVAL '4 hours';

    IF v_so_tran_trung_gio > 0 THEN
        RAISE EXCEPTION 'Lỗi nghiệp vụ: Sân vận động % đã có trận đấu khác diễn ra trong khoảng 4 giờ lân cận!',
            NEW.MaSan;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_quy_dinh_san_dau ON TRAN_DAU_CHUYEN_MON;
CREATE TRIGGER trg_check_quy_dinh_san_dau
BEFORE INSERT OR UPDATE OF MaSan, NgayGio, TrangThai
ON TRAN_DAU_CHUYEN_MON
FOR EACH ROW
EXECUTE FUNCTION fn_check_quy_dinh_san_dau();


-- ----------------------------------------------------------------------------
-- TRIGGER 2: KIỂM TRA HỢP ĐỒNG CẦU THỦ, SỐ ÁO VÀ GIỚI HẠN TỐI ĐA 30 CẦU THỦ
-- Bảng áp dụng: HOP_DONG_CAU_THU (bản sao replica - giữ nguyên như tập trung)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_hop_dong_va_so_ao()
RETURNS TRIGGER AS $$
DECLARE
    v_so_hop_dong_hieu_luc INT;
    v_trung_so_ao INT;
    v_so_luong_cau_thu INT;
BEGIN
    -- Khóa bản ghi đội bóng cha để tuần tự hóa các giao dịch đăng ký cầu thủ vào cùng một đội
    PERFORM 1 FROM DOI_BONG WHERE MaDoi = NEW.MaDoiHienTai FOR NO KEY UPDATE;

    -- Chỉ kiểm tra các hợp đồng đang có hiệu lực thi đấu
    IF NEW.TrangThai IN ('ChinhThuc', 'ChoMuon') THEN
        -- 1. Kiểm tra cầu thủ có đang vướng hợp đồng hiệu lực nào khác không
        SELECT COUNT(*) INTO v_so_hop_dong_hieu_luc
        FROM HOP_DONG_CAU_THU
        WHERE MaCauThu = NEW.MaCauThu
          AND MaHD <> NEW.MaHD
          AND TrangThai IN ('ChinhThuc', 'ChoMuon')
          AND NOT (NgayKetThuc < NEW.NgayBatDau OR NgayBatDau > NEW.NgayKetThuc);

        IF v_so_hop_dong_hieu_luc > 0 THEN
            RAISE EXCEPTION 'Lỗi nghiệp vụ: Cầu thủ % đang có hợp đồng thi đấu còn hiệu lực khác trong thời gian này!',
                NEW.MaCauThu;
        END IF;

        -- 2. Kiểm tra số áo không trùng trong cùng đội bóng đang thi đấu
        SELECT COUNT(*) INTO v_trung_so_ao
        FROM HOP_DONG_CAU_THU
        WHERE MaDoiHienTai = NEW.MaDoiHienTai
          AND SoAo = NEW.SoAo
          AND MaHD <> NEW.MaHD
          AND TrangThai IN ('ChinhThuc', 'ChoMuon')
          AND NOT (NgayKetThuc < NEW.NgayBatDau OR NgayBatDau > NEW.NgayKetThuc);

        IF v_trung_so_ao > 0 THEN
            RAISE EXCEPTION 'Lỗi nghiệp vụ: Số áo % đã được sử dụng bởi cầu thủ khác trong đội bóng %!',
                NEW.SoAo, NEW.MaDoiHienTai;
        END IF;

        -- 3. Kiểm tra giới hạn tối đa 30 cầu thủ đang thi đấu của đội bóng
        SELECT COUNT(*) INTO v_so_luong_cau_thu
        FROM HOP_DONG_CAU_THU
        WHERE MaDoiHienTai = NEW.MaDoiHienTai
          AND MaHD <> NEW.MaHD
          AND TrangThai IN ('ChinhThuc', 'ChoMuon');

        IF v_so_luong_cau_thu >= 30 THEN
            RAISE EXCEPTION 'Lỗi nghiệp vụ: Đội bóng % đã có đủ tối đa 30 cầu thủ đang thi đấu!',
                NEW.MaDoiHienTai;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_hop_dong_va_so_ao ON HOP_DONG_CAU_THU;
CREATE TRIGGER trg_check_hop_dong_va_so_ao
BEFORE INSERT OR UPDATE OF MaDoiHienTai, SoAo, NgayBatDau, NgayKetThuc, TrangThai
ON HOP_DONG_CAU_THU
FOR EACH ROW
EXECUTE FUNCTION fn_check_hop_dong_va_so_ao();


-- ----------------------------------------------------------------------------
-- TRIGGER 3: KIỂM TRA ĐĂNG KÝ THI ĐẤU (11 ĐÁ CHÍNH, TỐI ĐA 7 DỰ BỊ) VÀ ÁN TREO GIÒ
-- Bảng áp dụng: DANG_KY_THI_DAU
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_dang_ky_thi_dau_va_treo_gio()
RETURNS TRIGGER AS $$
DECLARE
    v_ma_vong INT;
    v_doi_nha VARCHAR(10);
    v_doi_khach VARCHAR(10);
    v_ngay_gio TIMESTAMP;
    v_doi_chu_quan VARCHAR(10);
    v_doi_hien_tai VARCHAR(10);
    v_so_chinh_thuc INT;
    v_so_du_bi INT;
    v_tong_dang_ky INT;
    v_the_do_gan_nhat INT;
    v_the_vang_gan_nhat INT;
    v_tong_the_vang_tich_luy INT;
    v_ma_tran_truoc VARCHAR(10);
BEGIN
    -- Khóa bản ghi trận đấu cha để ngăn chặn điều kiện tranh chấp (Race Condition)
    SELECT MaVong, MaDoiNha, MaDoiKhach, NgayGio
    INTO v_ma_vong, v_doi_nha, v_doi_khach, v_ngay_gio
    FROM TRAN_DAU_CHUYEN_MON
    WHERE MaTran = NEW.MaTran
    FOR NO KEY UPDATE;

    -- 1. Kiểm tra đội bóng có tham gia trận đấu này không
    IF NEW.MaDoi NOT IN (v_doi_nha, v_doi_khach) THEN
        RAISE EXCEPTION 'Lỗi nghiệp vụ: Đội bóng % không tham gia trận đấu %!',
            NEW.MaDoi, NEW.MaTran;
    END IF;

    -- 2. Kiểm tra cầu thủ có hợp đồng còn hiệu lực tại ngày diễn ra trận đấu
    SELECT MaDoiChuQuan, MaDoiHienTai INTO v_doi_chu_quan, v_doi_hien_tai
    FROM HOP_DONG_CAU_THU
    WHERE MaCauThu = NEW.MaCauThu
      AND MaDoiHienTai = NEW.MaDoi
      AND TrangThai IN ('ChinhThuc', 'ChoMuon')
      AND v_ngay_gio::DATE BETWEEN NgayBatDau AND NgayKetThuc
    LIMIT 1;

    IF v_doi_hien_tai IS NULL THEN
        RAISE EXCEPTION 'Lỗi nghiệp vụ: Cầu thủ % không có hợp đồng hiệu lực tại đội % vào ngày diễn ra trận đấu (%)!',
            NEW.MaCauThu, NEW.MaDoi, v_ngay_gio::DATE;
    END IF;

    -- 3. Điều khoản mượn cầu thủ: Cầu thủ cho mượn không được đối đầu đội bóng chủ quản
    IF v_doi_chu_quan <> v_doi_hien_tai AND v_doi_chu_quan IN (v_doi_nha, v_doi_khach) THEN
        RAISE EXCEPTION 'Lỗi nghiệp vụ: Cầu thủ % đang được cho mượn từ %, không được phép thi đấu đối đầu đội chủ quản!',
            NEW.MaCauThu, v_doi_chu_quan;
    END IF;

    -- 4. Kiểm tra giới hạn đăng ký: Tối đa 18 cầu thủ, 11 đá chính, tối đa 7 dự bị (11 + 7 = 18)
    SELECT
        COUNT(*) FILTER (WHERE VaiTroThiDau = 'ChinhThuc'),
        COUNT(*) FILTER (WHERE VaiTroThiDau = 'DuBi'),
        COUNT(*)
    INTO v_so_chinh_thuc, v_so_du_bi, v_tong_dang_ky
    FROM DANG_KY_THI_DAU
    WHERE MaTran = NEW.MaTran
      AND MaDoi = NEW.MaDoi
      AND MaCauThu <> NEW.MaCauThu;

    IF v_tong_dang_ky >= 18 THEN
        RAISE EXCEPTION 'Lỗi nghiệp vụ: Đội % đã đăng ký đủ tối đa 18 cầu thủ cho trận đấu %!',
            NEW.MaDoi, NEW.MaTran;
    END IF;

    IF NEW.VaiTroThiDau = 'ChinhThuc' AND v_so_chinh_thuc >= 11 THEN
        RAISE EXCEPTION 'Lỗi nghiệp vụ: Đội % đã đủ 11 cầu thủ đá chính cho trận đấu %!',
            NEW.MaDoi, NEW.MaTran;
    END IF;

    IF NEW.VaiTroThiDau = 'DuBi' AND v_so_du_bi >= 7 THEN
        RAISE EXCEPTION 'Lỗi nghiệp vụ: Đội % đã có đủ tối đa 7 cầu thủ dự bị (tổng tối đa 18)!',
            NEW.MaDoi;
    END IF;

    -- 5. Kiểm tra án treo giò: Xét trận đấu liền trước của đội bóng này (trong phạm vi mảnh trạm)
    SELECT MaTran INTO v_ma_tran_truoc
    FROM TRAN_DAU_CHUYEN_MON
    WHERE (MaDoiNha = NEW.MaDoi OR MaDoiKhach = NEW.MaDoi)
      AND NgayGio < v_ngay_gio
      AND TrangThai = 'DaKetThuc'
    ORDER BY NgayGio DESC
    LIMIT 1;

    IF v_ma_tran_truoc IS NOT NULL THEN
        -- Kiểm tra thẻ đỏ trực tiếp ở trận trước
        SELECT COUNT(*) INTO v_the_do_gan_nhat
        FROM SU_KIEN_TRAN_DAU
        WHERE MaTran = v_ma_tran_truoc
          AND MaCauThu = NEW.MaCauThu
          AND LoaiSuKien = 'TheDo';

        -- Kiểm tra số thẻ vàng nhận trong trận trước
        SELECT COUNT(*) INTO v_the_vang_gan_nhat
        FROM SU_KIEN_TRAN_DAU
        WHERE MaTran = v_ma_tran_truoc
          AND MaCauThu = NEW.MaCauThu
          AND LoaiSuKien = 'TheVang';

        -- Trường hợp 1: Nhận thẻ đỏ trực tiếp hoặc 2 thẻ vàng trong cùng trận trước (= thẻ đỏ gián tiếp)
        IF v_the_do_gan_nhat > 0 OR v_the_vang_gan_nhat >= 2 THEN
            RAISE EXCEPTION 'Lỗi nghiệp vụ: Cầu thủ % đang thụ án treo giò do nhận thẻ đỏ ở trận đấu liền trước (%)!',
                NEW.MaCauThu, v_ma_tran_truoc;
        END IF;

        -- Trường hợp 2: Nhận thẻ vàng ở trận trước và hoàn tất tích lũy đủ bội số 2 thẻ vàng (thẻ thứ 2, 4...)
        IF v_the_vang_gan_nhat = 1 THEN
            SELECT COUNT(*) INTO v_tong_the_vang_tich_luy
            FROM SU_KIEN_TRAN_DAU sk
            JOIN TRAN_DAU_CHUYEN_MON td ON sk.MaTran = td.MaTran
            WHERE sk.MaCauThu = NEW.MaCauThu
              AND sk.LoaiSuKien = 'TheVang'
              AND td.NgayGio <= (SELECT NgayGio FROM TRAN_DAU_CHUYEN_MON WHERE MaTran = v_ma_tran_truoc);

            IF (v_tong_the_vang_tich_luy % 2) = 0 THEN
                RAISE EXCEPTION 'Lỗi nghiệp vụ: Cầu thủ % đang thụ án treo giò do đã tích lũy đủ % thẻ vàng!',
                    NEW.MaCauThu, v_tong_the_vang_tich_luy;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_dang_ky_thi_dau_va_treo_gio ON DANG_KY_THI_DAU;
CREATE TRIGGER trg_check_dang_ky_thi_dau_va_treo_gio
BEFORE INSERT OR UPDATE OF MaTran, MaCauThu, MaDoi, VaiTroThiDau
ON DANG_KY_THI_DAU
FOR EACH ROW
EXECUTE FUNCTION fn_check_dang_ky_thi_dau_va_treo_gio();


-- ----------------------------------------------------------------------------
-- TRIGGER 4: MỘT TRỌNG TÀI CHỈ ĐIỀU KHIỂN TỐI ĐA 1 TRẬN TRONG MỖI VÒNG ĐẤU
-- Bảng áp dụng: PHAN_CONG_TRONG_TAI
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_phan_cong_trong_tai()
RETURNS TRIGGER AS $$
DECLARE
    v_ma_vong INT;
    v_trung_vong INT;
BEGIN
    -- Lấy mã vòng đấu của trận hiện tại
    SELECT MaVong INTO v_ma_vong
    FROM TRAN_DAU_CHUYEN_MON
    WHERE MaTran = NEW.MaTran;

    -- Khóa bản ghi trọng tài để tuần tự hóa các giao dịch phân công
    PERFORM 1 FROM TRONG_TAI WHERE MaTrongTai = NEW.MaTrongTai FOR NO KEY UPDATE;

    -- Kiểm tra xem trọng tài đã có nhiệm vụ trong bất kỳ trận nào thuộc vòng này chưa
    SELECT COUNT(*) INTO v_trung_vong
    FROM PHAN_CONG_TRONG_TAI pc
    JOIN TRAN_DAU_CHUYEN_MON td ON pc.MaTran = td.MaTran
    WHERE pc.MaTrongTai = NEW.MaTrongTai
      AND td.MaVong = v_ma_vong
      AND td.MaTran <> NEW.MaTran;

    IF v_trung_vong > 0 THEN
        RAISE EXCEPTION 'Lỗi nghiệp vụ: Trọng tài % đã được phân công làm nhiệm vụ tại trận khác trong vòng %!',
            NEW.MaTrongTai, v_ma_vong;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_phan_cong_trong_tai ON PHAN_CONG_TRONG_TAI;
CREATE TRIGGER trg_check_phan_cong_trong_tai
BEFORE INSERT OR UPDATE OF MaTrongTai, MaTran
ON PHAN_CONG_TRONG_TAI
FOR EACH ROW
EXECUTE FUNCTION fn_check_phan_cong_trong_tai();


-- ----------------------------------------------------------------------------
-- TRIGGER 5: ĐỐI SOÁT TỔ TRỌNG TÀI, TỔNG BÀN THẮNG (KỂ CẢ PHẢN LƯỚI) VÀ THẺ PHẠT
-- Bảng áp dụng: TRAN_DAU_CHUYEN_MON
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_khop_ban_thang_va_the()
RETURNS TRIGGER AS $$
DECLARE
    v_so_trong_tai INT;
    v_ban_nha INT;
    v_ban_khach INT;
    v_the_vang_nha INT;
    v_the_vang_khach INT;
    v_the_do_nha INT;
    v_the_do_khach INT;
BEGIN
    IF NEW.TrangThai = 'DaKetThuc' THEN
        -- 1. Kiểm tra đủ tổ 4 trọng tài
        SELECT COUNT(*) INTO v_so_trong_tai
        FROM PHAN_CONG_TRONG_TAI
        WHERE MaTran = NEW.MaTran;

        IF v_so_trong_tai <> 4 THEN
            RAISE EXCEPTION 'Lỗi nghiệp vụ: Trận đấu % phải có đủ 4 trọng tài làm nhiệm vụ trước khi kết thúc (hiện có %)!',
                NEW.MaTran, v_so_trong_tai;
        END IF;

        -- 2. Đếm tổng hợp sự kiện:
        -- Bàn thắng Đội Nhà = (Cầu thủ nhà ghi BanThang) + (Cầu thủ khách ghi PhanLuoi)
        -- Bàn thắng Đội Khách = (Cầu thủ khách ghi BanThang) + (Cầu thủ nhà ghi PhanLuoi)
        SELECT
            COUNT(*) FILTER (WHERE (dk.MaDoi = NEW.MaDoiNha AND sk.LoaiSuKien = 'BanThang')
                                OR (dk.MaDoi = NEW.MaDoiKhach AND sk.LoaiSuKien = 'PhanLuoi')),
            COUNT(*) FILTER (WHERE (dk.MaDoi = NEW.MaDoiKhach AND sk.LoaiSuKien = 'BanThang')
                                OR (dk.MaDoi = NEW.MaDoiNha AND sk.LoaiSuKien = 'PhanLuoi')),
            COUNT(*) FILTER (WHERE dk.MaDoi = NEW.MaDoiNha AND sk.LoaiSuKien = 'TheVang'),
            COUNT(*) FILTER (WHERE dk.MaDoi = NEW.MaDoiKhach AND sk.LoaiSuKien = 'TheVang'),
            COUNT(*) FILTER (WHERE dk.MaDoi = NEW.MaDoiNha AND sk.LoaiSuKien = 'TheDo'),
            COUNT(*) FILTER (WHERE dk.MaDoi = NEW.MaDoiKhach AND sk.LoaiSuKien = 'TheDo')
        INTO
            v_ban_nha, v_ban_khach,
            v_the_vang_nha, v_the_vang_khach,
            v_the_do_nha, v_the_do_khach
        FROM SU_KIEN_TRAN_DAU sk
        JOIN DANG_KY_THI_DAU dk ON sk.MaTran = dk.MaTran AND sk.MaCauThu = dk.MaCauThu
        WHERE sk.MaTran = NEW.MaTran;

        -- Đối soát bàn thắng
        IF v_ban_nha <> NEW.BanThangNha OR v_ban_khach <> NEW.BanThangKhach THEN
            RAISE EXCEPTION 'Lỗi toàn vẹn dữ liệu: Số bàn thắng trong sự kiện (Nhà: %, Khách: %) không khớp tỉ số trận % (Nhà: %, Khách: %)!',
                v_ban_nha, v_ban_khach, NEW.MaTran, NEW.BanThangNha, NEW.BanThangKhach;
        END IF;

        -- Đối soát thẻ vàng
        IF v_the_vang_nha <> NEW.TheVangNha OR v_the_vang_khach <> NEW.TheVangKhach THEN
            RAISE EXCEPTION 'Lỗi toàn vẹn dữ liệu: Số thẻ vàng trong sự kiện (Nhà: %, Khách: %) không khớp thống kê trận % (Nhà: %, Khách: %)!',
                v_the_vang_nha, v_the_vang_khach, NEW.MaTran, NEW.TheVangNha, NEW.TheVangKhach;
        END IF;

        -- Đối soát thẻ đỏ
        IF v_the_do_nha <> NEW.TheDoNha OR v_the_do_khach <> NEW.TheDoKhach THEN
            RAISE EXCEPTION 'Lỗi toàn vẹn dữ liệu: Số thẻ đỏ trong sự kiện (Nhà: %, Khách: %) không khớp thống kê trận % (Nhà: %, Khách: %)!',
                v_the_do_nha, v_the_do_khach, NEW.MaTran, NEW.TheDoNha, NEW.TheDoKhach;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_khop_ban_thang_va_the ON TRAN_DAU_CHUYEN_MON;
CREATE TRIGGER trg_check_khop_ban_thang_va_the
AFTER INSERT OR UPDATE OF TrangThai, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach
ON TRAN_DAU_CHUYEN_MON
FOR EACH ROW
EXECUTE FUNCTION fn_check_khop_ban_thang_va_the();


-- ----------------------------------------------------------------------------
-- TRIGGER BỔ TRỢ: BẢO VỆ DỮ LIỆU SỰ KIỆN KHI TRẬN ĐẤU ĐÃ KẾT THÚC
-- Bảng áp dụng: SU_KIEN_TRAN_DAU
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevent_modify_finished_events()
RETURNS TRIGGER AS $$
DECLARE
    v_target_tran VARCHAR(10);
    v_trang_thai VARCHAR(20);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_target_tran := OLD.MaTran;
    ELSE
        v_target_tran := NEW.MaTran;
    END IF;

    SELECT TrangThai INTO v_trang_thai
    FROM TRAN_DAU_CHUYEN_MON
    WHERE MaTran = v_target_tran;

    IF v_trang_thai = 'DaKetThuc' THEN
        RAISE EXCEPTION 'Lỗi an toàn: Trận đấu % đã kết thúc (DaKetThuc), không được phép thêm/sửa/xóa sự kiện diễn biến!',
            v_target_tran;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_modify_finished_events ON SU_KIEN_TRAN_DAU;
CREATE TRIGGER trg_prevent_modify_finished_events
BEFORE INSERT OR UPDATE OR DELETE
ON SU_KIEN_TRAN_DAU
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_modify_finished_events();
-- ============================================================================
-- PHẦN 3: 5 STORED PROCEDURE (bản trạm - thích ứng TRAN_DAU -> TRAN_DAU_CHUYEN_MON)
-- Khác biệt so với bản tập trung (db/centralized/03_transactions_procedures.sql):
--   - sp_tao_lich_thi_dau: bỏ tham số p_gia_ve + cột GiaVe/SoKhach (không có ở trạm)
--   - sp_ghi_nhan_ket_qua_tran_dau: bỏ tham số p_so_khach + cột SoKhach
--   - sp_phan_cong_to_trong_tai, sp_dang_ky_cau_thu_tran: tham chiếu TRAN_DAU_CHUYEN_MON
--   - sp_chuyen_nhuong_cho_muon_cau_thu: giữ nguyên (chỉ dùng bảng danh mục)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- GIAO DỊCH 1: KHỞI TẠO LỊCH THI ĐẤU CHO MỘT TRẬN ĐẤU THUỘC VÒNG ĐẤU
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tao_lich_thi_dau(
    p_ma_tran VARCHAR(10),
    p_ma_vong INT,
    p_ma_doi_nha VARCHAR(10),
    p_ma_doi_khach VARCHAR(10),
    p_ma_san VARCHAR(10),
    p_ngay_gio TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_da_ton_tai INT;
    v_trung_lich_san INT;
BEGIN
    -- 1. Kiểm tra hai đội không được trùng nhau
    IF p_ma_doi_nha = p_ma_doi_khach THEN
        RAISE EXCEPTION 'Lỗi giao dịch: Đội chủ nhà (%) và đội khách (%) không được trùng nhau!',
            p_ma_doi_nha, p_ma_doi_khach;
    END IF;

    -- Khóa bản ghi sân vận động cha (Row-level lock) để tuần tự hóa việc xếp lịch đồng thời
    PERFORM 1 FROM SAN_VAN_DONG WHERE MaSan = p_ma_san FOR NO KEY UPDATE;

    -- 2. Kiểm tra thể thức vòng tròn: Cặp đấu này trên sân nhà này đã tồn tại chưa
    SELECT COUNT(*) INTO v_da_ton_tai
    FROM TRAN_DAU_CHUYEN_MON
    WHERE MaDoiNha = p_ma_doi_nha AND MaDoiKhach = p_ma_doi_khach;

    IF v_da_ton_tai > 0 THEN
        RAISE EXCEPTION 'Lỗi giao dịch: Trận đấu giữa % (sân nhà) và % (sân khách) đã được xếp lịch trước đó!',
            p_ma_doi_nha, p_ma_doi_khach;
    END IF;

    -- 3. Kiểm tra sân vận động không bị trùng giờ thi đấu (cách nhau tối thiểu 4 giờ)
    SELECT COUNT(*) INTO v_trung_lich_san
    FROM TRAN_DAU_CHUYEN_MON
    WHERE MaSan = p_ma_san
      AND NgayGio > p_ngay_gio - INTERVAL '4 hours'
      AND NgayGio < p_ngay_gio + INTERVAL '4 hours';

    IF v_trung_lich_san > 0 THEN
        RAISE EXCEPTION 'Lỗi giao dịch: Sân vận động % đã có trận đấu diễn ra trong khoảng thời gian 4 giờ lân cận!',
            p_ma_san;
    END IF;

    -- 4. Thực hiện thêm trận đấu mới
    INSERT INTO TRAN_DAU_CHUYEN_MON (
        MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan,
        NgayGio, BanThangNha, BanThangKhach,
        TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai
    ) VALUES (
        p_ma_tran, p_ma_vong, p_ma_doi_nha, p_ma_doi_khach, p_ma_san,
        p_ngay_gio, 0, 0, 0, 0, 0, 0, 'ChuaDienRa'
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- GIAO DỊCH 2: PHÂN CÔNG ĐỦ TỔ 4 TRỌNG TÀI CHO MỘT TRẬN ĐẤU
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_phan_cong_to_trong_tai(
    p_ma_tran VARCHAR(10),
    p_tt_chinh VARCHAR(10),
    p_tt_bien1 VARCHAR(10),
    p_tt_bien2 VARCHAR(10),
    p_tt_ban VARCHAR(10)
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Kiểm tra 4 trọng tài trong tổ phải hoàn toàn phân biệt
    IF p_tt_chinh IN (p_tt_bien1, p_tt_bien2, p_tt_ban) OR
       p_tt_bien1 IN (p_tt_bien2, p_tt_ban) OR
       p_tt_bien2 = p_tt_ban THEN
        RAISE EXCEPTION 'Lỗi giao dịch: Bốn trọng tài trong tổ phân công phải là các cá nhân phân biệt!';
    END IF;

    -- Khóa bản ghi trận đấu để đảm bảo tính cô lập khi cập nhật tổ trọng tài
    PERFORM 1 FROM TRAN_DAU_CHUYEN_MON WHERE MaTran = p_ma_tran FOR NO KEY UPDATE;

    -- 2. Xóa phân công cũ nếu có để gán lại toàn bộ tổ trọng tài
    DELETE FROM PHAN_CONG_TRONG_TAI WHERE MaTran = p_ma_tran;

    -- 3. Thêm 4 vị trí (Trigger trg_check_phan_cong_trong_tai sẽ tự động kiểm tra vòng đấu)
    INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
    (p_ma_tran, 'Chinh', p_tt_chinh),
    (p_ma_tran, 'Bien1', p_tt_bien1),
    (p_ma_tran, 'Bien2', p_tt_bien2),
    (p_ma_tran, 'Ban', p_tt_ban);
END;
$$;


-- ----------------------------------------------------------------------------
-- GIAO DỊCH 3: ĐĂNG KÝ DANH SÁCH CẦU THỦ THI ĐẤU CHO MỘT TRẬN ĐẤU
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_dang_ky_cau_thu_tran(
    p_ma_tran VARCHAR(10),
    p_ma_doi VARCHAR(10),
    p_ma_cau_thu VARCHAR(10),
    p_vai_tro_thi_dau VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_so_ao INT;
    v_ngay_gio TIMESTAMP;
BEGIN
    -- Lấy ngày giờ diễn ra trận đấu
    SELECT NgayGio INTO v_ngay_gio
    FROM TRAN_DAU_CHUYEN_MON
    WHERE MaTran = p_ma_tran;

    IF v_ngay_gio IS NULL THEN
        RAISE EXCEPTION 'Lỗi giao dịch: Không tìm thấy trận đấu %!', p_ma_tran;
    END IF;

    -- 1. Kiểm tra cầu thủ có hợp đồng còn hiệu lực tại ngày diễn ra trận đấu
    SELECT SoAo INTO v_so_ao
    FROM HOP_DONG_CAU_THU
    WHERE MaCauThu = p_ma_cau_thu
      AND MaDoiHienTai = p_ma_doi
      AND TrangThai IN ('ChinhThuc', 'ChoMuon')
      AND v_ngay_gio::DATE BETWEEN NgayBatDau AND NgayKetThuc;

    IF v_so_ao IS NULL THEN
        RAISE EXCEPTION 'Lỗi giao dịch: Cầu thủ % không có hợp đồng thi đấu hợp lệ tại đội bóng % vào ngày diễn ra trận đấu (%)!',
            p_ma_cau_thu, p_ma_doi, v_ngay_gio::DATE;
    END IF;

    -- 2. Thực hiện đăng ký (Trigger trg_check_dang_ky_thi_dau_va_treo_gio sẽ kiểm tra 11 chính, tối đa 7 dự bị và án treo giò)
    INSERT INTO DANG_KY_THI_DAU (MaTran, MaCauThu, MaDoi, VaiTroThiDau, SoAoDangKy)
    VALUES (p_ma_tran, p_ma_cau_thu, p_ma_doi, p_vai_tro_thi_dau, v_so_ao);
END;
$$;


-- ----------------------------------------------------------------------------
-- GIAO DỊCH 4: GHI NHẬN KẾT QUẢ VÀ SỰ KIỆN TRẬN ĐẤU (HOÀN TẤT TRẬN)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_ghi_nhan_ket_qua_tran_dau(
    p_ma_tran VARCHAR(10),
    p_ban_nha INT,
    p_ban_khach INT,
    p_the_vang_nha INT,
    p_the_vang_khach INT,
    p_the_do_nha INT,
    p_the_do_khach INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_trang_thai VARCHAR(20);
    v_ngay_gio TIMESTAMP;
BEGIN
    -- 1. Lấy thông tin trận đấu và khóa độc quyền dòng dữ liệu trận đấu (FOR UPDATE)
    SELECT TrangThai, NgayGio INTO v_trang_thai, v_ngay_gio
    FROM TRAN_DAU_CHUYEN_MON
    WHERE MaTran = p_ma_tran
    FOR UPDATE;

    IF v_trang_thai IS NULL THEN
        RAISE EXCEPTION 'Lỗi giao dịch: Không tìm thấy trận đấu có mã %!', p_ma_tran;
    END IF;

    -- 2. Kiểm tra ngày giờ thi đấu không được vượt quá thời gian hiện tại
    IF v_ngay_gio > CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'Lỗi giao dịch: Không thể kết thúc trận đấu chưa diễn ra (thời gian thi đấu ở tương lai)!';
    END IF;

    -- 3. Cập nhật kết quả chung cuộc và chuyển trạng thái
    -- (Trigger trg_check_khop_ban_thang_va_the sẽ kiểm tra tính khớp nối với các sự kiện đã ghi)
    UPDATE TRAN_DAU_CHUYEN_MON
    SET BanThangNha = p_ban_nha,
        BanThangKhach = p_ban_khach,
        TheVangNha = p_the_vang_nha,
        TheVangKhach = p_the_vang_khach,
        TheDoNha = p_the_do_nha,
        TheDoKhach = p_the_do_khach,
        TrangThai = 'DaKetThuc'
    WHERE MaTran = p_ma_tran;
END;
$$;


-- ----------------------------------------------------------------------------
-- GIAO DỊCH 5: CHUYỂN NHƯỢNG HOẶC CHO MƯỢN CẦU THỦ (giữ nguyên như tập trung)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_chuyen_nhuong_cho_muon_cau_thu(
    p_ma_hd_moi VARCHAR(10),
    p_ma_cau_thu VARCHAR(10),
    p_ma_doi_chu_quan VARCHAR(10),
    p_ma_doi_moi VARCHAR(10),
    p_so_ao_moi INT,
    p_ngay_bat_dau DATE,
    p_ngay_ket_thuc DATE,
    p_trang_thai VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Khóa bản ghi cầu thủ để ngăn chặn hai giao dịch chuyển nhượng đồng thời cho cùng 1 cầu thủ
    PERFORM 1 FROM CAU_THU WHERE MaCauThu = p_ma_cau_thu FOR NO KEY UPDATE;
    PERFORM 1 FROM DOI_BONG WHERE MaDoi = p_ma_doi_moi FOR NO KEY UPDATE;

    -- 1. Xử lý hợp đồng cũ đang có hiệu lực của cầu thủ
    IF p_trang_thai = 'ChoMuon' THEN
        UPDATE HOP_DONG_CAU_THU
        SET TrangThai = 'TamDung'
        WHERE MaCauThu = p_ma_cau_thu
          AND TrangThai IN ('ChinhThuc', 'ChoMuon')
          AND NgayKetThuc >= p_ngay_bat_dau;
    ELSE
        UPDATE HOP_DONG_CAU_THU
        SET NgayKetThuc = p_ngay_bat_dau - INTERVAL '1 day',
            TrangThai = 'ThanhLy'
        WHERE MaCauThu = p_ma_cau_thu
          AND TrangThai IN ('ChinhThuc', 'ChoMuon', 'TamDung')
          AND NgayKetThuc >= p_ngay_bat_dau;
    END IF;

    -- 2. Thêm bản ghi hợp đồng mới cho cầu thủ tại đội bóng mới
    INSERT INTO HOP_DONG_CAU_THU (
        MaHD, MaCauThu, MaDoiChuQuan, MaDoiHienTai,
        SoAo, NgayBatDau, NgayKetThuc, TrangThai
    ) VALUES (
        p_ma_hd_moi, p_ma_cau_thu, p_ma_doi_chu_quan, p_ma_doi_moi,
        p_so_ao_moi, p_ngay_bat_dau, p_ngay_ket_thuc, p_trang_thai
    );
END;
$$;
-- ============================================================================
-- PHẦN 5: DỮ LIỆU 7 BẢNG DANH MỤC (đủ data - dùng chung cho mọi trạm)
-- Thứ tự nạp đúng BTL: sân -> đội -> màu áo -> trọng tài -> cầu thủ + hợp đồng -> vòng
-- ============================================================================
-- ----------------------------------------------------------------------------
-- 1. NẠP DỮ LIỆU SÂN VẬN ĐỘNG
-- Lưu ý: Sân Hàng Đẫy (SAN_HD) là sân nhà của cả 2 đội: HNFC và CAHN.
-- ----------------------------------------------------------------------------
INSERT INTO SAN_VAN_DONG (MaSan, TenSan, DiaChi, SucChua, KhuVuc) VALUES
('SAN_HD', 'Sân vận động Hàng Đẫy', 'Trịnh Hoài Đức, Đống Đa, Hà Nội', 22500, 'MienBac'),
('SAN_MD', 'Sân vận động Quốc gia Mỹ Đình', 'Lê Đức Thọ, Nam Từ Liêm, Hà Nội', 40192, 'MienBac'),
('SAN_LT', 'Sân vận động Lạch Tray', 'Lạch Tray, Ngô Quyền, Hải Phòng', 30000, 'MienBac'),
('SAN_TT', 'Sân vận động Thiên Trường', 'Đặng Xuân Thiều, TP Nam Định', 30000, 'MienBac'),
('SAN_PK', 'Sân vận động Pleiku', 'Quang Trung, TP Pleiku, Gia Lai', 12000, 'MienNam');

-- ----------------------------------------------------------------------------
-- 2. NẠP DỮ LIỆU ĐỘI BÓNG
-- ----------------------------------------------------------------------------
INSERT INTO DOI_BONG (MaDoi, TenDoi, HLV, MaSanNha) VALUES
('HNFC', 'Hà Nội FC', 'Daiki Iwamasa', 'SAN_HD'),
('CAHN', 'Công An Hà Nội', 'Alexandre Polking', 'SAN_HD'),
('VTT',  'Thể Công Viettel', 'Nguyễn Đức Thắng', 'SAN_MD'),
('HPFC', 'Hải Phòng FC', 'Chu Đình Nghiêm', 'SAN_LT'),
('NDFC', 'Thép Xanh Nam Định', 'Vũ Hồng Việt', 'SAN_TT'),
('HAGL', 'Hoàng Anh Gia Lai', 'Vũ Tiến Thành', 'SAN_PK');

-- ----------------------------------------------------------------------------
-- 3. NẠP DỮ LIỆU MÀU ÁO ĐỘI BÓNG (Mỗi đội có ít nhất 2 màu áo)
-- ----------------------------------------------------------------------------
INSERT INTO MAU_AO_DOI_BONG (MaDoi, LoaiMauAo, MoTaMau) VALUES
('HNFC', 'SanNha', 'Tím truyền thống'),
('HNFC', 'SanKhach', 'Vàng viền tím'),
('HNFC', 'Phu', 'Trắng tinh khôi'),

('CAHN', 'SanNha', 'Đỏ cờ'),
('CAHN', 'SanKhach', 'Trắng viền đỏ'),

('VTT',  'SanNha', 'Đỏ rực'),
('VTT',  'SanKhach', 'Trắng quân đội'),

('HPFC', 'SanNha', 'Đỏ hoa phượng'),
('HPFC', 'SanKhach', 'Trắng viền đỏ'),

('NDFC', 'SanNha', 'Vàng rực rỡ'),
('NDFC', 'SanKhach', 'Trắng phối xanh'),

('HAGL', 'SanNha', 'Trắng phố núi'),
('HAGL', 'SanKhach', 'Xanh lục đậm');

-- ----------------------------------------------------------------------------
-- 4. NẠP DỮ LIỆU TRỌNG TÀI (12 Trọng tài đảm bảo đủ 3 trận x 4 TT / vòng)
-- ----------------------------------------------------------------------------
INSERT INTO TRONG_TAI (MaTrongTai, HoTen, NgaySinh, QueQuan, CapBac) VALUES
('TT01', 'Ngô Duy Lân', '1984-06-12', 'Long An', 'FIFA Elite'),
('TT02', 'Hoàng Ngọc Hà', '1983-09-24', 'Hà Nội', 'FIFA'),
('TT03', 'Trần Đình Thịnh', '1982-03-15', 'Đồng Nai', 'FIFA'),
('TT04', 'Lê Vũ Linh', '1989-11-20', 'Cần Thơ', 'FIFA'),
('TT05', 'Nguyễn Viết Duẩn', '1985-07-08', 'Hà Nội', 'Quốc gia'),
('TT06', 'Mai Xuân Hùng', '1987-12-03', 'Đà Nẵng', 'Quốc gia'),
('TT07', 'Nguyễn Mạnh Hải', '1987-05-18', 'Hải Phòng', 'FIFA'),
('TT08', 'Trần Ngọc Nhớ', '1988-02-14', 'Tiền Giang', 'Quốc gia'),
('TT09', 'Phạm Hoài Tâm', '1986-10-30', 'TP Hồ Chí Minh', 'Quốc gia'),
('TT10', 'Nguyễn Trung Hậu', '1981-04-22', 'Đà Nẵng', 'FIFA Trợ lý'),
('TT11', 'Phạm Mạnh Long', '1980-08-11', 'Hải Phòng', 'FIFA Trợ lý'),
('TT12', 'Trần Duy Khánh', '1990-01-05', 'Nghệ An', 'Quốc gia');

-- ----------------------------------------------------------------------------
-- 5. NẠP DỮ LIỆU CẦU THỦ VÀ HỢP ĐỒNG (6 đội x 18 cầu thủ = 108 cầu thủ)
-- ----------------------------------------------------------------------------
-- (1) HÀ NỘI FC (HNFC) - 18 cầu thủ (Số áo từ 1 đến 35, phân biệt)
INSERT INTO CAU_THU (MaCauThu, HoTen, NgaySinh, ViTri, QuocTich) VALUES
('CT001', 'Bùi Tấn Trường', '1986-02-19', 'ThuMon', 'Việt Nam'),
('CT002', 'Đỗ Duy Mạnh', '1996-09-29', 'HauVe', 'Việt Nam'),
('CT003', 'Nguyễn Thành Chung', '1997-11-29', 'HauVe', 'Việt Nam'),
('CT004', 'Phạm Xuân Mạnh', '1996-03-27', 'HauVe', 'Việt Nam'),
('CT005', 'Vũ Đình Hai', '2000-01-13', 'TienVe', 'Việt Nam'),
('CT006', 'Đỗ Hùng Dũng', '1993-09-08', 'TienVe', 'Việt Nam'),
('CT007', 'Nguyễn Văn Quyết', '1991-07-01', 'TienDao', 'Việt Nam'),
('CT008', 'Phạm Tuấn Hải', '1998-05-19', 'TienDao', 'Việt Nam'),
('CT009', 'Lê Văn Xuân', '1999-02-27', 'HauVe', 'Việt Nam'),
('CT010', 'Nguyễn Văn Tùng', '2001-06-02', 'TienDao', 'Việt Nam'),
('CT011', 'Quan Văn Chuẩn', '2001-01-07', 'ThuMon', 'Việt Nam'),
('CT012', 'Đậu Văn Toàn', '1997-04-07', 'TienVe', 'Việt Nam'),
('CT013', 'Nguyễn Hai Long', '2000-08-27', 'TienVe', 'Việt Nam'),
('CT014', 'Trần Văn Kiên', '1996-05-13', 'HauVe', 'Việt Nam'),
('CT015', 'Joel Tagueu', '1993-11-06', 'TienDao', 'Cameroon'),
('CT016', 'Deni Junior', '1995-07-10', 'TienDao', 'Brazil'),
('CT017', 'Tim Hall', '1997-06-09', 'HauVe', 'Luxembourg'),
('CT018', 'Nguyễn Đức Anh', '2003-05-16', 'HauVe', 'Việt Nam');

INSERT INTO HOP_DONG_CAU_THU (MaHD, MaCauThu, MaDoiChuQuan, MaDoiHienTai, SoAo, NgayBatDau, NgayKetThuc, TrangThai) VALUES
('HD001', 'CT001', 'HNFC', 'HNFC', 1,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD002', 'CT002', 'HNFC', 'HNFC', 2,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD003', 'CT003', 'HNFC', 'HNFC', 16, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD004', 'CT004', 'HNFC', 'HNFC', 7,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD005', 'CT005', 'HNFC', 'HNFC', 21, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD006', 'CT006', 'HNFC', 'HNFC', 6,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD007', 'CT007', 'HNFC', 'HNFC', 10, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD008', 'CT008', 'HNFC', 'HNFC', 9,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD009', 'CT009', 'HNFC', 'HNFC', 5,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD010', 'CT010', 'HNFC', 'HNFC', 11, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD011', 'CT011', 'HNFC', 'HNFC', 25, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD012', 'CT012', 'HNFC', 'HNFC', 8,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD013', 'CT013', 'HNFC', 'HNFC', 14, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD014', 'CT014', 'HNFC', 'HNFC', 13, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD015', 'CT015', 'HNFC', 'HNFC', 15, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD016', 'CT016', 'HNFC', 'HNFC', 17, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD017', 'CT017', 'HNFC', 'HNFC', 4,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD018', 'CT018', 'HNFC', 'HNFC', 28, '2025-01-01', '2027-12-31', 'ChinhThuc');

-- (2) CÔNG AN HÀ NỘI (CAHN) - 18 cầu thủ
INSERT INTO CAU_THU (MaCauThu, HoTen, NgaySinh, ViTri, QuocTich) VALUES
('CT019', 'Filip Nguyễn', '1992-09-14', 'ThuMon', 'Việt Nam'),
('CT020', 'Hồ Tấn Tài', '1997-11-06', 'HauVe', 'Việt Nam'),
('CT021', 'Bùi Hoàng Việt Anh', '1999-01-01', 'HauVe', 'Việt Nam'),
('CT022', 'Đoàn Văn Hậu', '1999-04-19', 'HauVe', 'Việt Nam'),
('CT023', 'Vũ Văn Thanh', '1996-04-14', 'HauVe', 'Việt Nam'),
('CT024', 'Nguyễn Quang Hải', '1997-04-12', 'TienVe', 'Việt Nam'),
('CT025', 'Lê Phạm Thành Long', '1996-06-05', 'TienVe', 'Việt Nam'),
('CT026', 'Hoàng Văn Toản', '2001-04-01', 'TienVe', 'Việt Nam'),
('CT027', 'Phan Văn Đức', '1996-04-11', 'TienDao', 'Việt Nam'),
('CT028', 'Geovane Magno', '1994-04-14', 'TienDao', 'Brazil'),
('CT029', 'Jeferson Elias', '1998-08-18', 'TienDao', 'Brazil'),
('CT030', 'Bùi Tiến Dũng', '1997-02-28', 'ThuMon', 'Việt Nam'),
('CT031', 'Huỳnh Tấn Sinh', '1998-04-06', 'HauVe', 'Việt Nam'),
('CT032', 'Hà Văn Phương', '2001-05-28', 'TienVe', 'Việt Nam'),
('CT033', 'La Nguyễn Bảo Trung', '2002-03-12', 'TienVe', 'Việt Nam'),
('CT034', 'Phạm Gia Hưng', '2000-09-11', 'TienDao', 'Việt Nam'),
('CT035', 'Trần Đình Trọng', '1997-04-25', 'HauVe', 'Việt Nam'),
('CT036', 'Junior Fialho', '1998-10-21', 'TienDao', 'Brazil');

INSERT INTO HOP_DONG_CAU_THU (MaHD, MaCauThu, MaDoiChuQuan, MaDoiHienTai, SoAo, NgayBatDau, NgayKetThuc, TrangThai) VALUES
('HD019', 'CT019', 'CAHN', 'CAHN', 1,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD020', 'CT020', 'CAHN', 'CAHN', 4,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD021', 'CT021', 'CAHN', 'CAHN', 2,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD022', 'CT022', 'CAHN', 'CAHN', 5,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD023', 'CT023', 'CAHN', 'CAHN', 17, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD024', 'CT024', 'CAHN', 'CAHN', 19, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD025', 'CT025', 'CAHN', 'CAHN', 11, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD026', 'CT026', 'CAHN', 'CAHN', 12, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD027', 'CT027', 'CAHN', 'CAHN', 20, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD028', 'CT028', 'CAHN', 'CAHN', 10, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD029', 'CT029', 'CAHN', 'CAHN', 9,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD030', 'CT030', 'CAHN', 'CAHN', 25, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD031', 'CT031', 'CAHN', 'CAHN', 3,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD032', 'CT032', 'CAHN', 'CAHN', 7,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD033', 'CT033', 'CAHN', 'CAHN', 8,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD034', 'CT034', 'CAHN', 'CAHN', 14, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD035', 'CT035', 'CAHN', 'CAHN', 21, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD036', 'CT036', 'CAHN', 'CAHN', 30, '2025-01-01', '2027-12-31', 'ChinhThuc');

-- (3) THỂ CÔNG VIETTEL (VTT) - 18 cầu thủ
INSERT INTO CAU_THU (MaCauThu, HoTen, NgaySinh, ViTri, QuocTich) VALUES
('CT037', 'Trần Nguyên Mạnh', '1991-12-20', 'ThuMon', 'Việt Nam'),
('CT038', 'Bùi Tiến Dũng', '1995-10-02', 'HauVe', 'Việt Nam'),
('CT039', 'Nguyễn Thanh Bình', '2000-11-02', 'HauVe', 'Việt Nam'),
('CT040', 'Phan Tuấn Tài', '2001-01-07', 'HauVe', 'Việt Nam'),
('CT041', 'Trương Tiến Anh', '1999-04-25', 'TienVe', 'Việt Nam'),
('CT042', 'Nguyễn Hoàng Đức', '1998-01-11', 'TienVe', 'Việt Nam'),
('CT043', 'Nguyễn Đức Chiến', '1998-08-24', 'TienVe', 'Việt Nam'),
('CT044', 'Khuất Văn Khang', '2003-05-11', 'TienVe', 'Việt Nam'),
('CT045', 'Nhâm Mạnh Dũng', '2000-04-12', 'TienDao', 'Việt Nam'),
('CT046', 'Pedro Henrique', '1996-12-17', 'TienDao', 'Brazil'),
('CT047', 'Jaha', '1993-04-06', 'TienVe', 'Kosovo'),
('CT048', 'Quàng Thế Tài', '1995-02-05', 'ThuMon', 'Việt Nam'),
('CT049', 'Cao Trần Hoàng Hùng', '1999-03-03', 'HauVe', 'Việt Nam'),
('CT050', 'Nguyễn Huy Hùng', '1992-03-02', 'TienVe', 'Việt Nam'),
('CT051', 'Đinh Xuân Tiến', '2003-01-10', 'TienVe', 'Việt Nam'),
('CT052', 'Trần Danh Trung', '2000-10-03', 'TienDao', 'Việt Nam'),
('CT053', 'Dương Văn Hào', '1997-02-15', 'TienDao', 'Việt Nam'),
('CT054', 'Nguyễn Xuân Kiên', '2000-05-19', 'HauVe', 'Việt Nam');

INSERT INTO HOP_DONG_CAU_THU (MaHD, MaCauThu, MaDoiChuQuan, MaDoiHienTai, SoAo, NgayBatDau, NgayKetThuc, TrangThai) VALUES
('HD037', 'CT037', 'VTT', 'VTT', 1,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD038', 'CT038', 'VTT', 'VTT', 4,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD039', 'CT039', 'VTT', 'VTT', 3,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD040', 'CT040', 'VTT', 'VTT', 12, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD041', 'CT041', 'VTT', 'VTT', 8,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD042', 'CT042', 'VTT', 'VTT', 28, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD043', 'CT043', 'VTT', 'VTT', 21, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD044', 'CT044', 'VTT', 'VTT', 11, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD045', 'CT045', 'VTT', 'VTT', 23, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD046', 'CT046', 'VTT', 'VTT', 9,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD047', 'CT047', 'VTT', 'VTT', 7,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD048', 'CT048', 'VTT', 'VTT', 25, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD049', 'CT049', 'VTT', 'VTT', 5,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD050', 'CT050', 'VTT', 'VTT', 6,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD051', 'CT051', 'VTT', 'VTT', 10, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD052', 'CT052', 'VTT', 'VTT', 19, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD053', 'CT053', 'VTT', 'VTT', 17, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD054', 'CT054', 'VTT', 'VTT', 2,  '2025-01-01', '2027-12-31', 'ChinhThuc');

-- (4) THÉP XANH NAM ĐỊNH (NDFC) - 18 cầu thủ
INSERT INTO CAU_THU (MaCauThu, HoTen, NgaySinh, ViTri, QuocTich) VALUES
('CT055', 'Trần Liêm Điều', '2001-06-29', 'ThuMon', 'Việt Nam'),
('CT056', 'Dương Thanh Hào', '1991-06-23', 'HauVe', 'Việt Nam'),
('CT057', 'Trần Văn Kiên', '1996-05-13', 'HauVe', 'Việt Nam'),
('CT058', 'Nguyễn Phong Hồng Duy', '1996-06-13', 'HauVe', 'Việt Nam'),
('CT059', 'Lucas Alves', '1992-07-22', 'HauVe', 'Brazil'),
('CT060', 'Trần Văn Công', '1999-02-15', 'TienVe', 'Việt Nam'),
('CT061', 'Hendrio Araujo', '1994-05-16', 'TienVe', 'Brazil'),
('CT062', 'Nguyễn Tuấn Anh', '1995-05-16', 'TienVe', 'Việt Nam'),
('CT063', 'Nguyễn Văn Toàn', '1996-04-12', 'TienDao', 'Việt Nam'),
('CT064', 'Nguyễn Xuân Son', '1997-03-30', 'TienDao', 'Việt Nam'),
('CT065', 'Lâm Anh Quang', '1991-04-24', 'HauVe', 'Việt Nam'),
('CT066', 'Lê Vũ Quốc Nhật', '2001-01-19', 'ThuMon', 'Việt Nam'),
('CT067', 'Đinh Viết Tú', '1992-08-16', 'HauVe', 'Việt Nam'),
('CT068', 'Tô Văn Vũ', '1993-10-20', 'TienVe', 'Việt Nam'),
('CT069', 'Lý Công Hoàng Anh', '1999-09-01', 'TienVe', 'Việt Nam'),
('CT070', 'Mai Xuân Quyết', '1999-04-01', 'TienDao', 'Việt Nam'),
('CT071', 'Hoàng Minh Tuấn', '1995-08-17', 'TienDao', 'Việt Nam'),
('CT072', 'Đoàn Thanh Trường', '2000-09-08', 'TienVe', 'Việt Nam');

INSERT INTO HOP_DONG_CAU_THU (MaHD, MaCauThu, MaDoiChuQuan, MaDoiHienTai, SoAo, NgayBatDau, NgayKetThuc, TrangThai) VALUES
('HD055', 'CT055', 'NDFC', 'NDFC', 1,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD056', 'CT056', 'NDFC', 'NDFC', 3,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD057', 'CT057', 'NDFC', 'NDFC', 13, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD058', 'CT058', 'NDFC', 'NDFC', 7,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD059', 'CT059', 'NDFC', 'NDFC', 4,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD060', 'CT060', 'NDFC', 'NDFC', 16, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD061', 'CT061', 'NDFC', 'NDFC', 10, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD062', 'CT062', 'NDFC', 'NDFC', 21, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD063', 'CT063', 'NDFC', 'NDFC', 9,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD064', 'CT064', 'NDFC', 'NDFC', 14, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD065', 'CT065', 'NDFC', 'NDFC', 5,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD066', 'CT066', 'NDFC', 'NDFC', 25, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD067', 'CT067', 'NDFC', 'NDFC', 2,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD068', 'CT068', 'NDFC', 'NDFC', 28, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD069', 'CT069', 'NDFC', 'NDFC', 8,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD070', 'CT070', 'NDFC', 'NDFC', 11, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD071', 'CT071', 'NDFC', 'NDFC', 19, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD072', 'CT072', 'NDFC', 'NDFC', 18, '2025-01-01', '2027-12-31', 'ChinhThuc');

-- (5) HẢI PHÒNG FC (HPFC) - 18 cầu thủ
INSERT INTO CAU_THU (MaCauThu, HoTen, NgaySinh, ViTri, QuocTich) VALUES
('CT073', 'Nguyễn Đình Triệu', '1991-11-04', 'ThuMon', 'Việt Nam'),
('CT074', 'Đặng Văn Tới', '1999-01-12', 'HauVe', 'Việt Nam'),
('CT075', 'Bùi Tiến Dụng', '1998-11-23', 'HauVe', 'Việt Nam'),
('CT076', 'Phạm Trung Hiếu', '1998-09-22', 'HauVe', 'Việt Nam'),
('CT077', 'Nguyễn Văn Đạt', '1998-05-25', 'HauVe', 'Việt Nam'),
('CT078', 'Lương Xuân Trường', '1995-04-28', 'TienVe', 'Việt Nam'),
('CT079', 'Bicou Bissainthe', '1999-03-15', 'TienVe', 'Haiti'),
('CT080', 'Triệu Việt Hưng', '1997-01-19', 'TienVe', 'Việt Nam'),
('CT081', 'Nguyễn Hữu Sơn', '1996-09-27', 'TienDao', 'Việt Nam'),
('CT082', 'Lucao do Break', '1991-09-22', 'TienDao', 'Brazil'),
('CT083', 'Joseph Mpande', '1994-03-23', 'TienDao', 'Uganda'),
('CT084', 'Nguyễn Văn Toản', '1999-11-26', 'ThuMon', 'Việt Nam'),
('CT085', 'Nguyễn Nhật Minh', '2003-07-27', 'HauVe', 'Việt Nam'),
('CT086', 'Lê Mạnh Dũng', '1994-04-20', 'TienVe', 'Việt Nam'),
('CT087', 'Lương Hoàng Nam', '1997-03-02', 'TienVe', 'Việt Nam'),
('CT088', 'Nguyễn Tuấn Anh', '1999-08-16', 'TienDao', 'Việt Nam'),
('CT089', 'Dương Văn Khoa', '1994-05-06', 'HauVe', 'Việt Nam'),
('CT090', 'Nguyễn Minh Dĩ', '1998-02-17', 'TienDao', 'Việt Nam');

INSERT INTO HOP_DONG_CAU_THU (MaHD, MaCauThu, MaDoiChuQuan, MaDoiHienTai, SoAo, NgayBatDau, NgayKetThuc, TrangThai) VALUES
('HD073', 'CT073', 'HPFC', 'HPFC', 1,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD074', 'CT074', 'HPFC', 'HPFC', 5,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD075', 'CT075', 'HPFC', 'HPFC', 6,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD076', 'CT076', 'HPFC', 'HPFC', 17, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD077', 'CT077', 'HPFC', 'HPFC', 4,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD078', 'CT078', 'HPFC', 'HPFC', 8,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD079', 'CT079', 'HPFC', 'HPFC', 16, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD080', 'CT080', 'HPFC', 'HPFC', 20, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD081', 'CT081', 'HPFC', 'HPFC', 7,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD082', 'CT082', 'HPFC', 'HPFC', 9,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD083', 'CT083', 'HPFC', 'HPFC', 10, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD084', 'CT084', 'HPFC', 'HPFC', 25, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD085', 'CT085', 'HPFC', 'HPFC', 3,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD086', 'CT086', 'HPFC', 'HPFC', 14, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD087', 'CT087', 'HPFC', 'HPFC', 30, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD088', 'CT088', 'HPFC', 'HPFC', 19, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD089', 'CT089', 'HPFC', 'HPFC', 2,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD090', 'CT090', 'HPFC', 'HPFC', 11, '2025-01-01', '2027-12-31', 'ChinhThuc');

-- (6) HOÀNG ANH GIA LAI (HAGL) - 18 cầu thủ
INSERT INTO CAU_THU (MaCauThu, HoTen, NgaySinh, ViTri, QuocTich) VALUES
('CT091', 'Trần Trung Kiên', '2003-02-09', 'ThuMon', 'Việt Nam'),
('CT092', 'Lê Văn Sơn', '1996-12-20', 'HauVe', 'Việt Nam'),
('CT093', 'Jairo Rodrigues', '1992-12-31', 'HauVe', 'Brazil'),
('CT094', 'Dụng Quang Nho', '2000-01-01', 'HauVe', 'Việt Nam'),
('CT095', 'A Hoàng', '1995-07-31', 'HauVe', 'Việt Nam'),
('CT096', 'Trần Minh Vương', '1995-03-28', 'TienVe', 'Việt Nam'),
('CT097', 'Châu Ngọc Quang', '1996-02-01', 'TienVe', 'Việt Nam'),
('CT098', 'Marciel Silva', '1995-08-10', 'TienVe', 'Brazil'),
('CT099', 'Nguyễn Quốc Việt', '2003-05-04', 'TienDao', 'Việt Nam'),
('CT100', 'Gabriel Ferreira', '1997-10-14', 'TienDao', 'Brazil'),
('CT101', 'Trần Bảo Toàn', '2000-07-14', 'TienDao', 'Việt Nam'),
('CT102', 'Phan Đình Vũ Hải', '1994-06-06', 'ThuMon', 'Việt Nam'),
('CT103', 'Nguyễn Hữu Anh Tài', '1996-02-28', 'HauVe', 'Việt Nam'),
('CT104', 'Phan Du Học', '2001-11-01', 'HauVe', 'Việt Nam'),
('CT105', 'Nguyễn Đức Việt', '2004-01-01', 'TienVe', 'Việt Nam'),
('CT106', 'Võ Đình Lâm', '2000-01-10', 'TienVe', 'Việt Nam'),
('CT107', 'Đinh Thanh Bình', '1998-03-19', 'TienDao', 'Việt Nam'),
('CT108', 'Vũ Minh Hiếu', '2002-05-10', 'TienDao', 'Việt Nam');

INSERT INTO HOP_DONG_CAU_THU (MaHD, MaCauThu, MaDoiChuQuan, MaDoiHienTai, SoAo, NgayBatDau, NgayKetThuc, TrangThai) VALUES
('HD091', 'CT091', 'HAGL', 'HAGL', 1,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD092', 'CT092', 'HAGL', 'HAGL', 2,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD093', 'CT093', 'HAGL', 'HAGL', 33, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD094', 'CT094', 'HAGL', 'HAGL', 4,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD095', 'CT095', 'HAGL', 'HAGL', 6,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD096', 'CT096', 'HAGL', 'HAGL', 10, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD097', 'CT097', 'HAGL', 'HAGL', 8,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD098', 'CT098', 'HAGL', 'HAGL', 22, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD099', 'CT099', 'HAGL', 'HAGL', 11, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD100', 'CT100', 'HAGL', 'HAGL', 9,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD101', 'CT101', 'HAGL', 'HAGL', 20, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD102', 'CT102', 'HAGL', 'HAGL', 25, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD103', 'CT103', 'HAGL', 'HAGL', 3,  '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD104', 'CT104', 'HAGL', 'HAGL', 17, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD105', 'CT105', 'HAGL', 'HAGL', 14, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD106', 'CT106', 'HAGL', 'HAGL', 16, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD107', 'CT107', 'HAGL', 'HAGL', 19, '2025-01-01', '2027-12-31', 'ChinhThuc'),
('HD108', 'CT108', 'HAGL', 'HAGL', 28, '2025-01-01', '2027-12-31', 'ChinhThuc');

-- ----------------------------------------------------------------------------
-- 6. NẠP DỮ LIỆU VÒNG ĐẤU (10 VÒNG)
-- ----------------------------------------------------------------------------
INSERT INTO VONG_DAU (MaVong, TenVong, ThuTu) VALUES
(1, 'Vòng 1', 1),
(2, 'Vòng 2', 2),
(3, 'Vòng 3', 3),
(4, 'Vòng 4', 4),
(5, 'Vòng 5', 5),
(6, 'Vòng 6', 6),
(7, 'Vòng 7', 7),
(8, 'Vòng 8', 8),
(9, 'Vòng 9', 9),
(10, 'Vòng 10', 10);

-- ----------------------------------------------------------------------------
-- 7. NẠP LỊCH THI ĐẤU TOÀN BỘ 30 TRẬN ĐẤU CỦA MÙA GIẢI (VÒNG TRÒN 2 LƯỢT)
-- ----------------------------------------------------------------------------

-- ============================================================================
-- PHẦN 5b: DỮ LIỆU PHÂN MẢNH CỤC BỘ - 5 trận sân nhà NDFC (TR04, TR09, TR14, TR18, TR27)
-- Thứ tự nạp đúng BTL: trận (ChuaDienRa) -> phân công TT -> đăng ký -> sự kiện
-- -> chốt DaKetThuc (kích hoạt trigger đối soát bàn thắng / thẻ)
-- ============================================================================
INSERT INTO TRAN_DAU_CHUYEN_MON (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
('TR04', 2, 'NDFC', 'HNFC', 'SAN_TT', '2026-03-08 18:00:00', 3, 2, 2, 2, 0, 0, 'ChuaDienRa'),
('TR09', 3, 'NDFC', 'HAGL', 'SAN_TT', '2026-03-16 18:00:00', 4, 1, 0, 1, 0, 0, 'ChuaDienRa'),
('TR14', 5, 'NDFC', 'CAHN', 'SAN_TT', '2026-03-29 18:00:00', 2, 1, 2, 1, 0, 0, 'ChuaDienRa'),
('TR18', 6, 'NDFC', 'VTT', 'SAN_TT', '2026-04-06 18:00:00', 1, 0, 1, 1, 0, 0, 'ChuaDienRa'),
('TR27', 9, 'NDFC', 'HPFC', 'SAN_TT', '2026-04-27 18:00:00', 2, 0, 1, 1, 0, 0, 'ChuaDienRa')
;

INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
('TR04', 'Chinh', 'TT02'),
('TR04', 'Bien1', 'TT01'),
('TR04', 'Bien2', 'TT04'),
('TR04', 'Ban', 'TT03'),
('TR09', 'Chinh', 'TT10'),
('TR09', 'Bien1', 'TT12'),
('TR09', 'Bien2', 'TT09'),
('TR09', 'Ban', 'TT11'),
('TR14', 'Chinh', 'TT05'),
('TR14', 'Bien1', 'TT07'),
('TR14', 'Bien2', 'TT08'),
('TR14', 'Ban', 'TT06'),
('TR18', 'Chinh', 'TT10'),
('TR18', 'Bien1', 'TT12'),
('TR18', 'Bien2', 'TT09'),
('TR18', 'Ban', 'TT11'),
('TR27', 'Chinh', 'TT12'),
('TR27', 'Bien1', 'TT09'),
('TR27', 'Bien2', 'TT10'),
('TR27', 'Ban', 'TT11')
;

INSERT INTO DANG_KY_THI_DAU (MaTran, MaCauThu, MaDoi, VaiTroThiDau, SoAoDangKy) VALUES
('TR04', 'CT001', 'HNFC', 'ChinhThuc', 1),
('TR04', 'CT002', 'HNFC', 'ChinhThuc', 2),
('TR04', 'CT017', 'HNFC', 'DuBi', 4),
('TR04', 'CT009', 'HNFC', 'ChinhThuc', 5),
('TR04', 'CT006', 'HNFC', 'ChinhThuc', 6),
('TR04', 'CT004', 'HNFC', 'ChinhThuc', 7),
('TR04', 'CT012', 'HNFC', 'DuBi', 8),
('TR04', 'CT008', 'HNFC', 'ChinhThuc', 9),
('TR04', 'CT007', 'HNFC', 'ChinhThuc', 10),
('TR04', 'CT010', 'HNFC', 'ChinhThuc', 11),
('TR04', 'CT014', 'HNFC', 'DuBi', 13),
('TR04', 'CT013', 'HNFC', 'DuBi', 14),
('TR04', 'CT015', 'HNFC', 'DuBi', 15),
('TR04', 'CT003', 'HNFC', 'ChinhThuc', 16),
('TR04', 'CT016', 'HNFC', 'DuBi', 17),
('TR04', 'CT005', 'HNFC', 'ChinhThuc', 21),
('TR04', 'CT011', 'HNFC', 'ChinhThuc', 25),
('TR04', 'CT018', 'HNFC', 'DuBi', 28),
('TR04', 'CT055', 'NDFC', 'ChinhThuc', 1),
('TR04', 'CT067', 'NDFC', 'DuBi', 2),
('TR04', 'CT056', 'NDFC', 'ChinhThuc', 3),
('TR04', 'CT059', 'NDFC', 'ChinhThuc', 4),
('TR04', 'CT065', 'NDFC', 'ChinhThuc', 5),
('TR04', 'CT058', 'NDFC', 'ChinhThuc', 7),
('TR04', 'CT069', 'NDFC', 'DuBi', 8),
('TR04', 'CT063', 'NDFC', 'ChinhThuc', 9),
('TR04', 'CT061', 'NDFC', 'ChinhThuc', 10),
('TR04', 'CT070', 'NDFC', 'DuBi', 11),
('TR04', 'CT057', 'NDFC', 'ChinhThuc', 13),
('TR04', 'CT064', 'NDFC', 'ChinhThuc', 14),
('TR04', 'CT060', 'NDFC', 'ChinhThuc', 16),
('TR04', 'CT072', 'NDFC', 'DuBi', 18),
('TR04', 'CT071', 'NDFC', 'DuBi', 19),
('TR04', 'CT062', 'NDFC', 'ChinhThuc', 21),
('TR04', 'CT066', 'NDFC', 'DuBi', 25),
('TR04', 'CT068', 'NDFC', 'DuBi', 28),
('TR09', 'CT091', 'HAGL', 'ChinhThuc', 1),
('TR09', 'CT092', 'HAGL', 'ChinhThuc', 2),
('TR09', 'CT103', 'HAGL', 'DuBi', 3),
('TR09', 'CT094', 'HAGL', 'ChinhThuc', 4),
('TR09', 'CT095', 'HAGL', 'ChinhThuc', 6),
('TR09', 'CT097', 'HAGL', 'ChinhThuc', 8),
('TR09', 'CT100', 'HAGL', 'ChinhThuc', 9),
('TR09', 'CT096', 'HAGL', 'ChinhThuc', 10),
('TR09', 'CT099', 'HAGL', 'ChinhThuc', 11),
('TR09', 'CT105', 'HAGL', 'DuBi', 14),
('TR09', 'CT106', 'HAGL', 'DuBi', 16),
('TR09', 'CT104', 'HAGL', 'DuBi', 17),
('TR09', 'CT107', 'HAGL', 'DuBi', 19),
('TR09', 'CT101', 'HAGL', 'ChinhThuc', 20),
('TR09', 'CT098', 'HAGL', 'ChinhThuc', 22),
('TR09', 'CT102', 'HAGL', 'DuBi', 25),
('TR09', 'CT108', 'HAGL', 'DuBi', 28),
('TR09', 'CT093', 'HAGL', 'ChinhThuc', 33),
('TR09', 'CT055', 'NDFC', 'ChinhThuc', 1),
('TR09', 'CT067', 'NDFC', 'DuBi', 2),
('TR09', 'CT056', 'NDFC', 'ChinhThuc', 3),
('TR09', 'CT059', 'NDFC', 'ChinhThuc', 4),
('TR09', 'CT065', 'NDFC', 'ChinhThuc', 5),
('TR09', 'CT058', 'NDFC', 'ChinhThuc', 7),
('TR09', 'CT069', 'NDFC', 'DuBi', 8),
('TR09', 'CT063', 'NDFC', 'ChinhThuc', 9),
('TR09', 'CT061', 'NDFC', 'ChinhThuc', 10),
('TR09', 'CT070', 'NDFC', 'DuBi', 11),
('TR09', 'CT057', 'NDFC', 'ChinhThuc', 13),
('TR09', 'CT064', 'NDFC', 'ChinhThuc', 14),
('TR09', 'CT060', 'NDFC', 'ChinhThuc', 16),
('TR09', 'CT072', 'NDFC', 'DuBi', 18),
('TR09', 'CT071', 'NDFC', 'DuBi', 19),
('TR09', 'CT062', 'NDFC', 'ChinhThuc', 21),
('TR09', 'CT066', 'NDFC', 'DuBi', 25),
('TR09', 'CT068', 'NDFC', 'DuBi', 28),
('TR14', 'CT019', 'CAHN', 'ChinhThuc', 1),
('TR14', 'CT021', 'CAHN', 'ChinhThuc', 2),
('TR14', 'CT031', 'CAHN', 'DuBi', 3),
('TR14', 'CT020', 'CAHN', 'ChinhThuc', 4),
('TR14', 'CT022', 'CAHN', 'ChinhThuc', 5),
('TR14', 'CT032', 'CAHN', 'DuBi', 7),
('TR14', 'CT033', 'CAHN', 'DuBi', 8),
('TR14', 'CT029', 'CAHN', 'ChinhThuc', 9),
('TR14', 'CT028', 'CAHN', 'ChinhThuc', 10),
('TR14', 'CT025', 'CAHN', 'ChinhThuc', 11),
('TR14', 'CT026', 'CAHN', 'ChinhThuc', 12),
('TR14', 'CT034', 'CAHN', 'DuBi', 14),
('TR14', 'CT023', 'CAHN', 'ChinhThuc', 17),
('TR14', 'CT024', 'CAHN', 'ChinhThuc', 19),
('TR14', 'CT027', 'CAHN', 'ChinhThuc', 20),
('TR14', 'CT035', 'CAHN', 'DuBi', 21),
('TR14', 'CT030', 'CAHN', 'DuBi', 25),
('TR14', 'CT036', 'CAHN', 'DuBi', 30),
('TR14', 'CT055', 'NDFC', 'ChinhThuc', 1),
('TR14', 'CT067', 'NDFC', 'DuBi', 2),
('TR14', 'CT056', 'NDFC', 'ChinhThuc', 3),
('TR14', 'CT059', 'NDFC', 'ChinhThuc', 4),
('TR14', 'CT065', 'NDFC', 'ChinhThuc', 5),
('TR14', 'CT058', 'NDFC', 'ChinhThuc', 7),
('TR14', 'CT069', 'NDFC', 'DuBi', 8),
('TR14', 'CT063', 'NDFC', 'ChinhThuc', 9),
('TR14', 'CT061', 'NDFC', 'ChinhThuc', 10),
('TR14', 'CT070', 'NDFC', 'DuBi', 11),
('TR14', 'CT057', 'NDFC', 'ChinhThuc', 13),
('TR14', 'CT064', 'NDFC', 'ChinhThuc', 14),
('TR14', 'CT060', 'NDFC', 'ChinhThuc', 16),
('TR14', 'CT072', 'NDFC', 'DuBi', 18),
('TR14', 'CT071', 'NDFC', 'DuBi', 19),
('TR14', 'CT062', 'NDFC', 'ChinhThuc', 21),
('TR14', 'CT066', 'NDFC', 'DuBi', 25),
('TR14', 'CT068', 'NDFC', 'DuBi', 28),
('TR18', 'CT055', 'NDFC', 'ChinhThuc', 1),
('TR18', 'CT067', 'NDFC', 'DuBi', 2),
('TR18', 'CT056', 'NDFC', 'ChinhThuc', 3),
('TR18', 'CT059', 'NDFC', 'ChinhThuc', 4),
('TR18', 'CT065', 'NDFC', 'ChinhThuc', 5),
('TR18', 'CT058', 'NDFC', 'ChinhThuc', 7),
('TR18', 'CT069', 'NDFC', 'DuBi', 8),
('TR18', 'CT063', 'NDFC', 'ChinhThuc', 9),
('TR18', 'CT061', 'NDFC', 'ChinhThuc', 10),
('TR18', 'CT070', 'NDFC', 'DuBi', 11),
('TR18', 'CT057', 'NDFC', 'ChinhThuc', 13),
('TR18', 'CT064', 'NDFC', 'ChinhThuc', 14),
('TR18', 'CT060', 'NDFC', 'ChinhThuc', 16),
('TR18', 'CT072', 'NDFC', 'DuBi', 18),
('TR18', 'CT071', 'NDFC', 'DuBi', 19),
('TR18', 'CT062', 'NDFC', 'ChinhThuc', 21),
('TR18', 'CT066', 'NDFC', 'DuBi', 25),
('TR18', 'CT068', 'NDFC', 'DuBi', 28),
('TR18', 'CT037', 'VTT', 'ChinhThuc', 1),
('TR18', 'CT054', 'VTT', 'DuBi', 2),
('TR18', 'CT039', 'VTT', 'ChinhThuc', 3),
('TR18', 'CT049', 'VTT', 'DuBi', 5),
('TR18', 'CT050', 'VTT', 'DuBi', 6),
('TR18', 'CT047', 'VTT', 'ChinhThuc', 7),
('TR18', 'CT041', 'VTT', 'ChinhThuc', 8),
('TR18', 'CT046', 'VTT', 'ChinhThuc', 9),
('TR18', 'CT051', 'VTT', 'DuBi', 10),
('TR18', 'CT044', 'VTT', 'ChinhThuc', 11),
('TR18', 'CT040', 'VTT', 'ChinhThuc', 12),
('TR18', 'CT053', 'VTT', 'DuBi', 17),
('TR18', 'CT052', 'VTT', 'DuBi', 19),
('TR18', 'CT043', 'VTT', 'ChinhThuc', 21),
('TR18', 'CT045', 'VTT', 'ChinhThuc', 23),
('TR18', 'CT048', 'VTT', 'ChinhThuc', 25),
('TR18', 'CT042', 'VTT', 'ChinhThuc', 28),
('TR27', 'CT073', 'HPFC', 'ChinhThuc', 1),
('TR27', 'CT089', 'HPFC', 'DuBi', 2),
('TR27', 'CT085', 'HPFC', 'ChinhThuc', 3),
('TR27', 'CT077', 'HPFC', 'ChinhThuc', 4),
('TR27', 'CT074', 'HPFC', 'ChinhThuc', 5),
('TR27', 'CT075', 'HPFC', 'ChinhThuc', 6),
('TR27', 'CT081', 'HPFC', 'ChinhThuc', 7),
('TR27', 'CT082', 'HPFC', 'ChinhThuc', 9),
('TR27', 'CT083', 'HPFC', 'ChinhThuc', 10),
('TR27', 'CT090', 'HPFC', 'DuBi', 11),
('TR27', 'CT086', 'HPFC', 'DuBi', 14),
('TR27', 'CT079', 'HPFC', 'ChinhThuc', 16),
('TR27', 'CT088', 'HPFC', 'DuBi', 19),
('TR27', 'CT080', 'HPFC', 'ChinhThuc', 20),
('TR27', 'CT084', 'HPFC', 'ChinhThuc', 25),
('TR27', 'CT087', 'HPFC', 'DuBi', 30),
('TR27', 'CT055', 'NDFC', 'ChinhThuc', 1),
('TR27', 'CT067', 'NDFC', 'DuBi', 2),
('TR27', 'CT056', 'NDFC', 'ChinhThuc', 3),
('TR27', 'CT059', 'NDFC', 'ChinhThuc', 4),
('TR27', 'CT065', 'NDFC', 'ChinhThuc', 5),
('TR27', 'CT058', 'NDFC', 'ChinhThuc', 7),
('TR27', 'CT069', 'NDFC', 'DuBi', 8),
('TR27', 'CT063', 'NDFC', 'ChinhThuc', 9),
('TR27', 'CT061', 'NDFC', 'ChinhThuc', 10),
('TR27', 'CT070', 'NDFC', 'DuBi', 11),
('TR27', 'CT057', 'NDFC', 'ChinhThuc', 13),
('TR27', 'CT064', 'NDFC', 'ChinhThuc', 14),
('TR27', 'CT060', 'NDFC', 'ChinhThuc', 16),
('TR27', 'CT072', 'NDFC', 'DuBi', 18),
('TR27', 'CT071', 'NDFC', 'DuBi', 19),
('TR27', 'CT062', 'NDFC', 'ChinhThuc', 21),
('TR27', 'CT066', 'NDFC', 'DuBi', 25),
('TR27', 'CT068', 'NDFC', 'DuBi', 28)
;

INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK018', 'TR04', 'CT064', 'BanThang', 12),
('SK019', 'TR04', 'CT061', 'BanThang', 55),
('SK020', 'TR04', 'CT063', 'BanThang', 90),
('SK021', 'TR04', 'CT007', 'BanThang', 35),
('SK022', 'TR04', 'CT015', 'BanThang', 82),
('SK023', 'TR04', 'CT056', 'TheVang', 20),
('SK024', 'TR04', 'CT060', 'TheVang', 77),
('SK025', 'TR04', 'CT003', 'TheVang', 41),
('SK026', 'TR04', 'CT004', 'TheVang', 84),
('SK052', 'TR09', 'CT064', 'BanThang', 10),
('SK053', 'TR09', 'CT064', 'BanThang', 38),
('SK054', 'TR09', 'CT061', 'BanThang', 60),
('SK055', 'TR09', 'CT063', 'BanThang', 82),
('SK056', 'TR09', 'CT099', 'BanThang', 70),
('SK057', 'TR09', 'CT093', 'TheVang', 45),
('SK081', 'TR14', 'CT064', 'BanThang', 30),
('SK082', 'TR14', 'CT063', 'BanThang', 72),
('SK083', 'TR14', 'CT024', 'BanThang', 55),
('SK084', 'TR14', 'CT057', 'TheVang', 45),
('SK085', 'TR14', 'CT061', 'TheVang', 80),
('SK086', 'TR14', 'CT026', 'TheVang', 65),
('SK101', 'TR18', 'CT064', 'BanThang', 60),
('SK102', 'TR18', 'CT059', 'TheVang', 45),
('SK103', 'TR18', 'CT043', 'TheVang', 80),
('SK147', 'TR27', 'CT064', 'BanThang', 40),
('SK148', 'TR27', 'CT061', 'BanThang', 75),
('SK149', 'TR27', 'CT058', 'TheVang', 30),
('SK150', 'TR27', 'CT080', 'TheVang', 65)
;

-- Chốt trạng thái DaKetThuc cho 5 trận (kích hoạt trigger đối soát bàn thắng / thẻ)
UPDATE TRAN_DAU_CHUYEN_MON SET TrangThai = 'DaKetThuc';

-- ============================================================================
-- KIỂM TRA KẾT QUẢ (chạy xong nên thấy: 11 bảng, 6 trigger, 5 SP)
-- ============================================================================
SELECT 'SAN_VAN_DONG' AS bang, COUNT(*) AS so_dong FROM SAN_VAN_DONG
UNION ALL SELECT 'DOI_BONG', COUNT(*) FROM DOI_BONG
UNION ALL SELECT 'MAU_AO_DOI_BONG', COUNT(*) FROM MAU_AO_DOI_BONG
UNION ALL SELECT 'CAU_THU', COUNT(*) FROM CAU_THU
UNION ALL SELECT 'HOP_DONG_CAU_THU', COUNT(*) FROM HOP_DONG_CAU_THU
UNION ALL SELECT 'TRONG_TAI', COUNT(*) FROM TRONG_TAI
UNION ALL SELECT 'VONG_DAU', COUNT(*) FROM VONG_DAU
UNION ALL SELECT 'TRAN_DAU_CHUYEN_MON', COUNT(*) FROM TRAN_DAU_CHUYEN_MON
UNION ALL SELECT 'PHAN_CONG_TRONG_TAI', COUNT(*) FROM PHAN_CONG_TRONG_TAI
UNION ALL SELECT 'DANG_KY_THI_DAU', COUNT(*) FROM DANG_KY_THI_DAU
UNION ALL SELECT 'SU_KIEN_TRAN_DAU', COUNT(*) FROM SU_KIEN_TRAN_DAU
ORDER BY bang;

SELECT COUNT(*) AS so_trigger FROM pg_trigger WHERE NOT tgisinternal;

SELECT proname AS sp_hoac_ham FROM pg_proc
WHERE proname LIKE 'sp\_%' OR proname LIKE 'fn_check\_%' OR proname LIKE 'fn_prevent\_%'
ORDER BY proname;
