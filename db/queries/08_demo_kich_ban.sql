-- ============================================================================
-- KỊCH BẢN DEMO TRUY VẤN SQL KHI BÁO CÁO BẢO VỆ
-- Chạy TRÊN máy master (Quang) - Database: vleague_master
-- Port: 5430  |  User: postgres  |  Password: 123456
--
-- Cách chạy:
--   DBeaver: kết nối localhost:5430/vleague_master, paste từng Test vào SQL editor
--   CLI:     docker exec -it football-master psql -U postgres -d vleague_master
--   Make:    make psql-master
--
-- Kiến trúc hệ thống (6 station):
--   Station 1 (HNFC - Tuấn)          -> site1_hnfc schema (FDW)
--   Station 2 (CAHN - Thông)        -> site2_cahn schema (FDW)
--   Station 3 (VTT - Mạnh Dũng)     -> site3_viettel schema (FDW)
--   Station 4 (HPFC - Quang Anh)    -> site4_hpfc schema (FDW)
--   Station 5 (NDFC - Ngọc Bích)    -> site5_ndfc schema (FDW)
--   Station 6 (HAGL - Minh Dũng)    -> site6_hagl schema (FDW)
--
-- Total: 30 trận (6 station x 5 trận sân nhà)
-- ============================================================================

\echo '============================================================'
\echo 'KỊCH BẢN 1: TÍNH TRONG SUỐT VỊ TRÍ (TRANSPARENCY)'
\echo 'Chứng minh 30 trận từ 6 máy đều hiện trên master qua FDW'
\echo '============================================================'

-- Tổng quan: đếm trận, khán giả, doanh thu toàn giải
SELECT
    COUNT(*)                            AS TongSoTran,
    SUM(SoKhach)                        AS TongKhanGia,
    SUM(GiaVe * SoKhach)                AS TongDoanhThuVe
FROM vw_global_tran_dau;

-- Chi tiết 30 trận (sắp xếp theo CLB quản lý)
SELECT
    MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan,
    BanThangNha || '-' || BanThangKhach AS TiSo,
    GiaVe, SoKhach,
    TrangThai
FROM vw_global_tran_dau
ORDER BY MaDoiNha, MaTran;

-- Phân mảnh: xem mỗi station đóng góp bao nhiêu trận
SELECT
    CASE
        WHEN MaTran IN (SELECT MaTran FROM site1_hnfc.tran_dau_chuyen_mon) THEN 'St1 HNFC (Tuấn)'
        WHEN MaTran IN (SELECT MaTran FROM site2_cahn.tran_dau_chuyen_mon) THEN 'St2 CAHN (Thông)'
        WHEN MaTran IN (SELECT MaTran FROM site4_hpfc.tran_dau_chuyen_mon) THEN 'St4 HPFC (Quang Anh)'
        WHEN MaTran IN (SELECT MaTran FROM site5_ndfc.tran_dau_chuyen_mon) THEN 'St5 NDFC (Ngọc Bích)'
        WHEN MaTran IN (SELECT MaTran FROM site6_hagl.tran_dau_chuyen_mon) THEN 'St6 HAGL (Minh Dũng)'
    END AS Station,
    COUNT(*) SoTran,
    SUM(BanThangNha + BanThangKhach) AS TongBanThang
FROM vw_global_tran_dau
GROUP BY 1
ORDER BY 1;


\echo '============================================================'
\echo 'KỊCH BẢN 2: VUA PHÁ LƯỚI TOÀN GIẢI (CROSS-SITE JOIN)'
\echo 'Gom sự kiện 6 station + JOIN CAU_THU local master'
\echo '============================================================'

-- Top 10 vua phá lưới (function FDW-ready)
SELECT MaCauThu, HoTen, SoBanThang
FROM fn_top10_vua_pha_luoi()
ORDER BY SoBanThang DESC, MaCauThu;

-- Chi tiết: cầu thủ nào ghi bàn ở trận nào, tới từ station nào
SELECT
    sk.MaTran,
    CASE
        WHEN sk.MaTran IN (SELECT MaTran FROM site1_hnfc.tran_dau_chuyen_mon) THEN 'St1 HNFC'
        WHEN sk.MaTran IN (SELECT MaTran FROM site2_cahn.tran_dau_chuyen_mon) THEN 'St2 CAHN'
        WHEN sk.MaTran IN (SELECT MaTran FROM site4_hpfc.tran_dau_chuyen_mon) THEN 'St4 HPFC'
        WHEN sk.MaTran IN (SELECT MaTran FROM site5_ndfc.tran_dau_chuyen_mon) THEN 'St5 NDFC'
        WHEN sk.MaTran IN (SELECT MaTran FROM site6_hagl.tran_dau_chuyen_mon) THEN 'St6 HAGL'
    END AS Station,
    sk.MaCauThu,
    ct.HoTen,
    sk.PhutGhiNhan
FROM vw_global_su_kien_tran_dau sk
JOIN CAU_THU ct ON sk.MaCauThu = ct.MaCauThu
WHERE sk.LoaiSuKien = 'BanThang'
ORDER BY sk.MaTran, sk.PhutGhiNhan;

-- Top scorer phân theo CLB (MaDoiNha)
SELECT
    td.MaDoiNha AS CLB,
    ct.HoTen    AS CauThu,
    COUNT(*)    AS SoBanThang
FROM vw_global_su_kien_tran_dau sk
JOIN CAU_THU ct ON sk.MaCauThu = ct.MaCauThu
JOIN vw_global_tran_dau td ON sk.MaTran = td.MaTran
WHERE sk.LoaiSuKien = 'BanThang'
GROUP BY td.MaDoiNha, ct.HoTen
ORDER BY CLB, SoBanThang DESC;


\echo '============================================================'
\echo 'KỊCH BẢN 3: BẢNG XẾP HẠNG TỰ CẬP NHẬT'
\echo 'BXH tổng hợp từ vw_global_tran_dau (6 station)'
\echo '============================================================'

SELECT
    ViTri, MaDoi,
    SoTranDaDau, SoTranThang, SoTranHoa, SoTranThua,
    TongBanThang, TongBanThua, HieuSo,
    DiemSo,
    SoTranThangSanKhach,
    TongTheDo, TongTheVang
FROM vw_bang_xep_hang
ORDER BY ViTri;


\echo '============================================================'
\echo 'KỊCH BẢN 4: THỐNG KÊ DOANH THU (MẢNH DỌC)'
\echo 'Tran_Dau_Doanh_Thu chỉ lưu ở master - phân mảnh dọc'
\echo '============================================================'

-- Tổng doanh thu toàn giải
SELECT
    COUNT(*)                    AS SoTranCoDoanhThu,
    SUM(SoKhach)                AS TongKhach,
    SUM(GiaVe * SoKhach)        AS TongDoanhThu,
    AVG(GiaVe)                  AS GiaVeTrungBinh
FROM tran_dau_doanh_thu;

-- Doanh thu theo từng vòng đấu
SELECT
    td.MaVong,
    COUNT(*)                    AS SoTran,
    SUM(dt.SoKhach)             AS TongKhach,
    SUM(dt.GiaVe * dt.SoKhach)  AS DoanhThu
FROM vw_global_tran_dau td
JOIN tran_dau_doanh_thu dt ON td.MaTran = dt.MaTran
GROUP BY td.MaVong
ORDER BY td.MaVong;

-- Top 5 trận doanh thu cao nhất
SELECT
    td.MaTran, td.MaDoiNha, td.MaDoiKhach,
    dt.GiaVe, dt.SoKhach,
    dt.GiaVe * dt.SoKhach AS DoanhThu
FROM vw_global_tran_dau td
JOIN tran_dau_doanh_thu dt ON td.MaTran = dt.MaTran
ORDER BY DoanhThu DESC
LIMIT 5;


\echo '============================================================'
\echo 'KỊCH BẢN 5: REAL-TIME CROSS-SITE UPDATE'
\echo 'Bạn bè insert 1 row ở station -> master thấy qua FDW lập tức'
\echo '============================================================'

-- BƯỚC A: Báo 1 bạn (vd Quang Anh station 4) chạy trên máy anh ta:
--     ./scripts/station-test-insert.sh
--   Script insert MaTran=T4abc12345, CT994 ghi N bàn
--
-- BƯỚC B: Quang (master) chạy query dưới đây -> thấy row mới ngay
--     (không cần re-import schema, FDW query live)

-- Xem test row tới từ station nào
SELECT
    CASE
        WHEN MaTran LIKE 'TEST_1_%' OR MaTran LIKE 'T1%' THEN 'Station1 HNFC (Tuấn)'
        WHEN MaTran LIKE 'TEST_2_%' OR MaTran LIKE 'T2%' THEN 'Station2 CAHN (Thông)'
        WHEN MaTran LIKE 'TEST_4_%' OR MaTran LIKE 'T4%' THEN 'Station4 HPFC (Quang Anh)'
        WHEN MaTran LIKE 'TEST_5_%' OR MaTran LIKE 'T5%' THEN 'Station5 NDFC (Ngọc Bích)'
        WHEN MaTran LIKE 'TEST_6_%' OR MaTran LIKE 'T6%' THEN 'Station6 HAGL (Minh Dũng)'
        ELSE 'Chưa xác định station'
    END AS Trang,
    MaTran, MaDoiNha, MaDoiKhach,
    BanThangNha || '-' || BanThangKhach AS TiSo
FROM vw_global_tran_dau
WHERE MaTran LIKE 'TEST_%'
   OR MaTran LIKE 'T1%' OR MaTran LIKE 'T2%'
   OR MaTran LIKE 'T4%' OR MaTran LIKE 'T5%' OR MaTran LIKE 'T6%'
ORDER BY MaTran;

-- BXH mới sau khi test row cộng điểm
SELECT ViTri, MaDoi, SoTranDaDau, SoTranThang, DiemSo
FROM vw_bang_xep_hang
ORDER BY DiemSo DESC, HieuSo DESC;


\echo '============================================================'
\echo 'KỊCH BẢN 6: WRITE-THROUGH FDW (master INSERT sang station)'
\echo 'Chứng minh FDW cho phép 2 chiều: read + write'
\echo '============================================================'

-- Quang (master) insert 1 row QUA foreign table -> push tới station Thông
-- (replace T2TEST1234 bằng MaTran duy nhất tránh UNIQUE conflict)
INSERT INTO site2_cahn.tran_dau_chuyen_mon
    (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio,
     BanThangNha, BanThangKhach, TheVangNha, TheVangKhach,
     TheDoNha, TheDoKhach, TrangThai)
VALUES ('T2DEMO1234', 9, 'CAHN', 'P2TEST12', 'SV02',
        '2026-11-02 10:00:00', 3, 1, 0, 0, 0, 0, 'DaKetThuc');

-- Verify trên master qua FDW
SELECT MaTran, MaDoiNha, MaDoiKhach, BanThangNha || '-' || BanThangKhach AS TiSo
FROM site2_cahn.tran_dau_chuyen_mon
WHERE MaTran = 'T2DEMO1234';

-- Verify trên máy Thông thực sự lưu (run trên máy Quang, query sang station Thông)
--   docker exec football-master psql -h 10.19.227.149 -p 5432 -U postgres -d vleague_cahn \
--     -c "SELECT MaTran FROM tran_dau_chuyen_mon WHERE MaTran='T2DEMO1234';"

-- Cleanup test row
DELETE FROM site2_cahn.tran_dau_chuyen_mon WHERE MaTran = 'T2DEMO1234';


\echo '============================================================'
\echo 'KỊCH BẢN 7: KIỂM TRA PHÂN MẢNH - mỗi station giữ gì'
\echo 'Dùng foreign table trực tiếp (không qua view)'
\echo '============================================================'

-- Đếm trực tiếp từng station
SELECT 'Station 1 (HNFC - Tuấn)'      AS Station, COUNT(*) AS SoTran FROM site1_hnfc.tran_dau_chuyen_mon
UNION ALL SELECT 'Station 2 (CAHN - Thông)',    COUNT(*) FROM site2_cahn.tran_dau_chuyen_mon
UNION ALL SELECT 'Station 4 (HPFC - Quang Anh)', COUNT(*) FROM site4_hpfc.tran_dau_chuyen_mon
UNION ALL SELECT 'Station 5 (NDFC - Ngọc Bích)', COUNT(*) FROM site5_ndfc.tran_dau_chuyen_mon
UNION ALL SELECT 'Station 6 (HAGL - Minh Dũng)', COUNT(*) FROM site6_hagl.tran_dau_chuyen_mon
ORDER BY 1;

-- Chi tiết: 5 trận sân nhà HNFC trên máy Tuấn
SELECT MaTran, MaDoiNha, MaDoiKhach, BanThangNha, BanThangKhach, NgayGio
FROM site1_hnfc.tran_dau_chuyen_mon
ORDER BY MaTran;

-- Chi tiết: 5 trận sân nhà NDFC trên máy Ngọc Bích (category schema của NFL)
SELECT MaTran, MaDoiNha, MaDoiKhach, BanThangNha, BanThangKhach, NgayGio
FROM site5_ndfc.tran_dau_chuyen_mon
ORDER BY MaTran;


\echo '============================================================'
\echo 'KỊCH BẢN 8: DEMO FAILED CASE - station offline'
\echo 'Khi 1 station offline, query qua FDW phải có ERROR rõ ràng'
\echo '============================================================'

-- Ví dụ: 1 station chưa IMPORT foreign tables (schema trống) hoặc offline,
-- query trực tiếp sẽ báo ERROR:
-- SELECT * FROM site3_viettel.tran_dau_chuyen_mon;
-- ERROR: relation "site3_viettel.tran_dau_chuyen_mon" does not exist

-- Tương tự nếu 1 station offline (một bạn tắt máy):
-- SELECT * FROM site2_cahn.tran_dau_chuyen_mon;
-- -> ERROR: could not connect to server "srv_thong_cahn"
-- DETAIL: connection to server at "10.19.227.149", port 5432 failed: Connection refused

-- Tuy nhiên view vw_global_tran_dau cũng sẽ fail nếu 1 station trong UNION ALL offline


\echo '============================================================'
\echo 'KỊCH BẢN 9: DEMO TỔNG KẾT CHO BÁO CÁO BẢO VỆ'
\echo '============================================================'

-- Tóm tắt 1 dòng trạng thái hệ thống
SELECT
    (SELECT COUNT(*) FROM vw_global_tran_dau)            AS TongTran,
    (SELECT COUNT(*) FROM vw_global_su_kien_tran_dau)    AS TongSuKien,
    (SELECT COUNT(*) FROM CAU_THU)                       AS SoCauThuMaster,
    (SELECT COUNT(*) FROM vw_bang_xep_hang)               AS SoDoiBXH,
    (SELECT COUNT(*) FROM information_schema.tables
       WHERE table_schema LIKE 'site%' AND table_type='FOREIGN') AS SoForeignTables;

-- Phân mảnh rõ ràng: mô tả(SELECT descripcion)
\echo '=> 6 station đóng góp 5 trận mỗi cái = 30 tran (mảnh ngang theo đội sân nhà)'
\echo '=> Master giữ CAU_THU 22 (mảnh dọc, JOIN với vw_global_su_kien_tran_dau để top scorer)'
\echo '=> Master giữ TRAN_DAU_DOANH_THU 30 (mảnh dọc tài chính, LEFT JOIN với vw_global_tran_dau)'
\echo '=> FDW = postgres_fdw, IMPORT FOREIGN SCHEMA LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau)'

-- Báo cáo: truy vấn từ schema nào?
SELECT
    n.nspname AS schema,
    c.relname AS object,
    c.relkind AS kind,  -- 'r'=table, 'f'=foreign, 'v'=view, 'm'=matview
    pg_size_pretty(pg_total_relation_size(c.oid)) AS size
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname IN ('public', 'site1_hnfc', 'site2_cahn', 'site4_hpfc', 'site5_ndfc', 'site6_hagl')
  AND c.relkind IN ('r', 'f', 'v', 'm')
ORDER BY n.nspname, c.relname;
