-- ============================================================================
-- KỊCH BẢN CÁC CÂU LỆNH TRUY VẤN DEMO THỰC CHIẾN KHI BÁO CÁO BẢO VỆ
-- Chạy trên máy của NGUYỄN NGỌC QUANG (Database: vleague_master)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TEST 1: KIỂM TRA TÍNH TRONG SUỐT VỊ TRÍ & TÁI THIẾT DỮ LIỆU
-- Mục tiêu: Chứng minh 30 trận đấu từ 6 máy tính của 6 thành viên được kéo về đầy đủ
-- ----------------------------------------------------------------------------
SELECT 
    COUNT(*) AS TongSoTran, 
    SUM(SoKhach) AS TongKhanGia,
    SUM(GiaVe * SoKhach) AS TongDoanhThuVeToanGiai
FROM vw_global_tran_dau;

-- Xem chi tiết 30 trận đấu hợp nhất từ 6 máy:
SELECT MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, BanThangNha, BanThangKhach, GiaVe, SoKhach
FROM vw_global_tran_dau
ORDER BY MaVong, MaTran;


-- ----------------------------------------------------------------------------
-- TEST 2: THỐNG KÊ VUA PHÁ LƯỚI TOÀN GIẢI PHÂN TÁN
-- Mục tiêu: Gom nhóm sự kiện bàn thắng từ 6 máy và JOIN với danh mục Cầu thủ
-- ----------------------------------------------------------------------------
SELECT 
    ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, ct.HoTen ASC) AS XepHang,
    ct.MaCauThu,
    ct.HoTen,
    ct.ViTri,
    COUNT(*) AS SoBanThang
FROM vw_global_su_kien_tran_dau sk
JOIN CAU_THU ct ON sk.MaCauThu = ct.MaCauThu
WHERE sk.LoaiSuKien = 'BanThang'
GROUP BY ct.MaCauThu, ct.HoTen, ct.ViTri
ORDER BY SoBanThang DESC, ct.HoTen ASC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- TEST 3: CẬP NHẬT THỜI GIAN THỰC XUYÊN MẠNG (REAL-TIME DEMO)
-- Kịch bản: Bạn Hồ Quang Anh (Trạm Hải Phòng) thêm 1 bàn thắng trên máy của mình:
--   INSERT INTO su_kien_tran_dau VALUES ('SK999', 'TR15', 'CT082', 'BanThang', 89);
-- Sau đó Quang chạy lại câu lệnh dưới đây tại máy chủ Trung tâm:
-- ----------------------------------------------------------------------------
SELECT ct.HoTen, COUNT(*) AS SoBanThang
FROM vw_global_su_kien_tran_dau sk
JOIN CAU_THU ct ON sk.MaCauThu = ct.MaCauThu
WHERE sk.MaCauThu = 'CT082' AND sk.LoaiSuKien = 'BanThang'
GROUP BY ct.HoTen;
