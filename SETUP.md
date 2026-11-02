# SETUP - Hệ CSDL phân tán V-League (postgres_fdw)

Hướng dẫn chi tiết thiết lập hệ thống 1 Master + 6 Station qua `postgres_fdw`, dùng ZeroTier VPN mesh cho kết nối xuyên mạng.

## Mục lục

1. [Tổng quan kiến trúc](#1-tong-quan-kien-truc)
2. [Yêu cầu môi trường](#2-yeu-cau-moi-truong)
3. [Setup Master (máy bạn - admin)](#3-setup-master)
4. [Setup Station cho bạn bè (Windows)](#4-setup-station-windows)
5. [Setup Station cho bạn bè (Linux/Mac)](#5-setup-station-linuxmac)
6. [ZeroTier VPN mesh](#6-zerotier-vpn-mesh)
7. [Setup FDW từ Master tới 6 Station](#7-setup-fdw)
8. [Verify hệ thống](#8-verify)
9. [Demo test khi bảo vệ](#9-demo-test)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Tổng quan kiến trúc

### Lược đồ phân mảnh

| Loại phân mảnh | Bảng | Vị trí | Mô tả |
|---|---|---|---|
| Mảnh dọc | `TRAN_DAU_DOANH_THU` (MaTran, GiaVe, SoKhach) | Chỉ Master | Tài chính giải - chỉ VFF nắm |
| Mảnh ngang nguyên thủy | `SAN_VAN_DONG` theo `KhuVuc IN ('MienBac','MienNam')` | Station theo region | BTL-CSDL spec |
| Mảnh ngang dẫn xuất cấp 1 | `TRAN_DAU_CHUYEN_MON` (SEMI-JOIN SAN theo MaSan) | Mỗi Station 5 trận sân nhà | 30 trận / 6 station |
| Mảnh ngang dẫn xuất cấp 2 | `SU_KIEN_TRAN_DAU` (SEMI-JOIN TRAN_DAU_CHUYEN_MON) | Theo station | 166 sự kiện tổng |
| Danh mục nhân bản | SAN_VAN_DONG, DOI_BONG, CAU_THU, TRONG_TAI, VONG_DAU | Cả Master lẫn Station | Read-only replica trên station |

### Vai trò 6 thành viên

| STATION_ID | CLB | DB Name | Trận sân nhà | ZeroTier IP | Người phụ trách |
|---|---|---|---|---|---|
| - | Master | `vleague_master` | 0 (chỉ tài chính + fdw) | `10.147.17.10` | Nguyễn Ngọc Quang |
| 1 | HNFC (Hà Nội FC) | `vleague_hnfc` | TR01, TR07, TR13, TR19, TR25 | `10.147.17.11` | (Quang kiêm) |
| 2 | CAHN (Công An Hà Nội) | `vleague_cahn` | TR02, TR11, TR20, TR22, TR29 | `10.147.17.12` | Hoàng Anh Tuấn |
| 3 | VTT (Viettel) | `vleague_viettel` | TR03, TR08, TR21, TR26, TR28 | `10.147.17.13` | Mạnh Dũng |
| 4 | HPFC (Hải Phòng) | `vleague_haiphong` | TR05, TR12, TR15, TR16, TR23 | `10.147.17.14` | Hồ Quang Anh |
| 5 | NDFC (Nam Định) | `vleague_namdinh` | TR04, TR09, TR14, TR18, TR27 | `10.147.17.15` | Ngọc Bích |
| 6 | HAGL | `vleague_hagl` | TR06, TR10, TR17, TR24, TR30 | `10.147.17.16` | Minh Dũng |

---

## 2. Yêu cầu môi trường

**Master (máy bạn)**:
- Docker Desktop >= 4.x hoặc Docker Engine >= 24
- Docker Compose v2
- `make` (macOS/Linux có sẵn; Windows cài qua `winget install GnuWin32.Make` hoặc dùng WSL)
- ZeroTier client (xem ZEROTIER.md)
- Git

**Station (máy bạn bè)**:
- Docker Desktop
- ZeroTier client
- Git (tùy chọn, script Windows tự cài)

Không cần PostgreSQL cài trực tiếp trên host - tất cả chạy trong Docker container.

---

## 3. Setup Master

Trên máy bạn (admin).

```bash
git clone -b btl-fdw-import https://github.com/GnauqTheBeast/football-station.git
cd football-station

# 1. Tạo network Docker (chỉ 1 lần)
docker network create football-net

# 2. Sửa .env.master nếu cần (mặc định OK cho dev local):
cat .env.master
# STATION1_HOST=station1 ... (sẽ override bằng IP ZeroTier khi triển khai thực)

# 3. Up master container
make up                          # hoặc: docker compose --env-file .env.master up -d
# Master healthy trong ~10s, init-data.sql chạy (load TRAN_DAU_DOANH_THU + CAU_THU)

# 4. Verify data master local
docker exec football-master psql -U postgres -d vleague_master -c "SELECT COUNT(*) FROM tran_dau_doanh_thu;"
#  -> 30 (matches doanh thu 30 tran)
docker exec football-master psql -U postgres -d vleague_master -c "SELECT COUNT(*) FROM cau_thu;"
#  -> 22 (danh muc cau thu de tra cuu vua pha luoi)
```

Lúc này master **chưa có`vw_global_tran_dau`** - cần chờ 6 station healthy qua ZeroTier rồi `make setup-fdw`.

---

## 4. Setup Station (Windows)

Mỗi bạn bè làm trên máy mình:

```powershell
# PowerShell Run as Administrator
# Tải scripts/setup-station.ps1 về hoặc chay 1 lệnh inline:
irm https://raw.githubusercontent.com/GnauqTheBeast/football-station/btl-fdw-import/scripts/setup-station.ps1 | iex
```

Script tự động:
1. Cài Docker Desktop / git nếu thiếu
2. Clone repo về `football-station/`
3. Tạo docker network `football-net`
4. Hỏi **STATION_ID** (1..6 - match CLB nào)
5. Tạo `.env.station` với `POSTGRES_DB` đúng (vd station2=CAHN → `vleague_cahn`)
6. `docker compose -f docker-compose.station.yml --env-file .env.station -p football-station<N> up -d`
7. Đợi healthy, kiểm tra data
8. Lấy **IP ZeroTier** của máy bạn, in ra hướng dẫn báo admin master

Sau khi script hoàn tất:
- Station container `football-station<N>` đang chạy, port `5431`
- DB đã có 5 trận + ~25 sự kiện (data verbatim từ BTL-CSDL)
- Bạn báo admin master: *"Tôi là station 2 (CAHN), IP ZeroTier của tôi `10.147.17.12`"*

---

## 5. Setup Station (Linux/Mac)

```bash
git clone -b btl-fdw-import https://github.com/GnauqTheBeast/football-station.git
cd football-station
docker network create football-net

# Copy template
cp .env.station.example .env.station
# Sua 2 dong:
#   STATION_ID=2
#   POSTGRES_DB=vleague_cahn          # (match STATION_ID)
$EDITOR .env.station

# Up station
docker compose -f docker-compose.station.yml \
  --env-file .env.station \
  -p football-station2 up -d

# Verify
docker exec football-station2 psql -U postgres -d vleague_cahn -c \
  "SELECT COUNT(*) FROM tran_dau_chuyen_mon; SELECT COUNT(*) FROM su_kien_tran_dau;"
```

---

## 6. ZeroTier VPN mesh

Xem **ZEROTIER.md** đầy đủ. Tóm lược:

1. Admin (bạn) đăng ký my.zerotier.com, tạo network `Football DDB`, set IP cố định `10.147.17.10` cho máy master.
2. Phát **Network ID** cho 6 thành viên.
3. Mỗi member: cài ZeroTier client, Join Network ID, báo bạn authorize trong admin console.
4. Set IP cố định cho mỗi station: `10.147.17.11` (HNFC), `.12` (CAHN), `.13` (Viettel), `.14` (HPFC), `.15` (NDFC), `.16` (HAGL).

Test ping 2 chiều Master ↔ Station:

```bash
# Master ping từng station:
docker exec football-master sh -c "pg_isready -h 10.147.17.11 -p 5432 -U postgres"
#  -> accepting connections

# Station ping master:
docker exec football-station1 sh -c "pg_isready -h 10.147.17.10 -p 5432 -U postgres"
```

---

## 7. Setup FDW

Trên máy master, sau khi 6 stations đã healthy và ping được:

```bash
# Sửa .env.master: set STATION<N>_HOST = IP ZeroTier của station N
cat .env.master
# STATION1_HOST=10.147.17.11
# STATION2_HOST=10.147.17.12
# STATION3_HOST=10.147.17.13
# STATION4_HOST=10.147.17.14
# STATION5_HOST=10.147.17.15
# STATION6_HOST=10.147.17.16

# Chạy setup-fdw (substitute template + IMPORT FOREIGN SCHEMA):
make setup-fdw
```

`setup-fdw.sh` làm:
1. Substitute `__STATION<N>_HOST__` trong `db/master/20_fdw_setup.sql` bằng giá trị từ env.
2. `docker exec -i football-master psql < template` để chạy:
   - `CREATE EXTENSION postgres_fdw` (đã có từ init)
   - `DROP SCHEMA site1_hnfc..site6_hagl CASCADE; DROP SERVER IF EXISTS srv_* CASCADE;` (idempotent)
   - `CREATE SERVER srv_tuan_hnfc ..` (6 servers, mỗi server trỏ tới 1 station DB qua IP ZeroTier)
   - `CREATE USER MAPPING FOR postgres SERVER srv_* OPTIONS (user 'postgres', password '123456')`
   - `CREATE SCHEMA site1_hnfc .. site6_hagl` (6 schemas local chứa foreign tables)
   - `IMPORT FOREIGN SCHEMA public LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau)` từ 6 servers
   - `CREATE VIEW vw_global_tran_dau` - UNION ALL 6 tran_dau_chuyen_mon + JOIN tran_dau_doanh_thu
   - `CREATE VIEW vw_global_su_kien_tran_dau` - UNION ALL 6 su_kien_tran_dau
   - `CREATE VIEW vw_bang_xep_hang` - BXH từ `vw_global_tran_dau`
   - `CREATE FUNCTION fn_top10_vua_pha_luoi()` - top 10 vua phá lưới

**Idempotent**: Có thể chạy lại nhiều lần, script DROP cũ trước khi CREATE mới. Thích hợp khi station thay đổi IP ZeroTier hoặc thêm station mới.

---

## 8. Verify

```bash
make verify
```

Output mong đợi:

```
=== 1. Đếm trận từ vw_global_tran_dau ===
 tong_tran = 30

=== 2. Đếm sự kiện ===
 tong_su_kien = 166

=== 3. BXH ===
 vitri | madoi | sotrandadau | sotranthang | ... | diemso
     1 | NDFC  |          10 |           8 | ... |     26
     2 | HNFC  |          10 |           6 | ... |     21
     3 | CAHN  |          10 |           4 | ... |     15
     4 | VTT   |          10 |           3 | ... |     13
     5 | HPFC  |          10 |           1 | ... |      4
     6 | HAGL  |          10 |           1 | ... |      4

=== 4. Top 10 vua phá lưới ===
 xephang | macauthu |       hoten       | sobanthang
       1 | CT064    | Rafaelson Bezerra |         13
       ...

=== 5. Phân mảnh: số trận mỗi station ===
 Site1 HNFC    |     5
 Site2 CAHN    |     5
 ...
 Site6 HAGL    |     5
```

---

## 9. Demo test

Khuyến nghị demo theo `db/reference/07_demo_test_queries.sql`. Tóm lược kịch bản demo khi bảo vệ:

### Demo 1: Tính trong suốt vị trí & tái thiết dữ liệu

```sql
-- Master chạy:
-- Đếm tổng trận/khán giả/doanh thu toàn giải = UNION của 6 station DBs
SELECT COUNT(*) AS TongSoTran, SUM(SoKhach) AS TongKhanGia,
       SUM(GiaVe * SoKhach) AS TongDoanhThuVeToanGiai
FROM vw_global_tran_dau;
-- Kết quả: 30 trận, 460k khán giả, ~32 tỷ VND

-- Chi tiết 30 trận hợp nhất từ 6 máy:
SELECT MaTran, MaVong, MaDoiNha, MaDoiKhach, MaSan, BanThangNha, BanThangKhach, GiaVe, SoKhach
FROM vw_global_tran_dau ORDER BY MaVong, MaTran;
```

### Demo 2: Thống kê vua phá lưới phân tán

```sql
SELECT * FROM fn_top10_vua_pha_luoi();
-- Gom nhóm sự kiện bàn thắng từ 6 station + JOIN với CAU_THU master
```

### Demo 3: Cập nhật thời gian thực xuyên mạng

```bash
# Hồ Quang Anh (Station 4 - HPFC) thêm 1 bàn thắng trên máy mình:
docker exec football-station4 psql -U postgres -d vleague_haiphong -c \
  "INSERT INTO su_kien_tran_dau VALUES ('SK999', 'TR15', 'CT082', 'BanThang', 89);"

# Quang (master) chạy lại câu lệnh vua phá lưới tại máy trung tâm:
docker exec football-master psql -U postgres -d vleague_master -c \
  "SELECT * FROM fn_top10_vua_pha_luoi() WHERE macauthu='CT082';"
-- Ngay lập tức thấy Lucao do Break thêm 1 bàn (số bàn tăng từ 6 lên 7)
```

### Demo 4: Số bàn thắng từng station

```sql
SELECT 'Site1 HNFC'    AS Tram, COUNT(*) AS SoBan FROM site1_hnfc.su_kien_tran_dau    WHERE LoaiSuKien='BanThang'
UNION ALL SELECT 'Site2 CAHN',    COUNT(*) FROM site2_cahn.su_kien_tran_dau    WHERE LoaiSuKien='BanThang'
UNION ALL SELECT 'Site3 Viettel', COUNT(*) FROM site3_viettel.su_kien_tran_dau WHERE LoaiSuKien='BanThang'
UNION ALL SELECT 'Site4 HPFC',    COUNT(*) FROM site4_hpfc.su_kien_tran_dau    WHERE LoaiSuKien='BanThang'
UNION ALL SELECT 'Site5 NDFC',    COUNT(*) FROM site5_ndfc.su_kien_tran_dau    WHERE LoaiSuKien='BanThang'
UNION ALL SELECT 'Site6 HAGL',    COUNT(*) FROM site6_hagl.su_kien_tran_dau    WHERE LoaiSuKien='BanThang';
```

---

## 10. Troubleshooting

| Triệu chứng | Nguyên nhân | Khắc phục |
|---|---|---|
| `make setup-fdw` lỗi `could not connect to server "srv_*"` | ZeroTier IP của station chưa đúng / station container chưa healthy | Check `.env.master` STATION`<N>`_HOST = đúng IP ZeroTier. `docker ps` thấy station healthy |
| `IMPORT FOREIGN SCHEMA` trả về 0 tables | Station chưa init data (init-node.sh chưa chạy vì volume đã có data cũ) | `docker compose -p football-station<N> -f docker-compose.station.yml down -v` rồi up lại |
| Master `vw_global_tran_dau` trả về ít hơn 30 dòng | 1 hoặc vài station chưa authorize trong ZeroTier / chưa ping được | Test `docker exec football-master pg_isready -h <ip_zerotier> -p 5432 -U postgres` |
| Station container exit ngay sau khi up | `.env.station` sai POSTGRES_DB không khớp STATION_ID | Xem bảng mapping ở section 1, sửa file .env.station, `down -v` rồi `up` lại |
| Windows: `docker compose` không nhận | Docker Desktop chưa start | Khởi động Docker Desktop, đợi icon tray xanh |
| Lỗi `permission denied` khi `docker exec ... psql` | POSTGRES_USER khác `postgres` | Set `POSTGRES_USER=postgres` trong .env (script Windows mặc định) |
| `pg_hba.conf` reject host fdw | Station PG config mặc định reject remote | Đã sửa qua `command: postgres -c` trong compose - check `docker logs` |
| Station data số trận != 5 | Init file của station N không đúng (đã override file nhầm) | So sánh `db/station_<N>/00_init.sql` với `db/reference/0<N>_worker_*.sql` từ BTL-CSDL |
| Muốn đổi IP ZeroTier của station | Member đổi máy / Re-join ZeroTier | Member chạy `setup-station.ps1` lại, báo admin IP mới, admin sửa `.env.master` rồi `make setup-fdw` |

---

## Reset toàn bộ (khi muôn làm sạch)

```bash
# Master:
make reset        # down -v + up lại (NUKE master DB, init data chạy lại)

# Station (mỗi bạn tự làm):
docker compose -f docker-compose.station.yml -p football-station<N> --env-file .env.station down -v
docker compose -f docker-compose.station.yml -p football-station<N> --env-file .env.station up -d
```

Sau khi reset, chạy lại `make setup-fdw` để master reconnect tới các station fresh.
