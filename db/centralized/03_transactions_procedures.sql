-- ============================================================================
-- PHẦN 3: CÀI ĐẶT 5 GIAO DỊCH (TRANSACTION / STORED PROCEDURE) TRỌNG YẾU
-- HỆ QUẢN TRỊ: PostgreSQL (PL/pgSQL) - Tối ưu hóa Chỉ mục B-Tree & Khóa đồng thời
-- ============================================================================

-- ----------------------------------------------------------------------------
-- GIAO DỊCH 1: KHỞI TẠO LỊCH THI ĐẤU CHO MỘT TRẬN ĐẤU THUỘC VÒNG ĐẤU
-- Đảm bảo: Hai đội không trùng nhau, cặp đấu chưa từng đá trên sân nhà này, 
--          sân vận động không bị trùng giờ thi đấu (sử dụng B-Tree Index Scan).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tao_lich_thi_dau(
    p_ma_tran VARCHAR(10),
    p_ma_vong INT,
    p_ma_doi_nha VARCHAR(10),
    p_ma_doi_khach VARCHAR(10),
    p_ma_san VARCHAR(10),
    p_ngay_gio TIMESTAMP,
    p_gia_ve DECIMAL(12, 2)
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
    FROM TRAN_DAU
    WHERE MaDoiNha = p_ma_doi_nha AND MaDoiKhach = p_ma_doi_khach;

    IF v_da_ton_tai > 0 THEN
        RAISE EXCEPTION 'Lỗi giao dịch: Trận đấu giữa % (sân nhà) và % (sân khách) đã được xếp lịch trước đó!',
            p_ma_doi_nha, p_ma_doi_khach;
    END IF;

    -- 3. Kiểm tra sân vận động không bị trùng giờ thi đấu (cách nhau tối thiểu 4 giờ)
    -- Sử dụng phép so sánh khoảng trực tiếp trên cột NgayGio để tận dụng chỉ mục B-Tree idx_tran_dau_san_ngaygio
    SELECT COUNT(*) INTO v_trung_lich_san
    FROM TRAN_DAU
    WHERE MaSan = p_ma_san
      AND NgayGio > p_ngay_gio - INTERVAL '4 hours'
      AND NgayGio < p_ngay_gio + INTERVAL '4 hours';

    IF v_trung_lich_san > 0 THEN
        RAISE EXCEPTION 'Lỗi giao dịch: Sân vận động % đã có trận đấu diễn ra trong khoảng thời gian 4 giờ lân cận!',
            p_ma_san;
    END IF;

    -- 4. Thực hiện thêm trận đấu mới
    INSERT INTO TRAN_DAU (
        MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, 
        NgayGio, GiaVe, SoKhach, BanThangNha, BanThangKhach, 
        TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai
    ) VALUES (
        p_ma_tran, p_ma_vong, p_ma_doi_nha, p_ma_doi_khach, p_ma_san,
        p_ngay_gio, p_gia_ve, 0, 0, 0, 0, 0, 0, 0, 'ChuaDienRa'
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- GIAO DỊCH 2: PHÂN CÔNG ĐỦ TỔ 4 TRỌNG TÀI CHO MỘT TRẬN ĐẤU
-- Đảm bảo: Đủ 4 trọng tài khác nhau, không ai bị trùng lịch trong cùng vòng đấu.
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
    PERFORM 1 FROM TRAN_DAU WHERE MaTran = p_ma_tran FOR NO KEY UPDATE;

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
-- Đảm bảo: Cầu thủ thuộc biên chế đội bóng vào ngày thi đấu, gán đúng số áo.
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
    FROM TRAN_DAU 
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
-- Đảm bảo: Ghi nhận tỉ số, thẻ phạt, số lượng khán giả và đổi trạng thái sang 'DaKetThuc'
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_ghi_nhan_ket_qua_tran_dau(
    p_ma_tran VARCHAR(10),
    p_so_khach INT,
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
    FROM TRAN_DAU
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
    UPDATE TRAN_DAU
    SET SoKhach = p_so_khach,
        BanThangNha = p_ban_nha,
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
-- GIAO DỊCH 5: CHUYỂN NHƯỢNG HOẶC CHO MƯỢN CẦU THỦ
-- Đảm bảo: Nếu cho mượn ('ChoMuon'), hợp đồng gốc chuyển sang 'TamDung' để bảo lưu quyền sở hữu của CLB chủ quản;
--          nếu chuyển nhượng dứt đoạn ('ChinhThuc'), hợp đồng cũ chuyển sang 'ThanhLy'.
--          Nhờ Partial Unique Index, không bao giờ bị văng lỗi trùng khóa.
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
    -- Nếu cho mượn: Hợp đồng gốc tạm dừng để giữ quyền sở hữu của CLB chủ quản
    -- Nếu chuyển nhượng chính thức: Hợp đồng cũ thanh lý
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
    -- (Partial Unique Index và Trigger trg_check_hop_dong_va_so_ao sẽ đảm bảo tính hợp lệ tuyệt đối)
    INSERT INTO HOP_DONG_CAU_THU (
        MaHD, MaCauThu, MaDoiChuQuan, MaDoiHienTai, 
        SoAo, NgayBatDau, NgayKetThuc, TrangThai
    ) VALUES (
        p_ma_hd_moi, p_ma_cau_thu, p_ma_doi_chu_quan, p_ma_doi_moi,
        p_so_ao_moi, p_ngay_bat_dau, p_ngay_ket_thuc, p_trang_thai
    );
END;
$$;
