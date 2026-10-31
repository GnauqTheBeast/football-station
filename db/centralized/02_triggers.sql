-- ============================================================================
-- PHẦN 2: CÀI ĐẶT 5 TRIGGER BẮT BUỘC KIỂM TRA TOÀN VẸN NGHIỆP VỤ & ĐIỀU KHIỂN TƯƠNG TRANH
-- HỆ QUẢN TRỊ: PostgreSQL (PL/pgSQL) - Kiểm soát tương tranh đa phiên bản (MVCC)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1: KIỂM TRA QUY ĐỊNH SÂN ĐẤU, SỨC CHỨA VÀ THỜI GIAN THI ĐẤU
-- Bảng áp dụng: TRAN_DAU
-- Nghiệp vụ: Số khán giả không vượt sức chứa; trận đấu kết thúc không ở tương lai;
--            hai trận đấu trên cùng một sân phải cách nhau tối thiểu 4 giờ.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_quy_dinh_san_dau()
RETURNS TRIGGER AS $$
DECLARE
    v_suc_chua INT;
    v_so_tran_trung_gio INT;
BEGIN
    -- Khóa dòng sân vận động (Row-level lock) để tuần tự hóa các giao dịch xếp lịch đồng thời
    SELECT SucChua INTO v_suc_chua
    FROM SAN_VAN_DONG
    WHERE MaSan = NEW.MaSan
    FOR NO KEY UPDATE;

    -- 1. Kiểm tra sức chứa khán đài
    IF NEW.SoKhach > v_suc_chua THEN
        RAISE EXCEPTION 'Lỗi nghiệp vụ: Số lượng khán giả (%) vượt quá sức chứa sân vận động (%)!',
            NEW.SoKhach, v_suc_chua;
    END IF;

    -- 2. Kiểm tra tính hợp lệ về thời gian khi kết thúc trận
    IF NEW.TrangThai = 'DaKetThuc' AND NEW.NgayGio > CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'Lỗi nghiệp vụ: Trận đấu có thời điểm diễn ra ở tương lai không thể có trạng thái DaKetThuc!';
    END IF;

    -- 3. Kiểm tra khoảng cách 4 giờ trên cùng sân vận động (sử dụng chỉ mục B-Tree idx_tran_dau_san_ngaygio)
    SELECT COUNT(*) INTO v_so_tran_trung_gio
    FROM TRAN_DAU
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

DROP TRIGGER IF EXISTS trg_check_quy_dinh_san_dau ON TRAN_DAU;
CREATE TRIGGER trg_check_quy_dinh_san_dau
BEFORE INSERT OR UPDATE OF MaSan, NgayGio, SoKhach, TrangThai
ON TRAN_DAU
FOR EACH ROW
EXECUTE FUNCTION fn_check_quy_dinh_san_dau();


-- ----------------------------------------------------------------------------
-- TRIGGER 2: KIỂM TRA HỢP ĐỒNG CẦU THỦ, SỐ ÁO VÀ GIỚI HẠN TỐI ĐA 30 CẦU THỦ
-- Bảng áp dụng: HOP_DONG_CAU_THU
-- Nghiệp vụ: Tại một thời điểm, mỗi cầu thủ chỉ thi đấu cho 1 đội; số áo trong đội
--            không được trùng giữa các cầu thủ đang thi đấu; mỗi đội tối đa 30 cầu thủ.
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
-- Nghiệp vụ: Đội hình 18 người (11 đá chính, tối đa 7 dự bị); kiểm tra hạn hợp đồng
--            theo ngày trận đấu; cấm cầu thủ cho mượn đá chống đội chủ quản;
--            kiểm tra án treo giò do thẻ phạt ở trận trước đó của đội.
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
    FROM TRAN_DAU 
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

    -- 5. Kiểm tra án treo giò: Xét trận đấu liền trước của đội bóng này
    SELECT MaTran INTO v_ma_tran_truoc
    FROM TRAN_DAU
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
            JOIN TRAN_DAU td ON sk.MaTran = td.MaTran
            WHERE sk.MaCauThu = NEW.MaCauThu 
              AND sk.LoaiSuKien = 'TheVang'
              AND td.NgayGio <= (SELECT NgayGio FROM TRAN_DAU WHERE MaTran = v_ma_tran_truoc);

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
-- Nghiệp vụ: 1 trọng tài không được phân công điều khiển 2 trận đấu trong cùng 1 vòng.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_phan_cong_trong_tai()
RETURNS TRIGGER AS $$
DECLARE
    v_ma_vong INT;
    v_trung_vong INT;
BEGIN
    -- Lấy mã vòng đấu của trận hiện tại
    SELECT MaVong INTO v_ma_vong 
    FROM TRAN_DAU 
    WHERE MaTran = NEW.MaTran;

    -- Khóa bản ghi trọng tài để tuần tự hóa các giao dịch phân công
    PERFORM 1 FROM TRONG_TAI WHERE MaTrongTai = NEW.MaTrongTai FOR NO KEY UPDATE;

    -- Kiểm tra xem trọng tài đã có nhiệm vụ trong bất kỳ trận nào thuộc vòng này chưa
    SELECT COUNT(*) INTO v_trung_vong
    FROM PHAN_CONG_TRONG_TAI pc
    JOIN TRAN_DAU td ON pc.MaTran = td.MaTran
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
-- Bảng áp dụng: TRAN_DAU
-- Nghiệp vụ: Khi trận chuyển sang DaKetThuc, phải có đủ 4 trọng tài;
--            tổng bàn thắng (bàn thắng thường + phản lưới nhà của đối phương)
--            và số lượng thẻ phạt phải khớp chính xác với bảng SU_KIEN_TRAN_DAU.
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

DROP TRIGGER IF EXISTS trg_check_khop_ban_thang_va_the ON TRAN_DAU;
CREATE TRIGGER trg_check_khop_ban_thang_va_the
AFTER INSERT OR UPDATE OF TrangThai, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach
ON TRAN_DAU
FOR EACH ROW
EXECUTE FUNCTION fn_check_khop_ban_thang_va_the();


-- ----------------------------------------------------------------------------
-- TRIGGER BỔ TRỢ: BẢO VỆ DỮ LIỆU SỰ KIỆN KHI TRẬN ĐẤU ĐÃ KẾT THÚC
-- Bảng áp dụng: SU_KIEN_TRAN_DAU
-- Nghiệp vụ: Chặn INSERT/UPDATE/DELETE sự kiện khi trận đấu đã 'DaKetThuc'
--            nhằm bảo toàn tuyệt đối tính nhất quán của tỉ số và thẻ phạt.
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
    FROM TRAN_DAU 
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
