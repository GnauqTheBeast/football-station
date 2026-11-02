-- ============================================================================
-- PHẦN 5: BỘ DỮ LIỆU MẪU ĐẦY ĐỦ CHO TRỌN VẸN MỘT MÙA GIẢI (6 ĐỘI, 30 TRẬN)
-- HỆ QUẢN TRỊ: PostgreSQL
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
-- VÒNG 1 (Ngày 2026-03-01)
INSERT INTO TRAN_DAU (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, GiaVe, SoKhach, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
('TR01', 1, 'HNFC', 'HPFC', 'SAN_HD', '2026-03-01 19:15:00', 80000, 15200, 2, 1, 2, 1, 0, 0, 'ChuaDienRa'),
('TR02', 1, 'CAHN', 'HAGL', 'SAN_HD', '2026-03-02 19:15:00', 80000, 12000, 3, 0, 1, 2, 0, 0, 'ChuaDienRa'),
('TR03', 1, 'VTT',  'NDFC', 'SAN_MD', '2026-03-01 18:00:00', 60000, 18500, 1, 2, 1, 1, 0, 0, 'ChuaDienRa');

-- VÒNG 2 (Ngày 2026-03-08)
INSERT INTO TRAN_DAU (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, GiaVe, SoKhach, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
('TR04', 2, 'NDFC', 'HNFC', 'SAN_TT', '2026-03-08 18:00:00', 70000, 22000, 3, 2, 2, 2, 0, 0, 'ChuaDienRa'),
('TR05', 2, 'HPFC', 'CAHN', 'SAN_LT', '2026-03-08 19:15:00', 70000, 19500, 0, 2, 3, 1, 0, 0, 'ChuaDienRa'),
('TR06', 2, 'HAGL', 'VTT',  'SAN_PK', '2026-03-09 17:00:00', 50000, 9800,  1, 1, 1, 2, 0, 0, 'ChuaDienRa');

-- VÒNG 3 (Ngày 2026-03-15)
INSERT INTO TRAN_DAU (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, GiaVe, SoKhach, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
('TR07', 3, 'HNFC', 'CAHN', 'SAN_HD', '2026-03-15 19:15:00', 100000, 21500, 2, 2, 2, 3, 1, 0, 'ChuaDienRa'),
('TR08', 3, 'VTT',  'HPFC', 'SAN_MD', '2026-03-15 18:00:00', 60000,  14000, 2, 0, 1, 1, 0, 0, 'ChuaDienRa'),
('TR09', 3, 'NDFC', 'HAGL', 'SAN_TT', '2026-03-16 18:00:00', 70000,  18000, 4, 1, 0, 1, 0, 0, 'ChuaDienRa');

-- VÒNG 4 (Ngày 2026-03-22)
INSERT INTO TRAN_DAU (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, GiaVe, SoKhach, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
('TR10', 4, 'HAGL', 'HNFC', 'SAN_PK', '2026-03-22 17:00:00', 50000, 10500, 0, 1, 2, 1, 0, 0, 'ChuaDienRa'),
('TR11', 4, 'CAHN', 'VTT',  'SAN_HD', '2026-03-22 19:15:00', 90000, 17000, 1, 1, 2, 2, 0, 0, 'ChuaDienRa'),
('TR12', 4, 'HPFC', 'NDFC', 'SAN_LT', '2026-03-23 18:00:00', 70000, 16000, 1, 3, 1, 2, 0, 0, 'ChuaDienRa');

-- VÒNG 5 (Ngày 2026-03-29 - Hết lượt đi)
INSERT INTO TRAN_DAU (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, GiaVe, SoKhach, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
('TR13', 5, 'HNFC', 'VTT',  'SAN_HD', '2026-03-29 19:15:00', 90000, 18000, 2, 1, 1, 2, 0, 0, 'ChuaDienRa'),
('TR14', 5, 'NDFC', 'CAHN', 'SAN_TT', '2026-03-29 18:00:00', 80000, 24000, 2, 1, 2, 1, 0, 0, 'ChuaDienRa'),
('TR15', 5, 'HPFC', 'HAGL', 'SAN_LT', '2026-03-30 18:00:00', 60000, 13000, 2, 0, 1, 0, 0, 0, 'ChuaDienRa');

-- LƯỢT VỀ (VÒNG 6 ĐẾN 10)
-- VÒNG 6 (Đảo ngược Vòng 1)
INSERT INTO TRAN_DAU (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, GiaVe, SoKhach, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
('TR16', 6, 'HPFC', 'HNFC', 'SAN_LT', '2026-04-05 18:00:00', 80000, 17500, 1, 2, 2, 2, 0, 0, 'ChuaDienRa'),
('TR17', 6, 'HAGL', 'CAHN', 'SAN_PK', '2026-04-05 17:00:00', 50000, 11000, 0, 2, 1, 1, 0, 0, 'ChuaDienRa'),
('TR18', 6, 'NDFC', 'VTT',  'SAN_TT', '2026-04-06 18:00:00', 70000, 21000, 1, 0, 1, 1, 0, 0, 'ChuaDienRa');

-- VÒNG 7 (Đảo ngược Vòng 2)
INSERT INTO TRAN_DAU (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, GiaVe, SoKhach, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
('TR19', 7, 'HNFC', 'NDFC', 'SAN_HD', '2026-04-12 19:15:00', 90000, 19000, 1, 1, 1, 2, 0, 0, 'ChuaDienRa'),
('TR20', 7, 'CAHN', 'HPFC', 'SAN_HD', '2026-04-13 19:15:00', 80000, 14500, 2, 1, 1, 1, 0, 0, 'ChuaDienRa'),
('TR21', 7, 'VTT',  'HAGL', 'SAN_MD', '2026-04-12 18:00:00', 60000, 12000, 3, 1, 0, 1, 0, 0, 'ChuaDienRa');

-- VÒNG 8 (Đảo ngược Vòng 3)
INSERT INTO TRAN_DAU (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, GiaVe, SoKhach, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
('TR22', 8, 'CAHN', 'HNFC', 'SAN_HD', '2026-04-19 19:15:00', 100000, 22000, 1, 2, 3, 2, 0, 1, 'ChuaDienRa'),
('TR23', 8, 'HPFC', 'VTT',  'SAN_LT', '2026-04-19 18:00:00', 70000,  15000, 1, 1, 2, 2, 0, 0, 'ChuaDienRa'),
('TR24', 8, 'HAGL', 'NDFC', 'SAN_PK', '2026-04-20 17:00:00', 50000,  9500,  0, 2, 1, 0, 0, 0, 'ChuaDienRa');

-- VÒNG 9 (Đảo ngược Vòng 4)
INSERT INTO TRAN_DAU (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, GiaVe, SoKhach, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
('TR25', 9, 'HNFC', 'HAGL', 'SAN_HD', '2026-04-26 19:15:00', 80000, 14000, 3, 0, 0, 1, 0, 0, 'ChuaDienRa'),
('TR26', 9, 'VTT',  'CAHN', 'SAN_MD', '2026-04-26 18:00:00', 80000, 16500, 2, 1, 2, 1, 0, 0, 'ChuaDienRa'),
('TR27', 9, 'NDFC', 'HPFC', 'SAN_TT', '2026-04-27 18:00:00', 70000, 23000, 2, 0, 1, 1, 0, 0, 'ChuaDienRa');

-- VÒNG 10 (Đảo ngược Vòng 5 - Vòng hạ màn)
INSERT INTO TRAN_DAU (MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, GiaVe, SoKhach, BanThangNha, BanThangKhach, TheVangNha, TheVangKhach, TheDoNha, TheDoKhach, TrangThai) VALUES
('TR28', 10, 'VTT',  'HNFC', 'SAN_MD', '2026-05-03 18:00:00', 90000, 20000, 1, 1, 2, 2, 0, 0, 'ChuaDienRa'),
('TR29', 10, 'CAHN', 'NDFC', 'SAN_HD', '2026-05-03 18:00:00', 90000, 21000, 1, 1, 1, 2, 0, 0, 'ChuaDienRa'),
('TR30', 10, 'HAGL', 'HPFC', 'SAN_PK', '2026-05-03 18:00:00', 50000, 10000, 2, 1, 1, 1, 0, 0, 'ChuaDienRa');

-- ----------------------------------------------------------------------------
-- 8. NẠP PHÂN CÔNG ĐỦ 4 TRỌNG TÀI CHO 30 TRẬN ĐẤU (12 TT / VÒNG, KHÔNG TRÙNG)
-- ----------------------------------------------------------------------------
-- Vòng 1: Trận TR01 (TT01, TT02, TT03, TT04), TR02 (TT05, TT06, TT07, TT08), TR03 (TT09, TT10, TT11, TT12)
INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
('TR01', 'Chinh', 'TT01'), ('TR01', 'Bien1', 'TT02'), ('TR01', 'Bien2', 'TT03'), ('TR01', 'Ban', 'TT04'),
('TR02', 'Chinh', 'TT05'), ('TR02', 'Bien1', 'TT06'), ('TR02', 'Bien2', 'TT07'), ('TR02', 'Ban', 'TT08'),
('TR03', 'Chinh', 'TT09'), ('TR03', 'Bien1', 'TT10'), ('TR03', 'Bien2', 'TT11'), ('TR03', 'Ban', 'TT12');

-- Vòng 2
INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
('TR04', 'Chinh', 'TT02'), ('TR04', 'Bien1', 'TT01'), ('TR04', 'Bien2', 'TT04'), ('TR04', 'Ban', 'TT03'),
('TR05', 'Chinh', 'TT07'), ('TR05', 'Bien1', 'TT05'), ('TR05', 'Bien2', 'TT08'), ('TR05', 'Ban', 'TT06'),
('TR06', 'Chinh', 'TT11'), ('TR06', 'Bien1', 'TT09'), ('TR06', 'Bien2', 'TT12'), ('TR06', 'Ban', 'TT10');

-- Vòng 3
INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
('TR07', 'Chinh', 'TT03'), ('TR07', 'Bien1', 'TT04'), ('TR07', 'Bien2', 'TT01'), ('TR07', 'Ban', 'TT02'),
('TR08', 'Chinh', 'TT06'), ('TR08', 'Bien1', 'TT08'), ('TR08', 'Bien2', 'TT05'), ('TR08', 'Ban', 'TT07'),
('TR09', 'Chinh', 'TT10'), ('TR09', 'Bien1', 'TT12'), ('TR09', 'Bien2', 'TT09'), ('TR09', 'Ban', 'TT11');

-- Vòng 4
INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
('TR10', 'Chinh', 'TT04'), ('TR10', 'Bien1', 'TT03'), ('TR10', 'Bien2', 'TT02'), ('TR10', 'Ban', 'TT01'),
('TR11', 'Chinh', 'TT08'), ('TR11', 'Bien1', 'TT07'), ('TR11', 'Bien2', 'TT06'), ('TR11', 'Ban', 'TT05'),
('TR12', 'Chinh', 'TT12'), ('TR12', 'Bien1', 'TT11'), ('TR12', 'Bien2', 'TT10'), ('TR12', 'Ban', 'TT09');

-- Vòng 5
INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
('TR13', 'Chinh', 'TT01'), ('TR13', 'Bien1', 'TT03'), ('TR13', 'Bien2', 'TT04'), ('TR13', 'Ban', 'TT02'),
('TR14', 'Chinh', 'TT05'), ('TR14', 'Bien1', 'TT07'), ('TR14', 'Bien2', 'TT08'), ('TR14', 'Ban', 'TT06'),
('TR15', 'Chinh', 'TT09'), ('TR15', 'Bien1', 'TT11'), ('TR15', 'Bien2', 'TT12'), ('TR15', 'Ban', 'TT10');

-- Vòng 6
INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
('TR16', 'Chinh', 'TT02'), ('TR16', 'Bien1', 'TT04'), ('TR16', 'Bien2', 'TT01'), ('TR16', 'Ban', 'TT03'),
('TR17', 'Chinh', 'TT06'), ('TR17', 'Bien1', 'TT08'), ('TR17', 'Bien2', 'TT05'), ('TR17', 'Ban', 'TT07'),
('TR18', 'Chinh', 'TT10'), ('TR18', 'Bien1', 'TT12'), ('TR18', 'Bien2', 'TT09'), ('TR18', 'Ban', 'TT11');

-- Vòng 7
INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
('TR19', 'Chinh', 'TT03'), ('TR19', 'Bien1', 'TT01'), ('TR19', 'Bien2', 'TT02'), ('TR19', 'Ban', 'TT04'),
('TR20', 'Chinh', 'TT07'), ('TR20', 'Bien1', 'TT05'), ('TR20', 'Bien2', 'TT06'), ('TR20', 'Ban', 'TT08'),
('TR21', 'Chinh', 'TT11'), ('TR21', 'Bien1', 'TT09'), ('TR21', 'Bien2', 'TT10'), ('TR21', 'Ban', 'TT12');

-- Vòng 8
INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
('TR22', 'Chinh', 'TT01'), ('TR22', 'Bien1', 'TT02'), ('TR22', 'Bien2', 'TT03'), ('TR22', 'Ban', 'TT04'),
('TR23', 'Chinh', 'TT05'), ('TR23', 'Bien1', 'TT06'), ('TR23', 'Bien2', 'TT07'), ('TR23', 'Ban', 'TT08'),
('TR24', 'Chinh', 'TT09'), ('TR24', 'Bien1', 'TT10'), ('TR24', 'Bien2', 'TT11'), ('TR24', 'Ban', 'TT12');

-- Vòng 9
INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
('TR25', 'Chinh', 'TT04'), ('TR25', 'Bien1', 'TT01'), ('TR25', 'Bien2', 'TT02'), ('TR25', 'Ban', 'TT03'),
('TR26', 'Chinh', 'TT08'), ('TR26', 'Bien1', 'TT05'), ('TR26', 'Bien2', 'TT06'), ('TR26', 'Ban', 'TT07'),
('TR27', 'Chinh', 'TT12'), ('TR27', 'Bien1', 'TT09'), ('TR27', 'Bien2', 'TT10'), ('TR27', 'Ban', 'TT11');

-- Vòng 10
INSERT INTO PHAN_CONG_TRONG_TAI (MaTran, VaiTro, MaTrongTai) VALUES
('TR28', 'Chinh', 'TT02'), ('TR28', 'Bien1', 'TT03'), ('TR28', 'Bien2', 'TT01'), ('TR28', 'Ban', 'TT04'),
('TR29', 'Chinh', 'TT06'), ('TR29', 'Bien1', 'TT07'), ('TR29', 'Bien2', 'TT05'), ('TR29', 'Ban', 'TT08'),
('TR30', 'Chinh', 'TT10'), ('TR30', 'Bien1', 'TT11'), ('TR30', 'Bien2', 'TT09'), ('TR30', 'Ban', 'TT12');

-- ----------------------------------------------------------------------------
-- 8.5. NẠP DANH SÁCH ĐĂNG KÝ THI ĐẤU CHO 30 TRẬN ĐẤU (11 CHÍNH THỨC + DỰ BỊ)
-- Loại trừ 30 trường hợp cầu thủ bị treo giò ở vòng kế tiếp do nhận thẻ đỏ
-- hoặc tích lũy đủ 2 thẻ vàng ở vòng liền trước.
-- ----------------------------------------------------------------------------
INSERT INTO DANG_KY_THI_DAU (MaTran, MaCauThu, MaDoi, VaiTroThiDau, SoAoDangKy)
SELECT
    sub.MaTran,
    sub.MaCauThu,
    sub.MaDoi,
    CASE WHEN sub.rn <= 11 THEN 'ChinhThuc' ELSE 'DuBi' END AS VaiTroThiDau,
    sub.SoAo AS SoAoDangKy
FROM (
    SELECT
        t.MaTran,
        hd.MaCauThu,
        hd.MaDoiHienTai AS MaDoi,
        hd.SoAo,
        ROW_NUMBER() OVER (PARTITION BY t.MaTran, hd.MaDoiHienTai ORDER BY hd.MaCauThu) AS rn
    FROM TRAN_DAU t
    JOIN HOP_DONG_CAU_THU hd
      ON hd.MaDoiHienTai IN (t.MaDoiNha, t.MaDoiKhach)
     AND hd.TrangThai = 'ChinhThuc'
    WHERE (t.MaTran, hd.MaCauThu) NOT IN (
        ('TR10', 'CT009'), ('TR10', 'CT002'), ('TR10', 'CT006'),
        ('TR18', 'CT038'), ('TR19', 'CT003'), ('TR19', 'CT059'),
        ('TR20', 'CT074'), ('TR20', 'CT021'), ('TR21', 'CT043'),
        ('TR22', 'CT004'), ('TR22', 'CT020'), ('TR23', 'CT075'),
        ('TR24', 'CT056'), ('TR24', 'CT060'), ('TR24', 'CT094'),
        ('TR25', 'CT010'), ('TR25', 'CT014'), ('TR25', 'CT093'),
        ('TR26', 'CT022'), ('TR26', 'CT023'), ('TR26', 'CT028'),
        ('TR26', 'CT039'), ('TR26', 'CT041'), ('TR27', 'CT076'),
        ('TR27', 'CT078'), ('TR28', 'CT044'), ('TR29', 'CT025'),
        ('TR29', 'CT058'), ('TR30', 'CT095'), ('TR30', 'CT080')
    )
) sub;

-- ----------------------------------------------------------------------------
-- 9. NẠP SỰ KIỆN BÀN THẮNG & THẺ PHẠT (ĐẢM BẢO KHỚP CHÍNH XÁC KẾT QUẢ TRẬN ĐẤU)
-- ----------------------------------------------------------------------------
-- TR01: HNFC 2 - 1 HPFC (Thẻ vàng: HNFC 2, HPFC 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK001', 'TR01', 'CT007', 'BanThang', 23),
('SK002', 'TR01', 'CT008', 'BanThang', 67),
('SK003', 'TR01', 'CT082', 'BanThang', 81),
('SK004', 'TR01', 'CT002', 'TheVang', 44),
('SK005', 'TR01', 'CT006', 'TheVang', 75),
('SK006', 'TR01', 'CT075', 'TheVang', 89);

-- TR02: CAHN 3 - 0 HAGL (Thẻ vàng: CAHN 1, HAGL 2)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK007', 'TR02', 'CT024', 'BanThang', 15),
('SK008', 'TR02', 'CT028', 'BanThang', 52),
('SK009', 'TR02', 'CT029', 'BanThang', 78),
('SK010', 'TR02', 'CT023', 'TheVang', 33),
('SK011', 'TR02', 'CT094', 'TheVang', 40),
('SK012', 'TR02', 'CT096', 'TheVang', 85);

-- TR03: VTT 1 - 2 NDFC (Thẻ vàng: VTT 1, NDFC 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK013', 'TR03', 'CT046', 'BanThang', 30),
('SK014', 'TR03', 'CT064', 'BanThang', 45),
('SK015', 'TR03', 'CT064', 'BanThang', 88),
('SK016', 'TR03', 'CT043', 'TheVang', 62),
('SK017', 'TR03', 'CT059', 'TheVang', 71);

-- TR04: NDFC 3 - 2 HNFC (Thẻ vàng: NDFC 2, HNFC 2)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK018', 'TR04', 'CT064', 'BanThang', 12),
('SK019', 'TR04', 'CT061', 'BanThang', 55),
('SK020', 'TR04', 'CT063', 'BanThang', 90),
('SK021', 'TR04', 'CT007', 'BanThang', 35),
('SK022', 'TR04', 'CT015', 'BanThang', 82),
('SK023', 'TR04', 'CT056', 'TheVang', 20),
('SK024', 'TR04', 'CT060', 'TheVang', 77),
('SK025', 'TR04', 'CT003', 'TheVang', 41),
('SK026', 'TR04', 'CT004', 'TheVang', 84);

-- TR05: HPFC 0 - 2 CAHN (Thẻ vàng: HPFC 3, CAHN 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK027', 'TR05', 'CT024', 'BanThang', 28),
('SK028', 'TR05', 'CT029', 'BanThang', 64),
('SK029', 'TR05', 'CT074', 'TheVang', 30),
('SK030', 'TR05', 'CT078', 'TheVang', 50),
('SK031', 'TR05', 'CT080', 'TheVang', 73),
('SK032', 'TR05', 'CT020', 'TheVang', 60);

-- TR06: HAGL 1 - 1 VTT (Thẻ vàng: HAGL 1, VTT 2)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK033', 'TR06', 'CT096', 'BanThang', 40),
('SK034', 'TR06', 'CT042', 'BanThang', 65),
('SK035', 'TR06', 'CT095', 'TheVang', 55),
('SK036', 'TR06', 'CT038', 'TheVang', 38),
('SK037', 'TR06', 'CT041', 'TheVang', 82);

-- TR07: HNFC 2 - 2 CAHN (Thẻ vàng: HNFC 2, CAHN 3; Thẻ đỏ: HNFC 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK038', 'TR07', 'CT008', 'BanThang', 18),
('SK039', 'TR07', 'CT016', 'BanThang', 70),
('SK040', 'TR07', 'CT027', 'BanThang', 35),
('SK041', 'TR07', 'CT024', 'BanThang', 89),
('SK042', 'TR07', 'CT002', 'TheVang', 25),
('SK043', 'TR07', 'CT006', 'TheVang', 60),
('SK044', 'TR07', 'CT009', 'TheDo', 85),
('SK045', 'TR07', 'CT021', 'TheVang', 44),
('SK046', 'TR07', 'CT025', 'TheVang', 66),
('SK047', 'TR07', 'CT028', 'TheVang', 90);

-- TR08: VTT 2 - 0 HPFC (Thẻ vàng: VTT 1, HPFC 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK048', 'TR08', 'CT046', 'BanThang', 22),
('SK049', 'TR08', 'CT045', 'BanThang', 76),
('SK050', 'TR08', 'CT039', 'TheVang', 50),
('SK051', 'TR08', 'CT076', 'TheVang', 80);

-- TR09: NDFC 4 - 1 HAGL (Thẻ vàng: NDFC 0, HAGL 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK052', 'TR09', 'CT064', 'BanThang', 10),
('SK053', 'TR09', 'CT064', 'BanThang', 38),
('SK054', 'TR09', 'CT061', 'BanThang', 60),
('SK055', 'TR09', 'CT063', 'BanThang', 82),
('SK056', 'TR09', 'CT099', 'BanThang', 70),
('SK057', 'TR09', 'CT093', 'TheVang', 45);

-- TR10: HAGL 0 - 1 HNFC (Thẻ vàng: HAGL 2, HNFC 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK058', 'TR10', 'CT007', 'BanThang', 55),
('SK059', 'TR10', 'CT092', 'TheVang', 30),
('SK060', 'TR10', 'CT097', 'TheVang', 80),
('SK061', 'TR10', 'CT014', 'TheVang', 65);

-- TR11: CAHN 1 - 1 VTT (Thẻ vàng: CAHN 2, VTT 2)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK062', 'TR11', 'CT029', 'BanThang', 42),
('SK063', 'TR11', 'CT042', 'BanThang', 68),
('SK064', 'TR11', 'CT022', 'TheVang', 25),
('SK065', 'TR11', 'CT024', 'TheVang', 75),
('SK066', 'TR11', 'CT040', 'TheVang', 50),
('SK067', 'TR11', 'CT044', 'TheVang', 85);

-- TR12: HPFC 1 - 3 NDFC (Thẻ vàng: HPFC 1, NDFC 2)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK068', 'TR12', 'CT082', 'BanThang', 50),
('SK069', 'TR12', 'CT064', 'BanThang', 15),
('SK070', 'TR12', 'CT064', 'BanThang', 65),
('SK071', 'TR12', 'CT068', 'BanThang', 90),
('SK072', 'TR12', 'CT081', 'TheVang', 35),
('SK073', 'TR12', 'CT058', 'TheVang', 40),
('SK074', 'TR12', 'CT062', 'TheVang', 88);

-- TR13: HNFC 2 - 1 VTT (Thẻ vàng: HNFC 1, VTT 2)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK075', 'TR13', 'CT008', 'BanThang', 20),
('SK076', 'TR13', 'CT015', 'BanThang', 75),
('SK077', 'TR13', 'CT046', 'BanThang', 85),
('SK078', 'TR13', 'CT005', 'TheVang', 60),
('SK079', 'TR13', 'CT038', 'TheVang', 30),
('SK080', 'TR13', 'CT047', 'TheVang', 70);

-- TR14: NDFC 2 - 1 CAHN (Thẻ vàng: NDFC 2, CAHN 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK081', 'TR14', 'CT064', 'BanThang', 30),
('SK082', 'TR14', 'CT063', 'BanThang', 72),
('SK083', 'TR14', 'CT024', 'BanThang', 55),
('SK084', 'TR14', 'CT057', 'TheVang', 45),
('SK085', 'TR14', 'CT061', 'TheVang', 80),
('SK086', 'TR14', 'CT026', 'TheVang', 65);

-- TR15: HPFC 2 - 0 HAGL (Thẻ vàng: HPFC 1, HAGL 0)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK087', 'TR15', 'CT082', 'BanThang', 40),
('SK088', 'TR15', 'CT083', 'BanThang', 68),
('SK089', 'TR15', 'CT077', 'TheVang', 52);

-- VÒNG 6 ĐẾN VÒNG 10 (15 trận lượt về)
-- TR16: HPFC 1 - 2 HNFC (Vàng: HP 2, HN 2)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK090', 'TR16', 'CT083', 'BanThang', 25),
('SK091', 'TR16', 'CT007', 'BanThang', 50),
('SK092', 'TR16', 'CT008', 'BanThang', 85),
('SK093', 'TR16', 'CT074', 'TheVang', 30),
('SK094', 'TR16', 'CT079', 'TheVang', 70),
('SK095', 'TR16', 'CT002', 'TheVang', 40),
('SK096', 'TR16', 'CT003', 'TheVang', 88);

-- TR17: HAGL 0 - 2 CAHN (Vàng: HAGL 1, CAHN 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK097', 'TR17', 'CT028', 'BanThang', 18),
('SK098', 'TR17', 'CT029', 'BanThang', 72),
('SK099', 'TR17', 'CT098', 'TheVang', 55),
('SK100', 'TR17', 'CT021', 'TheVang', 65);

-- TR18: NDFC 1 - 0 VTT (Vàng: NDFC 1, VTT 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK101', 'TR18', 'CT064', 'BanThang', 60),
('SK102', 'TR18', 'CT059', 'TheVang', 45),
('SK103', 'TR18', 'CT043', 'TheVang', 80);

-- TR19: HNFC 1 - 1 NDFC (Vàng: HN 1, NDFC 2)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK104', 'TR19', 'CT008', 'BanThang', 33),
('SK105', 'TR19', 'CT064', 'BanThang', 75),
('SK106', 'TR19', 'CT004', 'TheVang', 50),
('SK107', 'TR19', 'CT056', 'TheVang', 25),
('SK108', 'TR19', 'CT060', 'TheVang', 85);

-- TR20: CAHN 2 - 1 HPFC (Vàng: CAHN 1, HP 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK109', 'TR20', 'CT024', 'BanThang', 22),
('SK110', 'TR20', 'CT027', 'BanThang', 65),
('SK111', 'TR20', 'CT082', 'BanThang', 80),
('SK112', 'TR20', 'CT020', 'TheVang', 40),
('SK113', 'TR20', 'CT075', 'TheVang', 60);

-- TR21: VTT 3 - 1 HAGL (Vàng: VTT 0, HAGL 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK114', 'TR21', 'CT042', 'BanThang', 15),
('SK115', 'TR21', 'CT046', 'BanThang', 48),
('SK116', 'TR21', 'CT045', 'BanThang', 82),
('SK117', 'TR21', 'CT096', 'BanThang', 60),
('SK118', 'TR21', 'CT094', 'TheVang', 70);

-- TR22: CAHN 1 - 2 HNFC (Vàng: CAHN 3, HN 2; Đỏ: HNFC 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK119', 'TR22', 'CT029', 'BanThang', 30),
('SK120', 'TR22', 'CT007', 'BanThang', 55),
('SK121', 'TR22', 'CT016', 'BanThang', 90),
('SK122', 'TR22', 'CT022', 'TheVang', 20),
('SK123', 'TR22', 'CT023', 'TheVang', 45),
('SK124', 'TR22', 'CT028', 'TheVang', 75),
('SK125', 'TR22', 'CT006', 'TheVang', 35),
('SK126', 'TR22', 'CT014', 'TheVang', 80),
('SK127', 'TR22', 'CT010', 'TheDo', 88);

-- TR23: HPFC 1 - 1 VTT (Vàng: HP 2, VTT 2)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK128', 'TR23', 'CT082', 'BanThang', 35),
('SK129', 'TR23', 'CT046', 'BanThang', 70),
('SK130', 'TR23', 'CT076', 'TheVang', 25),
('SK131', 'TR23', 'CT078', 'TheVang', 65),
('SK132', 'TR23', 'CT039', 'TheVang', 40),
('SK133', 'TR23', 'CT041', 'TheVang', 82);

-- TR24: HAGL 0 - 2 NDFC (Vàng: HAGL 1, NDFC 0)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK134', 'TR24', 'CT064', 'BanThang', 20),
('SK135', 'TR24', 'CT063', 'BanThang', 65),
('SK136', 'TR24', 'CT093', 'TheVang', 50);

-- TR25: HNFC 3 - 0 HAGL (Vàng: HN 0, HAGL 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK137', 'TR25', 'CT007', 'BanThang', 15),
('SK138', 'TR25', 'CT008', 'BanThang', 42),
('SK139', 'TR25', 'CT015', 'BanThang', 78),
('SK140', 'TR25', 'CT095', 'TheVang', 60);

-- TR26: VTT 2 - 1 CAHN (Vàng: VTT 2, CAHN 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK141', 'TR26', 'CT042', 'BanThang', 25),
('SK142', 'TR26', 'CT046', 'BanThang', 80),
('SK143', 'TR26', 'CT024', 'BanThang', 60),
('SK144', 'TR26', 'CT038', 'TheVang', 35),
('SK145', 'TR26', 'CT044', 'TheVang', 75),
('SK146', 'TR26', 'CT025', 'TheVang', 50);

-- TR27: NDFC 2 - 0 HPFC (Vàng: NDFC 1, HP 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK147', 'TR27', 'CT064', 'BanThang', 40),
('SK148', 'TR27', 'CT061', 'BanThang', 75),
('SK149', 'TR27', 'CT058', 'TheVang', 30),
('SK150', 'TR27', 'CT080', 'TheVang', 65);

-- TR28: VTT 1 - 1 HNFC (Vàng: VTT 2, HN 2)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK151', 'TR28', 'CT046', 'BanThang', 45),
('SK152', 'TR28', 'CT008', 'BanThang', 70),
('SK153', 'TR28', 'CT040', 'TheVang', 30),
('SK154', 'TR28', 'CT043', 'TheVang', 85),
('SK155', 'TR28', 'CT002', 'TheVang', 50),
('SK156', 'TR28', 'CT004', 'TheVang', 90);

-- TR29: CAHN 1 - 1 NDFC (Vàng: CAHN 1, NDFC 2)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK157', 'TR29', 'CT024', 'BanThang', 35),
('SK158', 'TR29', 'CT064', 'BanThang', 82),
('SK159', 'TR29', 'CT021', 'TheVang', 60),
('SK160', 'TR29', 'CT057', 'TheVang', 40),
('SK161', 'TR29', 'CT062', 'TheVang', 75);

-- TR30: HAGL 2 - 1 HPFC (Vàng: HAGL 1, HP 1)
INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan) VALUES
('SK162', 'TR30', 'CT096', 'BanThang', 20),
('SK163', 'TR30', 'CT100', 'BanThang', 65),
('SK164', 'TR30', 'CT082', 'BanThang', 50),
('SK165', 'TR30', 'CT092', 'TheVang', 40),
('SK166', 'TR30', 'CT074', 'TheVang', 70);

-- ----------------------------------------------------------------------------
-- 10. CHỐT KẾT QUẢ TOÀN BỘ 30 TRẬN ĐẤU (KÍCH HOẠT TRIGGER ĐỐI SOÁT SỐ LIỆU)
-- ----------------------------------------------------------------------------
UPDATE TRAN_DAU SET TrangThai = 'DaKetThuc';
