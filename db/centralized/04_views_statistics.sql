-- ============================================================================
-- PHẦN 4: VIEWS VÀ HÀM THỐNG KÊ (BẢNG XẾP HẠNG, VUA PHÁ LƯỚI, LƯƠNG TRỌNG TÀI)
-- HỆ QUẢN TRỊ: PostgreSQL
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. VIEW BẢNG XẾP HẠNG MÙA GIẢI
-- Tiêu chí sắp xếp: Điểm -> Hiệu số -> Tổng bàn thắng -> Số trận thắng sân khách
--                   -> Tổng thẻ đỏ (ít hơn xếp trên) -> Tổng thẻ vàng (ít hơn)
-- Thể thức: Thắng = 3 điểm, Hòa = 1 điểm, Thua = 0 điểm.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_bang_xep_hang AS
WITH TranDauKetThuc AS (
    -- Thống kê khi đội đóng vai trò SÂN NHÀ
    SELECT 
        MaDoiNha AS MaDoi,
        1 AS SoTran,
        CASE WHEN BanThangNha > BanThangKhach THEN 1 ELSE 0 END AS Thang,
        CASE WHEN BanThangNha = BanThangKhach THEN 1 ELSE 0 END AS Hoa,
        CASE WHEN BanThangNha < BanThangKhach THEN 1 ELSE 0 END AS Thua,
        BanThangNha AS BanThang,
        BanThangKhach AS BanThua,
        0 AS ThangSanKhach,
        TheDoNha AS TheDo,
        TheVangNha AS TheVang
    FROM TRAN_DAU
    WHERE TrangThai = 'DaKetThuc'

    UNION ALL

    -- Thống kê khi đội đóng vai trò SÂN KHÁCH
    SELECT 
        MaDoiKhach AS MaDoi,
        1 AS SoTran,
        CASE WHEN BanThangKhach > BanThangNha THEN 1 ELSE 0 END AS Thang,
        CASE WHEN BanThangKhach = BanThangNha THEN 1 ELSE 0 END AS Hoa,
        CASE WHEN BanThangKhach < BanThangNha THEN 1 ELSE 0 END AS Thua,
        BanThangKhach AS BanThang,
        BanThangNha AS BanThua,
        CASE WHEN BanThangKhach > BanThangNha THEN 1 ELSE 0 END AS ThangSanKhach,
        TheDoKhach AS TheDo,
        TheVangKhach AS TheVang
    FROM TRAN_DAU
    WHERE TrangThai = 'DaKetThuc'
),
TongHop AS (
    SELECT 
        d.MaDoi,
        d.TenDoi,
        COALESCE(SUM(t.SoTran), 0) AS SoTranDaDau,
        COALESCE(SUM(t.Thang), 0) AS SoTranThang,
        COALESCE(SUM(t.Hoa), 0) AS SoTranHoa,
        COALESCE(SUM(t.Thua), 0) AS SoTranThua,
        COALESCE(SUM(t.BanThang), 0) AS TongBanThang,
        COALESCE(SUM(t.BanThua), 0) AS TongBanThua,
        COALESCE(SUM(t.BanThang) - SUM(t.BanThua), 0) AS HieuSo,
        COALESCE(SUM(t.Thang) * 3 + SUM(t.Hoa) * 1, 0) AS DiemSo,
        COALESCE(SUM(t.ThangSanKhach), 0) AS SoTranThangSanKhach,
        COALESCE(SUM(t.TheDo), 0) AS TongTheDo,
        COALESCE(SUM(t.TheVang), 0) AS TongTheVang
    FROM DOI_BONG d
    LEFT JOIN TranDauKetThuc t ON d.MaDoi = t.MaDoi
    GROUP BY d.MaDoi, d.TenDoi
)
SELECT 
    ROW_NUMBER() OVER (
        ORDER BY 
            DiemSo DESC, 
            HieuSo DESC, 
            TongBanThang DESC, 
            SoTranThangSanKhach DESC, 
            TongTheDo ASC, 
            TongTheVang ASC,
            TenDoi ASC
    ) AS ViTri,
    MaDoi,
    TenDoi,
    SoTranDaDau,
    SoTranThang,
    SoTranHoa,
    SoTranThua,
    TongBanThang,
    TongBanThua,
    HieuSo,
    DiemSo,
    SoTranThangSanKhach,
    TongTheDo,
    TongTheVang
FROM TongHop;


-- ----------------------------------------------------------------------------
-- 2. HÀM TRUY VẤN TOP 10 CẦU THỦ GHI NHIỀU BÀN THẮNG NHẤT (VUA PHÁ LƯỚI)
-- Lưu ý: Gom nhóm theo cầu thủ (MaCauThu, HoTen), không gom theo TenDoi để tránh
--        bị phân tách dòng nếu cầu thủ chuyển nhượng giữa mùa. Đội bóng hiện tại
--        được truy vấn độc lập từ hợp đồng mới nhất còn hiệu lực.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_top10_vua_pha_luoi()
RETURNS TABLE (
    XepHang BIGINT,
    MaCauThu VARCHAR(10),
    HoTen VARCHAR(100),
    TenDoiHienTai VARCHAR(100),
    SoBanThang BIGINT
)
LANGUAGE sql
AS $$
    WITH BanThangCuaCauThu AS (
        SELECT 
            sk.MaCauThu,
            COUNT(*) AS SoBanThang
        FROM SU_KIEN_TRAN_DAU sk
        WHERE sk.LoaiSuKien = 'BanThang'
        GROUP BY sk.MaCauThu
    ),
    DoiBongHienTai AS (
        SELECT DISTINCT ON (hd.MaCauThu)
            hd.MaCauThu,
            db.TenDoi
        FROM HOP_DONG_CAU_THU hd
        JOIN DOI_BONG db ON hd.MaDoiHienTai = db.MaDoi
        WHERE hd.TrangThai IN ('ChinhThuc', 'ChoMuon')
        ORDER BY hd.MaCauThu, hd.NgayBatDau DESC
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY b.SoBanThang DESC, ct.HoTen ASC) AS XepHang,
        ct.MaCauThu,
        ct.HoTen,
        COALESCE(d.TenDoi, 'Tự do') AS TenDoiHienTai,
        b.SoBanThang
    FROM BanThangCuaCauThu b
    JOIN CAU_THU ct ON b.MaCauThu = ct.MaCauThu
    LEFT JOIN DoiBongHienTai d ON b.MaCauThu = d.MaCauThu
    ORDER BY b.SoBanThang DESC, ct.HoTen ASC
    LIMIT 10;
$$;


-- ----------------------------------------------------------------------------
-- 3. HÀM TÍNH LƯƠNG TRỌNG TÀI THEO THÁNG
-- Quy định thù lao: Trọng tài chính = 3 triệu/trận; Trọng tài biên = 2 triệu/trận;
--                   Trọng tài bàn = 1 triệu/trận.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_tinh_luong_trong_tai_thang(
    p_thang INT,
    p_nam INT
)
RETURNS TABLE (
    MaTrongTai VARCHAR(10),
    HoTen VARCHAR(100),
    CapBac VARCHAR(50),
    SoTranChinh BIGINT,
    SoTranBien BIGINT,
    SoTranBan BIGINT,
    TongSoTran BIGINT,
    TongLuong DECIMAL(15, 2)
)
LANGUAGE sql
AS $$
    SELECT 
        tt.MaTrongTai,
        tt.HoTen,
        tt.CapBac,
        COUNT(CASE WHEN td.MaTran IS NOT NULL AND pc.VaiTro = 'Chinh' THEN 1 END) AS SoTranChinh,
        COUNT(CASE WHEN td.MaTran IS NOT NULL AND pc.VaiTro IN ('Bien1', 'Bien2') THEN 1 END) AS SoTranBien,
        COUNT(CASE WHEN td.MaTran IS NOT NULL AND pc.VaiTro = 'Ban' THEN 1 END) AS SoTranBan,
        COUNT(td.MaTran) AS TongSoTran,
        (
            COUNT(CASE WHEN td.MaTran IS NOT NULL AND pc.VaiTro = 'Chinh' THEN 1 END) * 3000000 +
            COUNT(CASE WHEN td.MaTran IS NOT NULL AND pc.VaiTro IN ('Bien1', 'Bien2') THEN 1 END) * 2000000 +
            COUNT(CASE WHEN td.MaTran IS NOT NULL AND pc.VaiTro = 'Ban' THEN 1 END) * 1000000
        )::DECIMAL(15, 2) AS TongLuong
    FROM TRONG_TAI tt
    LEFT JOIN (
        PHAN_CONG_TRONG_TAI pc
        JOIN TRAN_DAU td ON pc.MaTran = td.MaTran
                        AND EXTRACT(MONTH FROM td.NgayGio) = p_thang
                        AND EXTRACT(YEAR FROM td.NgayGio) = p_nam
                        AND td.TrangThai = 'DaKetThuc'
    ) ON tt.MaTrongTai = pc.MaTrongTai
    GROUP BY tt.MaTrongTai, tt.HoTen, tt.CapBac
    ORDER BY TongLuong DESC, tt.HoTen ASC;
$$;


-- ----------------------------------------------------------------------------
-- 4. HÀM THỐNG KÊ DOANH THU CỦA CÁC SÂN VẬN ĐỘNG
-- Công thức: Doanh thu = Tổng (Số lượng khán giả * Giá vé mỗi trận)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_thong_ke_doanh_thu_san()
RETURNS TABLE (
    MaSan VARCHAR(10),
    TenSan VARCHAR(100),
    DiaChi VARCHAR(200),
    SucChua INT,
    SoTranDaToChuc BIGINT,
    TongKhanGia BIGINT,
    TongDoanhThu DECIMAL(18, 2)
)
LANGUAGE sql
AS $$
    SELECT 
        s.MaSan,
        s.TenSan,
        s.DiaChi,
        s.SucChua,
        COUNT(t.MaTran) AS SoTranDaToChuc,
        COALESCE(SUM(t.SoKhach), 0)::BIGINT AS TongKhanGia,
        COALESCE(SUM(t.SoKhach * t.GiaVe), 0)::DECIMAL(18, 2) AS TongDoanhThu
    FROM SAN_VAN_DONG s
    LEFT JOIN TRAN_DAU t ON s.MaSan = t.MaSan AND t.TrangThai = 'DaKetThuc'
    GROUP BY s.MaSan, s.TenSan, s.DiaChi, s.SucChua
    ORDER BY TongDoanhThu DESC, s.TenSan ASC;
$$;


-- ----------------------------------------------------------------------------
-- 5. HÀM THỐNG KÊ DIỄN BIẾN MỘT VÒNG ĐẤU CỤ THỂ
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_thong_ke_vong_dau(p_ma_vong INT)
RETURNS TABLE (
    MaTran VARCHAR(10),
    NgayGio TIMESTAMP,
    TenSan VARCHAR(100),
    DoiNha VARCHAR(100),
    DoiKhach VARCHAR(100),
    TiSo VARCHAR(20),
    TheVang INT,
    TheDo INT,
    SoKhach INT,
    TrangThai VARCHAR(20)
)
LANGUAGE sql
AS $$
    SELECT 
        t.MaTran,
        t.NgayGio,
        s.TenSan,
        dn.TenDoi AS DoiNha,
        dk.TenDoi AS DoiKhach,
        CONCAT(t.BanThangNha, ' - ', t.BanThangKhach) AS TiSo,
        (t.TheVangNha + t.TheVangKhach) AS TheVang,
        (t.TheDoNha + t.TheDoKhach) AS TheDo,
        t.SoKhach,
        t.TrangThai
    FROM TRAN_DAU t
    JOIN DOI_BONG dn ON t.MaDoiNha = dn.MaDoi
    JOIN DOI_BONG dk ON t.MaDoiKhach = dk.MaDoi
    JOIN SAN_VAN_DONG s ON t.MaSan = s.MaSan
    WHERE t.MaVong = p_ma_vong
    ORDER BY t.NgayGio ASC;
$$;
