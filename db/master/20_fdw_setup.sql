-- ============================================================================
-- PHẦN FDW: KẾT NỐI TỚI 6 STATION & TẠO VIEW TOÀN CỤC
-- File này CHẠY SAU khi tất cả station đã healthy (xem scripts/setup-fdw.sh).
-- Template variables (sẽ được sed thay thế bởi setup-fdw.sh):
--   __STATION1_HOST__ ... __STATION6_HOST__  - hostname/IP của station N
-- ============================================================================

-- 3. CẤU HÌNH LIÊN KẾT TỪ XA TỚI 6 MÁY KHÁCH QUA ZEROTIER / DOCKER NETWORK
-- Xóa cấu hình cũ nếu có
DROP SCHEMA IF EXISTS site1_hnfc CASCADE;
DROP SCHEMA IF EXISTS site2_cahn CASCADE;
DROP SCHEMA IF EXISTS site3_viettel CASCADE;
DROP SCHEMA IF EXISTS site4_hpfc CASCADE;
DROP SCHEMA IF EXISTS site5_ndfc CASCADE;
DROP SCHEMA IF EXISTS site6_hagl CASCADE;

DROP SERVER IF EXISTS srv_tuan_hnfc CASCADE;
DROP SERVER IF EXISTS srv_thong_cahn CASCADE;
DROP SERVER IF EXISTS srv_dung_viettel CASCADE;
DROP SERVER IF EXISTS srv_quanganh_hpfc CASCADE;
DROP SERVER IF EXISTS srv_bich_ndfc CASCADE;
DROP SERVER IF EXISTS srv_minhdung_hagl CASCADE;

-- Tạo Foreign Server (host được substitute từ env var STATION<N>_HOST)
CREATE SERVER srv_tuan_hnfc FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '__STATION1_HOST__', port '5432', dbname 'vleague_hnfc');
CREATE SERVER srv_thong_cahn FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '__STATION2_HOST__', port '5432', dbname 'vleague_cahn');
CREATE SERVER srv_dung_viettel FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '__STATION3_HOST__', port '5432', dbname 'vleague_viettel');
CREATE SERVER srv_quanganh_hpfc FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '__STATION4_HOST__', port '5432', dbname 'vleague_haiphong');
CREATE SERVER srv_bich_ndfc FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '__STATION5_HOST__', port '5432', dbname 'vleague_namdinh');
CREATE SERVER srv_minhdung_hagl FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '__STATION6_HOST__', port '5432', dbname 'vleague_hagl');

-- Tạo User mapping (mật khẩu mặc định 123456 - khớp với POSTGRES_PASSWORD của station)
CREATE USER MAPPING FOR postgres SERVER srv_tuan_hnfc OPTIONS (user 'postgres', password '123456');
CREATE USER MAPPING FOR postgres SERVER srv_thong_cahn OPTIONS (user 'postgres', password '123456');
CREATE USER MAPPING FOR postgres SERVER srv_dung_viettel OPTIONS (user 'postgres', password '123456');
CREATE USER MAPPING FOR postgres SERVER srv_quanganh_hpfc OPTIONS (user 'postgres', password '123456');
CREATE USER MAPPING FOR postgres SERVER srv_bich_ndfc OPTIONS (user 'postgres', password '123456');
CREATE USER MAPPING FOR postgres SERVER srv_minhdung_hagl OPTIONS (user 'postgres', password '123456');

-- Tạo 6 schema đại diện cho 6 trạm ngoại lai
CREATE SCHEMA site1_hnfc;
CREATE SCHEMA site2_cahn;
CREATE SCHEMA site3_viettel;
CREATE SCHEMA site4_hpfc;
CREATE SCHEMA site5_ndfc;
CREATE SCHEMA site6_hagl;

-- Kéo cấu trúc bảng từ xa về 6 Schema (chỉ kéo tran_dau_chuyên môn + sự kiện)
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_tuan_hnfc INTO site1_hnfc;
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_thong_cahn INTO site2_cahn;
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_dung_viettel INTO site3_viettel;
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_quanganh_hpfc INTO site4_hpfc;
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_bich_ndfc INTO site5_ndfc;
IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau) FROM SERVER srv_minhdung_hagl INTO site6_hagl;

-- 4. TÁI THIẾT VIEW TOÀN CỤC HỢP NHẤT TẤT CẢ CÁC TRẠM
-- LEFT JOIN TRAN_DAU_DOANH_THU để các trận chưa có thông tin doanh thu (test,
-- lịch mới) vẫn hiển thị với GiaVe/SoKhach = NULL.
CREATE OR REPLACE VIEW vw_global_tran_dau AS
SELECT 
    cm.MaTran, cm.MaVong, cm.MaDoiNha, cm.MaDoiKhach, cm.MaSan, cm.NgayGio,
    dt.GiaVe, dt.SoKhach,
    cm.BanThangNha, cm.BanThangKhach, cm.TheVangNha, cm.TheVangKhach, cm.TheDoNha, cm.TheDoKhach, cm.TrangThai
FROM (
    SELECT * FROM site1_hnfc.tran_dau_chuyen_mon
    UNION ALL
    SELECT * FROM site2_cahn.tran_dau_chuyen_mon
    UNION ALL
    SELECT * FROM site3_viettel.tran_dau_chuyen_mon
    UNION ALL
    SELECT * FROM site4_hpfc.tran_dau_chuyen_mon
    UNION ALL
    SELECT * FROM site5_ndfc.tran_dau_chuyen_mon
    UNION ALL
    SELECT * FROM site6_hagl.tran_dau_chuyen_mon
) cm
LEFT JOIN TRAN_DAU_DOANH_THU dt ON cm.MaTran = dt.MaTran;

CREATE OR REPLACE VIEW vw_global_su_kien_tran_dau AS
SELECT * FROM site1_hnfc.su_kien_tran_dau
UNION ALL
SELECT * FROM site2_cahn.su_kien_tran_dau
UNION ALL
SELECT * FROM site3_viettel.su_kien_tran_dau
UNION ALL
SELECT * FROM site4_hpfc.su_kien_tran_dau
UNION ALL
SELECT * FROM site5_ndfc.su_kien_tran_dau
UNION ALL
SELECT * FROM site6_hagl.su_kien_tran_dau;

-- 5. VIEW BẢNG XẾP HẠNG TOÀN GIẢI (tái thiết từ vw_global_tran_dau)
CREATE OR REPLACE VIEW vw_bang_xep_hang AS
WITH TranDauKetThuc AS (
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
    FROM vw_global_tran_dau
    WHERE TrangThai = 'DaKetThuc'
    UNION ALL
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
    FROM vw_global_tran_dau
    WHERE TrangThai = 'DaKetThuc'
),
AliasDoi AS (
    -- Danh mục đội bóng giả từ MaDoiNha/MaDoiKhach (vì DOI_BONG chỉ lưu ở station)
    SELECT DISTINCT MaDoi FROM (
        SELECT MaDoiNha AS MaDoi FROM vw_global_tran_dau
        UNION
        SELECT MaDoiKhach AS MaDoi FROM vw_global_tran_dau
    ) d
),
TongHop AS (
    SELECT 
        d.MaDoi,
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
    FROM AliasDoi d
    LEFT JOIN TranDauKetThuc t ON d.MaDoi = t.MaDoi
    GROUP BY d.MaDoi
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
            MaDoi ASC
    ) AS ViTri,
    MaDoi,
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

-- 6. HÀM TOP 10 VUA PHÁ LƯỚI TOÀN GIẢI (gom từ vw_global_su_kien_tran_dau + CAU_THU master)
CREATE OR REPLACE FUNCTION fn_top10_vua_pha_luoi()
RETURNS TABLE (
    XepHang BIGINT,
    MaCauThu VARCHAR(10),
    HoTen VARCHAR(100),
    SoBanThang BIGINT
)
LANGUAGE sql
AS $$
    WITH BanThangCuaCauThu AS (
        SELECT 
            sk.MaCauThu,
            COUNT(*) AS SoBanThang
        FROM vw_global_su_kien_tran_dau sk
        WHERE sk.LoaiSuKien = 'BanThang'
        GROUP BY sk.MaCauThu
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY b.SoBanThang DESC, ct.HoTen ASC) AS XepHang,
        ct.MaCauThu,
        ct.HoTen,
        b.SoBanThang
    FROM BanThangCuaCauThu b
    JOIN CAU_THU ct ON b.MaCauThu = ct.MaCauThu
    ORDER BY b.SoBanThang DESC, ct.HoTen ASC
    LIMIT 10;
$$;

-- Xóa file template cũ (vì nội dung đã được gộp vào 10_local_data.sql + 20_fdw_setup.sql)
