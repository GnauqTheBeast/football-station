# NGHIỆP VỤ - HỆ CSDL QUẢN LÝ GIẢI BÓNG ĐÁ V-LEAGUE

> Tài liệu nội bộ - GIẢI THÍCH NGHIỆP VỤ (BUSINESS LOGIC) của hệ thống.
> Không phải tài liệu kỹ thuật/kết nối. Đọc để hiểu "vì sao thiết kế vậy",
> "thực tế V-League hoạt động ra sao trong CSDL này".
>
> **Chỉ lưu local, KHÔNG push lên repo.**

---

## 1. CONTEXT - Giải V-League trong bài toán này

Đây là **giải bóng đá chuyên nghiệp Việt Nam** mô phỏng, gồm:

| Đội (6 clb) | Mã | Sân nhà | Huấn luyện viên |
|---|---|---|---|
| Hà Nội FC | `HNFC` | Hàng Đẫy (`SAN_HD`, 22.500 chỗ) | Daiki Iwamasa |
| Công An Hà Nội | `CAHN` | Hàng Đẫy (`SAN_HD`) | Alexandre Polking |
| Thể Công Viettel | `VTT` | Quốc Gia Mỹ Đình (`SAN_MD`, 40.192 chỗ) | Nguyễn Đức Thắng |
| Hải Phòng FC | `HPFC` | Lạch Tray (`SAN_LT`, 30.000 chỗ) | Chu Đình Nghiêm |
| Thép Xanh Nam Định | `NDFC` | Thiên Trường (`SAN_TT`, 30.000 chỗ) | Vũ Hồng Việt |
| Hoàng Anh Gia Lai | `HAGL` | Pleiku (`SAN_PK`, Gia Lai, 12.000 chỗ) | Vũ Tiến Thành |

**Lưu ý**: HNFC và CAHN cùng chia sẻ sân Hàng Đẫy (đặc thù đời thực).

### Thể thức mùa giải

- 6 đội → vòng tròn 2 lượt: mỗi đội gặp 5 đội kia 2 lần (sân nhà + sân khách)
- Tổng: `6 × 5 = 30 trận/season`
- Phân theo 10 vòng đấu (`VONG_DAU`: 1-10), mỗi vòng 3 trận
- Mùa giải kéo dài 2 tháng (2026-03-01 → 2026-04-27)

Khảo sát seed dữ liệu: 30 trận `TR01`..`TR30` đã fix lịch + tỉ số + thẻ
(tất cả `TrangThai = 'ChuaDienRa'` trong seed, dù tỉ số đã có sẵn -
lưu ý kịch bản demo cần `DaKetThuc` để BXH tính điểm, sẽ update qua SP).

---

## 2. CÁC ĐỐI TƯỢNG NGHIỆP VỤ (ENTITIES)

Sơ đồ quan hệ (BRACK nhọn = cha, trong = con):

```
SAN_VAN_DONG (sân vận động)
    └── DOI_BONG (đội bóng - mỗi đội 1 sân nhà)
            └── MAU_AO_DOI_BONG (3 màu áo: SanNha/SanKhach/Phu)
            └── HOP_DONG_CAU_THU (lịch sử cầu thủ thi đấu tại đội)

CAU_THU (cầu thủ) - bảng GỐC, phân mảnh dọc về master
    └── HOP_DONG_CAU_THU (mỗi cầu thủ có nhiều hợp đồng theo withRouter lịch sử)

TRONG_TAI (trọng tài)

VONG_DAU (10 vòng đấu)

TRAN_DAU (trận đấu) - FK tới VONG_DAU + DOI_BONG + SAN_VAN_DONG
    └── PHAN_CONG_TRONG_TAI (4 trọng tài/trận: Chinh + Bien1 + Bien2 + Ban)
    └── DANG_KY_THI_DAU (22 cầu thủ/trận: 11 chính + 11 dự bị, mỗi đội 1 danh sách)
            └── SU_KIEN_TRAN_DAU (sự kiện trong trận, FK tới DANG_KY_THI_DAU)
```

### 2.1. Các đối tượng danh mục (MASTER DATA)

#### `SAN_VAN_DONG` (Sân vận động)
- Sân nhà của mỗi đội + sân có thể tổ chức trận
- `KhuVuc`: Miền Bắc / Miền Nam (phục vụ thống kê)
- Mỗi sân có sức chứa tối đa → kiểm tra `SoKhach <= SucChua` (theo ràng buộc)

#### `DOI_BONG` (Đội bóng)
- 1 đội = 1 CLB, có HLV và sân nhà cố định
- Không có field "số cầu thủ" vì cầu thủ link qua `HOP_DONG_CAU_THU` (theo thời gian)

#### `MAU_AO_DOI_BONG` (Màu áo)
- Mỗi đội có 3 loại: `SanNha` (áo sân nhà), `SanKhach` (áo sân khách), `Phu` (áo dự phòng)
- Tránh trùng môn khi 2 đội cùng màu → cần đổi áo phụ

#### `CAU_THU` (Cầu thủ)
- `ViTri`: 4 vai trò chính - `ThuMon` (thủ môn), `HauVe` (hậu vệ), `TienVe` (tiền vệ), `TienDao` (tiền đạo)
- `QuocTich`: đa số Việt Nam, có ngoại binh (vd Denilson Junior, Rafaelson, Jeferson Elias...)
- **Master giữ 22 cầu thủ** - danh mục trung tâm, JOIN top scorer

#### `HOP_DONG_CAU_THU` (Hợp đồng)
- **Bảng phức tạp nhất** - quản lý lịch sử chuyển nhượng
- Có 4 trạng thái:
  - `ChinhThuc`: hợp đồng gốc (cầu thủ thuộc biên chế đội)
  - `ChoMuon`: đội hiện tại mượn cầu thủ, đội chủ quản giữ quyền sở hữu
  - `TamDung`: hợp đồng gốc tạm dừng (khi cầu thủ đi mượn ở đội khác)
  - `ThanhLy`: chấm dứt hợp đồng
- `MaDoiChuQuan`: đội sở hữu cầu thủ (vd CAHN sở hữu Rafaelson)
- `MaDoiHienTai`: đội đang thi đấu (có thể khác chủ quản khi cho mượn)
- `SoAo`: áo số (1-35), trong 1 đội không trùng số (Partial Unique Index)
- Tại 1 thời điểm, mỗi cầu thủ chỉ có 1 hợp đồng `ChinhThuc`/`ChoMuon` active

#### `TRONG_TAI` (Trọng tài)
- 4 vai trò trong 1 trận: `Chinh` (trọng tài chính), `Bien1` (trọng tài biên 1),
  `Bien2` (trọng tài biên 2), `Ban` (trọng tài bàn/line)
- `CapBac`: loại "Quốc gia" (mặc định), có thể "FIFA"...

#### `VONG_DAU` (Vòng đấu)
- 10 vòng, mỗi vòng có 3 trận (6 đội → 3 cặp đấu)
- Thứ tự ung dung (1 → 10)

### 2.2. Đối tượng giao dịch (TRANSACTION DATA)

#### `TRAN_DAU` (Trận đấu)
- Bảng **phân mảnh ngang** - mỗi station giữ 5 trận sân nhà của CLB đó
- Mỗi trận có:
  - `MaDoiNha` + `MaDoiKhach`: đội nhà + đội khách
  - `MaSan`: sân tổ chức (thường = sân nhà đội nhà)
  - `MaVong`: vòng đấu (1-10)
  - `NgayGio`: thời gian thi đấu
  - `GiaVe` (ticket price) + `SoKhach` (số khán giả): phục vụ doanh thu
  - `BanThangNha/Khach`: tỉ số
  - `TheVangNha/Khach`, `TheDoNha/Khach`: thẻ phạt
  - `TrangThai`: `ChuaDienRa` (chưa đá) / `DaKetThuc` (đã xong)

#### `SU_KIEN_TRAN_DAU` (Sự kiện trong trận)
- Mỗi bàn thắng/thẻ/phản lối là 1 dòng
- `LoaiSuKien`: `BanThang` (bàn), `PhanLuoi` (phản lưới nhà),
  `TheVang` (thẻ vàng), `TheDo` (thẻ đỏ)
- `PhutGhiNhan`: phút thi đấu (1-120)
- FK tới `DANG_KY_THI_DAU` (MaTran + MaCauThu) - phải đăng ký đá thì mới có sự kiện

---

## 3. PHÂN MẢNH DỮ LIỆU (NHÂN QUẢN TRỊ PHÂN TÁN)

Đây là phần **quan trọng nhất** để hiểu kiến trúc CSDL phân tán:

### 3.1. Phân mảnh NGANG (Horizontal Fragmentation) - theo đội

`TRAN_DAU_CHUYEN_MON` (đã chuẩn hóa BCNF thành bản con của TRAN_DAU,
bỏ các ràng buộc về doanh thu - giữ riêng ở master) - phân mảnh
**theo đội sân nhà** (MadOINha = CLB của station đó).

| Station | Bạn | CLB | Quản lý 5 trận sân nhà |
|---|---|---|---|
| 1 | Tuấn | HNFC | TR01, TR07, TR13, TR19, TR25 |
| 2 | Thông | CAHN | TR02, TR11, TR20, TR22, TR29 |
| 3 | Mạnh Dũng | VTT | TR03, TR08, TR21, TR26, TR28 |
| 4 | Quang Anh | HPFC | TR05, TR12, TR15, TR16, TR23 |
| 5 | Ngọc Bích | NDFC | TR04, TR09, TR14, TR18, TR27 |
| 6 | Minh Dũng | HAGL | TR06, TR10, TR17, TR24, TR30 |
| Master | (Quang) | - | Gộp 6 station = 30 trận |

**Lý do phân mảnh ngang**: Mỗi chi nhánh CLB (vd HNFC) chỉ quan tâm
5 trận sân nhà của mình (vì họ trực tiếp tổ chức vé, trọng tài, sự kiện).
Không cần data trận sân khách (kể cả khi có đội đó đá) vì đó là việc của
CLB chủ nhà khác → giảm tải network cho chi nhánh.

**Phân mảnh theo `MaDoiNha`** vì:
- `MaDoiNha` của station X = CLB X luôn (CHECK constraint trong schema station)
- Không overlap (HK: mỗi trận có 1 MaDoiNha duy nhất)
- Kéo theo key partition: `su_kien_tran_dau.MaTran` cùng station với `tran_dau_chuyen_mon.MaTran`

### 3.2. Phân mảnh DỌC (Vertical Fragmentation) - theo field

`TRAN_DAU` gốc (11 bảng) có nhiều fields: thể thức, sân, ngày,
doanh thu, tỉ số... Phân mảnh dọc:

| Mảnh nào | Fields | Lưu ở đâu | vì sao |
|---|---|---|---|
| `TRAN_DAU_CHUYEN_MON` (mảnh ngang station) | `MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, NgayGio, BanThang*, The*` | Station | Chi nhánh cần quản lý tỉ số, sự kiện |
| `TRAN_DAU_DOANH_THU` (mảnh dọc master) | `MaTran, GiaVe, SoKhach` | Master (Quang) chỉ 1 nơi | Tài chính nhạy cảm, chỉ VFF/trung tâm giữ |

Giải thích nghiệp vụ: **Trung tâm VFF** (master = máy Quang) quản lý tài
chính giải (doanh thu vé), còn **mỗi chi nhánh CLB** (station) tự quản
trận sân nhà mình (tỉ số, sự kiện, trọng tài, danh sách cầu thủ dự bị).

### 3.3. Bảng REPLICA (Sao chép - cho FK)

Mỗi station có bản sao **read-only** của các bảng danh mục:
- `SAN_VAN_DONG`, `DOI_BONG`, `CAU_THU`, `TRONG_TAI`, `VONG_DAU`

**Lý do**: trigger `sp_ghi_nhan_ket_qua_tran_dau` khi user nhập tỉ số
cần check FK tới cầu thủ, đội, sân... Nếu station không có bản sao,
trigger phải query network tới master mỗi lần → chậm, fragile khi
master offline.

**Replica không insert/update phía station** - nếu cần thêm cầu thủ mới
(cầu thủ đăng ký thi đấu mới), admin Trung tâm insert vào master
`public.CAU_THU` (vì bảng này master độc quyền), không phải station.

---

## 4. CÁC GIAO DỊCH & STORED PROCEDURE (5 SP)

Sách gốc có 5 SP - mỗi SP là 1 nghiệp vụ giải:

### 4.1. SP1: `sp_tao_lich_thi_dau` - Lên lịch trận đấu

**Nghiệp vụ**: VFF xếp lịch trận đấu mới

**Check nghiệp vụ**:
1. Đội nhà ≠ đội khách (`MaDoiNha <> MaDoiKhach`)
2. Thể thức vòng tròn: cặp đấu trên sân nhà đó **chưa từng** diễn ra
   (`MaDoiNha, MaDoiKhach` unique)
3. Sân không trùng giờ: trong khoảng 4 giờ lân cận không có trận nào
   cùng sân (`MaSan, NgayGio` trong khoảng ±4 giờ)
4. Lock row trên `SAN_VAN_DONG` để tránh xếp lịch concurrent

### 4.2. SP2: `sp_phan_cong_to_trong_tai` - Phân công tổ trọng tài

**Nghiệp vụ**: VFF chỉ định 4 trọng tài cho 1 trận

**Check nghiệp vụ**:
1. 4 trọng tài phải phân biệt (4 cá nhân khác nhau)
2. Mỗi trận chỉ có 1 tổ (4 dòng `Chinh` + `Bien1` + `Bien2` + `Ban`)
3. Đếm số trận của trọng tài cùng vòng (trigger tự check bằng
   `trg_check_phan_cong_trong_tai`)

Lương: Trọng tài chính 3tr/trận, biên 2tr/trận, bàn 1tr/trận
(tính bằng `fn_tinh_luong_trong_tai_thang`).

### 4.3. SP3: `sp_dang_ky_cau_thu_tran` - Đăng ký cầu thủ thi đấu

**Nghiệp vụ**: HLV đăng ký cầu thủ đá trận X cho đội Y, vai trò chính/dự bị

**Check nghiệp vụ**:
1. Cầu thủ có hợp đồng `ChinhThuc`/`ChoMuon` với đội Y tại ngày diễn ra trận
   (check `HOP_DONG_CAU_THU`: `NgayBatDau <= v_ngay_gio <= NgayKetThuc`)
2. Đăng ký đúng `SoAo` đã gán trong hợp đồng (lấy `v_so_ao` từ `HOP_DONG`)
3. Trigger `trg_check_dang_ky_thi_dau_va_treo_gio` kiểm tra:
   - 11 chính + tối đa 7 dự bị (18 cầu thủ max/đội/trận)
   - Cầu thủ không bị treo giò (đã nhận 2 thẻ vàng hoặc 1 thẻ đỏ trong
     trận trước đó của vòng này)

### 4.4. SP4: `sp_ghi_nhan_ket_qua_tran_dau` - Hoàn tất trận

**Nghiệp vụ**: Trọng tài kết thúc trận, nhập tỉ số, số khán giả, thẻ

**Check nghiệp vụ**:
1. Trận phải tồn tại
2. `NgayGio <= CURRENT_TIMESTAMP` (không kết thúc trận tương lai)
3. Cập nhật `SoKhach, BanThang*, The*` + đổi status `ChuaDienRa` → `DaKetThuc`
4. Trigger `trg_check_khop_ban_thang_va_the` kiểm tra:
   - Số bàn thắng (`BanThangNha + BanThangKhach`) phải khớp số dòng
     `LoaiSuKien='BanThang'` trong `SU_KIEN_TRAN_DAU`
   - Số thẻ vàng/đỏ khớp tương ứng

### 4.5. SP5: `sp_chuyen_nhuong_cho_muon_cau_thu` - Chuyển nhượng cầu thủ

**Nghiệp vụ**: Mở phiên chuyển nhượng, cầu thủ A từ đội X đến đội Y

**Tham số**:
- `p_trang_thai`: `ChoMuon` (mượn, giữ quyền sở hữu đội X) hoặc `ChinhThuc` (chuyển hẳn)

**Check nghiệp vụ**:
1. Lock 2 bản ghi (cầu thủ + đội mới) tránh 2 giao dịch chuyển nhượng concurrent
2. Nếu `ChoMuon`: hợp đồng gốc của A tại X → status `TamDung` (tạm dừng,
   vẫn thuộc sở hữu X)
3. Nếu `ChinhThuc`: hợp đồng cũ → `ThanhLy` (chấm dứt), `NgayKetThuc` = `p_ngay_bat_dau - 1`
4. Insert hợp đồng mới (MaDoiChuQuan = X nếu cho mượn, = Y nếu chuyển hẳn;
   MaDoiHienTai = Y; SoAo = p_so_ao_moi; TrangThai = p_trang_thai)

---

## 5. CÁC VIEW VÀ FUNCTION THỐNG KÊ (REPORTS)

### 5.1. `vw_bang_xep_hang` - BXH mùa giải

**Công thức điểm**:
- Thắng = 3 điểm
- Hòa = 1 điểm
- Thua = 0 điểm

**Tiêu chí xếp hạng** (ưu tiên từ trên xuống):
1. `DiemSo` DESC (điểm cao hơn xếp trên)
2. `HieuSo` DESC (hiệu số bàn thắng-bàn thua cao hơn)
3. `TongBanThang` DESC (nhiều bàn thắng hơn)
4. `SoTranThangSanKhach` DESC (thắng sân khách nhiều hơn - khó hơn)
5. `TongTheDo` ASC (ít thẻ đỏ hơn - fair play)
6. `TongTheVang` ASC (ít thẻ vàng hơn)
7. `TenDoi` ASC (alphabet nếu vẫn hòa)

**Cú pháp CTAS**: UNION ALL (sân nhà + sân khách) để mỗi đội được tính cả 2 vai trò.

### 5.2. `fn_top10_vua_pha_luoi()` - Top 10 vua phá lưới

**Nghiệp vụ**: Báo cáo danh sách 10 cầu thủ ghi nhiều bàn nhất toàn giải.

**Cross-site JOIN**:
- Lấy tất cả `LoaiSuKien='BanThang'` từ `vw_global_su_kien_tran_dau`
  (UNION 6 station)
- JOIN với `CAU_THU` (local master) để hiện tên
- LEFT JOIN hợp đồng hiện tại để biết "cầu thủ đang đá cho đội nào"
  (vd Rafaelson đang đá cho CAHN dù chủ quản có thể khác)

**Lưu ý phân tán**:
- Vì mỗi station chỉ có 5 trận sân nhà, cầu thủ ghi bàn ở TR04 (NDFC sân nhà)
  sẽ được Ngọc Bích insert sự kiện → master gộp qua FDW.
- Master JOIN với `CAU_THU` local (22 cầu thủ) để biết tên → nếu cầu thủ
  không có trong master (vd test row CT99X hoặc CT101/CT102 Ngọc Bích tự thêm)
  thì fn_top10_vua_pha_luoi không hiện (HoTen = NULL).

### 5.3. `fn_tinh_luong_trong_tai_thang` - Lương trọng tài tháng

**Nghiệp vụ**: VFF trả lương cho trọng tài cuối tháng.

**Công thức**:
- Trọng tài CHÍNH: 3.000.000 đ/trận
- Trọng tài BIÊN (1 hoặc 2): 2.000.000 đ/trận
- Trọng tài BÀN: 1.000.000 đ/trận

**Lọc**: với các trận `TrangThai='DaKetThuc'` trong tháng/năm param.

### 5.4. `fn_thong_ke_doanh_thu_san` - Doanh thu theo sân

**Nghiệp vụ**: Báo cáo cuối mùa - sân nào thu được nhiều tiền vé nhất.

**Công thức**: `DoanhThu = SUM(SoKhach * GiaVe)` cho các trận đã kết thúc.

### 5.5. `fn_thong_ke_vong_dau` - Thống kê 1 vòng

**Nghiệp vụ**: Báo cáo vòng đấu X có những trận nào, tỉ số, số khán giả.

---

## 6. RÀNG BUỘC TOÀN VẸN & TRIGGER (INTEGRITY)

### 6.1. CHECK Constraints

| Bảng | Constraint | Ý nghĩa nghiệp vụ |
|---|---|---|
| `SAN_VAN_DONG` | `SucChua > 0` | Sân phải có sức chứa |
| `SAN_VAN_DONG` | `KhuVuc IN ('MienBac','MienNam')` | Chỉ 2 miền VN |
| `CAU_THU` | `ViTri IN (4 vai trò)` | Thủ môn/Hậu vệ/Tiền vệ/Tiền đạo |
| `HOP_DONG_CAU_THU` | `SoAo BETWEEN 1 AND 35` | Số áo trong 1-35 |
| `HOP_DONG_CAU_THU` | `NgayKetThuc >= NgayBatDau` | Hợp đồng phải có hạn kết thúc sau bắt đầu |
| `HOP_DONG_CAU_THU` | `TrangThai IN 4 trạng thái` | ChinhThuc/ChoMuon/TamDung/ThanhLy |
| `TRAN_DAU` | `MaDoiNha <> MaDoiKhach` | Đội nhà khác đội khách |
| `TRAN_DAU` | `UNIQUE(MaDoiNha, MaDoiKhach)` | Cặp đấu 1 lượt sân-khách |
| `TRAN_DAU` | `UNIQUE(MaVong, MaDoiNha)` | 1 đội 1 vòng 1 trận sân nhà |
| `TRAN_DAU` | `UNIQUE(MaVong, MaDoiKhach)` | 1 đội 1 vòng 1 trận sân khách |
| `DANG_KY_THI_DAU` | `SoAoDangKy 1-35` | Số áo đăng ký đá phải trong 1-35 |
| `SU_KIEN_TRAN_DAU` | `PhutGhiNhan 1-120` | Sự kiện trong 120 phút (incl. extra time) |
| `TRAN_DAU_CHUYEN_MON` (station) | `MaDoiNha = 'CAHN'` (vd station 2) | Station X chỉ quản lý trận sân nhà của CLB X |

### 6.2. Triggers (5 cái - trong `02_triggers.sql`)

Mỗi trigger đảm bảo tính toàn vẹn phức tạp mà CHECK constraint không đủ:

1. **`trg_check_dang_ky_thi_dau_va_treo_gio`**: Khi INSERT `DANG_KY_THI_DAU`,
   check 11 chính + tối đa 7 dự bị (18 max), và cầu thủ không bị treo giò
   (2 thẻ vàng/1 thẻ đỏ trong trận trước đó của vòng)

2. **`trg_check_phan_cong_trong_tai`**: Khi INSERT `PHAN_CONG_TRONG_TAI`,
   check trọng tài không trùng lịch trong cùng vòng (1 vòng 3 trận -
   không ai cầm 2 trận cùng vòng)

3. **`trg_check_khop_ban_thang_va_the`**: Khi UPDATE `TRAN_DAU` sang
   `DaKetThuc`, check số bàn thắng/thẻ khớp với dòng `SU_KIEN_TRAN_DAU`
   tương ứng (BanThangNha + BanThangKhach = COUNT(su_kien BanThang))

4. **`trg_check_hop_dong_va_so_ao`**: Khi INSERT/UPDATE `HOP_DONG_CAU_THU`,
   check trùng số áo trong cùng 1 đội khi hợp đồng active

5. (Trigger thứ 5 trong file nếu có - kiểm tra ràng buộc điểm thi đấu)

### 6.3. Partial Unique Index (PostgreSQL đặc trưng)

Hai unique index có điều kiện WHERE - giải quyết bài toán "mỗi cầu thủ
tại 1 thời điểm chỉ có 1 hợp đồng active":

```sql
-- 1. 1 cầu thủ chỉ có 1 hợp đồng active (ChinhThuc/ChoMuon)
CREATE UNIQUE INDEX idx_uq_cauthu_active_contract
ON HOP_DONG_CAU_THU (MaCauThu)
WHERE TrangThai IN ('ChinhThuc', 'ChoMuon');

-- 2. Trong 1 đội không trùng số áo cho hợp đồng active
CREATE UNIQUE INDEX idx_uq_doihientai_soao_active
ON HOP_DONG_CAU_THU (MaDoiHienTai, SoAo)
WHERE TrangThai IN ('ChinhThuc', 'ChoMuon');
```

`Partial Index` khác unique constraint thường: chỉ ràng buộc unique
TRONG TẬP HỢP có điều kiện, với các dòng có `TrangThai='ThanhLy'` thì
cho phép trùng (vì là lịch sử).

---

## 7. VÍ DỤ NGHIỆP VỤ - END-TO-END WORKFLOW

### 7.1. pathway "Tổ chức 1 trận đấu từ A đến Z"

Bước nghiệp vụ → thao tác SQL:

```
1. VFF lên lịch trận
   -> SP1 sp_tao_lich_thi_dau (insert TRAN_DAU)

2. VFF phân công tổ trọng tài
   -> SP2 sp_phan_cong_to_trong_tai

3. HLV đội nhà + khách đăng ký danh sách cầu thủ
   -> SP3 sp_dang_ky_cau_thu_tran (multi times: 11 chính + 7 dự bị mỗi đội)

4. Trận diễn ra, trọng tài ghi từng sự kiện:
   -> INSERT INTO SU_KIEN_TRAN_DAU (MaSuKien, MaTran, MaCauThu, LoaiSuKien, PhutGhiNhan)
   -> VD: ('SK001', 'TR01', 'CT007', 'BanThang', 25)

5. Trọng tài kết thúc trận, nhập tổng kết
   -> SP4 sp_ghi_nhan_ket_qua_tran_dau (BanThangNha, BanThangKhach, TheVang*, TheDo*, SoKhach)
   -> Trigger tự check khớp vs SU_KIEN_TRAN_DAU

6. BXH tự cập nhật
   -> Query vw_bang_xep_hang (recompute UNION sân nhà + sân khách)

7. Top scorer tự cập nhật
   -> Query fn_top10_vua_pha_luoi() (recompute từ vw_global_su_kien_tran_dau)

8. VFF cuối tháng trả lương trọng tài
   -> Query fn_tinh_luong_trong_tai_thang(month, year)

9. Cuối mùa, VFF báo cáo doanh thu từng sân
   -> Query fn_thong_ke_doanh_thu_san
```

### 7.2. pathway "Chuyển nhượng cầu thủ mùa nghỉ"

```
1. Đội Y muốn mượn cầu thủ A từ đội X
   -> SP5 sp_chuyen_nhuong_cho_muon_cau_thu(
        p_ma_hd_moi='HD123', p_ma_cau_thu='CT064',
        p_ma_doi_chu_quan='CAHN', p_ma_doi_moi='HAGL',
        p_so_ao_moi=9, p_ngay_bat_dau='2026-06-01',
        p_ngay_ket_thuc='2027-05-31', p_trang_thai='ChoMuon'
      )
   -> Hợp đồng gốc CT064 tại CAHN: TrangThai ChinhThuc -> TamDung
   -> Hợp đồng mới: CT064 tại HAGL, TrangThai ChoMuon

2. Trong mùa, CT064 đá cho HAGL. fn_top10_vua_pha_luoi LEFT JOIN hợp đồng
   mới nhất để xác định "đội hiện tại".

3. Hết mùa, X gọi về: insert hợp đồng mới TrangThai ChinhThuc, hợp đồng
   ChoMuon cũ chuyển ThanhLy.
```

### 7.3. pathway "Demo phân tán" (khi báo cáo bảo vệ)

```
1. 5 bạn station setup Docker + Postgres + seed data (ai nấy 5 trận)
2. Quang (master) chạy make setup-fdw -> IMPORT FOREIGN SCHEMA
3. Test 1: SELECT COUNT(*) FROM vw_global_tran_dau = 25
4. Test 2: SELECT * FROM fn_top10_vua_pha_luoi() - top scorer toàn giải
5. Test 3: 1 bạn (vd Quang Anh) chạy ./scripts/station-test-insert.sh
   -> Insert trận test (T4abc12345) + sự kiện bàn thắng vào station DB của m
6. Quang chạy SELECT * FROM vw_global_tran_dau WHERE MaTran LIKE 'T4%'
   -> Thấy ngay row mới (FDW pull real-time)
7. Test 4: Quang INSERT INTO site4_hpfc.tran_dau_chuyen_mon ....
   -> Push qua FDW, Quang Anh SELECT thấy luôn trên máy anh (write-through)
8. Cleanup: mỗi bạn chạy station-test-cleanup.sh
```

---

## 8. LƯU Ý QUAN TRỌNG KHI BÁO CÁO BẢO VỆ

### 8.1. Nhận diện thiết kế phân tán

- **Mảnh ngang** (`TRAN_DAU_CHUYEN_MON` + `SU_KIEN_TRAN_DAU`): dữ liệu
  phân theo đội sân nhà → mỗi station 5 trận
- **Mảnh dọc** (`TRAN_DAU_DOANH_THU` + `CAU_THU`): master độc quyền
  tài chính + danh mục cầu thủ → JOIN với FDW ở master
- **Replica** (`SAN_VAN_DONG, DOI_BONG...`): station có bản sao để
  trigger/FK chạy local không cần network
- **Foreign Key join cross-DB**: master JOIN CAU_THU local với
  vw_global_su_kien_tran_dau FDW (đây là "distributed join")

### 8.2. Station 3 (Viettel) - đã bổ sung

Ban đầu team thiếu 1 bạn (chỉ có 5 bạn station) nên bỏ Station 3. Sau đó
Mạnh Dũng tham gia → Station 3 (VTT) được bổ sung, hệ thống đủ 6 station = 30 trận.

### 8.3. Tại sao `vw_global_tran_dau` dùng LEFT JOIN với TRAN_DAU_DOANH_THU

Vì `TRAN_DAU_DOANH_THU` lưu 30 trận gốc BTL (cả 6 station).
Test row mới insert không có trong `TRAN_DAU_DOANH_THU` → không có doanh thu.

If INNER JOIN: chỉ hiện trận có cả (tran_dau_chuyen_mon + tran_dau_doanh_thu)
→ test row sẽ bị loại. LEFT JOIN để hiện cả trận chưa có data doanh thu
(GiaVe, SoKhach = NULL).

### 8.4. Vì sao INSERT(route test) qua FDW cần bypass trigger

Bảng `tran_dau_chuyen_mon` ở station có CHECK constraint `MaDoiNha = 'CAHN'`
(vd station 2). Test insert thỏa CHECK vì `MaDoiNha='CAHN'`.

Tuy nhiên, nếu sống trigger BTL `sp_ghi_nhan_ket_qua_tran_dau` sẽ check:
- `DANG_KY_THI_DAU` có 11+7 cầu thủ cho trận này không?
- Cầu thủ test `CT99X` có hợp đồng active với đội không?
- Trận phải tồn tại trong `VONG_DAU` với `MaVong=10` không?

Test row dùng `MaVong=10` (vòng hợp lệ), `MaDoiNha='CAHN'` (CHECK OK),
nhưng `CT99X` không có trong `HOP_DONG_CAU_THU` → trigger chặn.

Script `station-test-insert.sh` INSERT thẳng vào bảng, không gọi SP4
trigger → bypass được trigger, test row ghi OK.

### 8.5. Tại sao station có bảng CAU_THU nhưng "không đăng ký" với master

`IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau)`
- Chỉ 2 bảng được master trỏ tới qua FDW
- Các bảng replica khác (`CAU_THU`, `DOI_BONG`, `SAN_VAN_DONG`, ...) ở station
  chỉ để trigger chạy FK join local, master không query qua FDW
- Nếu thêm cầu thủ mới vào giải: insert vào **master `public.CAU_THU`**
  (master độc quyền), không phải station. Station đồng bộ qua replication
  (ở BTL gốc) hoặc qua init script (ở repo mình).

---

## 9. CÂU HỎI THƯỜNG GẶP (PHẢN BIỆN CÓ THỂ HỎI)

### Q1: Tại sao BXH có 6 đội?

A: Vì mỗi đội tham gia 5 trận sân nhà + 5 trận sân khách = 10 trận/đội.
Tổng = 6 đội * 5 trận sân nhà = 30 trận (1 đội đá 10 trận). Mỗi đội xuất hiện
trong BXH qua cột MaDoiNha (5 trận sân nhà) + MaDoiKhach (5 trận sân khách).

### Q2: Trận sân khách của HNFC (vd TR04: NDFC vs HNFC) lưu ở đâu?

A: Ở **station 5** (Ngọc Bích - NDFC) vì `MaDoiNha='NDFC'`. HNFC là khách
trong trận này → HNFC station (Tuấn) không lưu. Master truy vấn được
qua FDW vì trận đó đã xếp mảnh ngang về station 5.

### Q3: Tại sao top scorer có HoTen=NULL?

A: Vì `fn_top10_vua_pha_luoi()` JOIN `vw_global_su_kien_tran_dau` với
`CAU_THU` local master. Nếu MaCauThu không có trong master CAU_THU (vd
test player CT99X, hoặc Ngọc Bích insert CT101/CT102 vào station local)
→ JOIN không khớp → không hiện.

### Q4: Nếu 1 station offline, master query được không?

A: Tùy query:
- Query trực tiếp `site2_cahn.tran_dau_chuyen_mon` → ERROR
  "could not connect to server srv_thong_cahn"
- Query `vw_global_tran_dau` (UNION ALL 6 station) → ERROR vì UNION
  cố query cả schema offline
- Master local tables (`cau_thu`, `tran_dau_doanh_thu`) → vẫn OK

Đây là **trade-off** của FDW: không có sẵn "failover" hay "partial result",
hoặc là all hoặc nothing cho view query. Tránh bằng cách setup
`connect_timeout '5'` để fail nhanh.

### Q5: FDW 2 chiều read + write, có ghi ngược qua station không?

A: Có. `postgres_fdw` hỗ trợ INSERT/UPDATE/DELETE trên foreign table nếu:
1. User mapping có quyền tương ứng (mặc định `postgres` superuser → có)
2. Bảng remote không phải view hoặc computed
3. FK/CHECK constraint của remote DB cũng áp dụng (insert có thể fail nếu
   vi phạm constraint của station)

`station-test-insert.sh` cụ thể insert **directly** vào station DB. Nhưng
có thể insert qua FDW từ master - test đã verify (vd T2TEST1234 insert qua
`site2_cahn.tran_dau_chuyên chuyên môn` push sang máy Thông).

### Q6: Nếu 2 bạn cùng insert test row, có conflict không?

A: Không, vì:
- `MaTran` của station 1 là `T1XXXXXX`, station 2 là `T2XXXXXX` → không trùng
- `MaDoiKhach` của station 1 là `P1XXXXXX`, station 2 là `P2XXXXXX` →
  không trùng UNIQUE(MaDoiNha, MaDoiKhach)
- Mỗi station INSERT vào DB RIÊNG (vleague_hnfc, vleague_cahn,...) →
  không share table,Lock row không liên quan

---

## 10. THUẬT NGỮ NGHIỆP VỤ GLOSSARY

| Thuật ngữ | Ý nghĩa |
|---|---|
| VFF | liên đoàn bóng đá Việt Nam (chủ quản giải - master = Quang) |
| CLB | Câu lạc bộ bóng đá (HNFC, CAHN, VTT...) |
| Trận đấu sân nhà | Trận do CLB tổ chức tại sân nhà mình (vd HNFC vs HPFC tại HĐ1) |
| Trận đấu sân khách | Trận CLB đi đá ở sân đối phương (vd HPFC vs HNFC tại HĐ1 từ góc HPFC) |
| Sân Hàng Đẫy | Sân của Hà Nội FC + Công An HN (2 CLB dùng chung) |
| Sân Mỹ Đình | Sân Viettel (Thể Công), sức chứa 40k chỗ |
| Thể thức vòng tròn 2 lượt | Mỗi đội gặp 5 đội kia 2 lần (sân nhà + sân khách) = 10 trận/đội |
| Cầu thủ đăng ký | Danh sách 18 cầu thủ đá 1 trận (11 chính + 7 dự bị) |
| Treo giò | Cầu thủ bị 2 thẻ vàng/1 thẻ đỏ trận trước → không được đá trận sau |
| Phản lưới (PhanLuoi) | Bàn do cầu thủ ghi vào lưới nhà mình |
| Áo chính thức | Áo đấu sân nhà (SanNha) hoặc sân khách (SanKhach) |
| Áo dự phòng (Phu) | Áo đổi khi 2 đội cùng màu áo chính |
| Chuyển nhượng | Cầu thủ đổi đội (hợp đồng mới) |
| Cho mượn | Cầu thủ đá cho đội khác tạm thời, CLB chủ quản giữ quyền sở hữu |
| Top scorer / Vua phá lưới | Cầu thủ ghi nhiều bàn thắng nhất giải |
| BXH | Bảng xếp hạng mùa giải (theo điểm > hiệu số > bàn thắng > thẻ) |
| Trọng tài chính | Trọng tài cầm còi, 3tr/trận lương |
| Trọng tài biên | 2 người cầm cờ biên (Bien1, Bien2), 2tr/trận lương |
| Trọng tài bàn | 1 người cầm cờ line bàn, 1tr/trận lương |

---

Tài liệu này chỉ nội bộ - cho hiểu nghiệp vụ. KHÔNG push.
