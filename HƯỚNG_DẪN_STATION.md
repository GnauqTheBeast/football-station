# HƯỚNG DẪN CHẠY TRẠM (STATION) - cho 5 bạn còn lại

> **Mỗi bạn được giao 1 CLB cụ thể. Phần này nói rõ bạn chạy máy trạm (station) nào và nhập lệnh gì.**
>
> **Máy master (Trung tâm) ở máy Quang - IP ZeroTier: `10.19.227.12`**
>
> Kiến trúc: `postgres_fdw` - master IMPORT FOREIGN SCHEMA từ 6 station. Bạn không cần biết cái đó, chỉ cần làm đúng theo hướng dẫn bên dưới.

---

## 1. VAI TRÒ CỦA BẠN (ĐỌC ĐÚNG MỤC CỦA MÌNH)

### Tuấn - Station 1 (HNFC - Hà Nội FC)

| | |
|---|---|
| **STATION_ID** | `1` |
| **CLB** | HNFC (Hà Nội FC) |
| **Sân nhà** | Hàng Đẫy |
| **DB name** | `vleague_hnfc` |
| **Trận quản lý** | TR01, TR07, TR13, TR19, TR25 (5 trận sân nhà HNFC) |

### Thông - Station 2 (CAHN - Công An Hà Nội)

| | |
|---|---|
| **STATION_ID** | `2` |
| **CLB** | CAHN (Công An Hà Nội) |
| **Sân nhà** | Hàng Đẫy |
| **DB name** | `vleague_cahn` |
| **Trận quản lý** | TR02, TR11, TR20, TR22, TR29 (5 trận sân nhà CAHN) |

### Mạnh Dũng - Station 3 (VTT - Viettel)

| | |
|---|---|
| **STATION_ID** | `3` |
| **CLB** | VTT (Viettel - Thể Công) |
| **Sân nhà** | Quốc Gia Mỹ Đình |
| **DB name** | `vleague_viettel` |
| **Trận quản lý** | TR03, TR08, TR21, TR26, TR28 (5 trận sân nhà Viettel) |

### Quang Anh - Station 4 (HPFC - Hải Phòng FC)

| | |
|---|---|
| **STATION_ID** | `4` |
| **CLB** | HPFC (Hải Phòng FC) |
| **Sân nhà** | Lạch Tray |
| **DB name** | `vleague_haiphong` |
| **Trận quản lý** | TR05, TR12, TR15, TR16, TR23 (5 trận sân nhà HPFC) |

### Ngọc Bích - Station 5 (NDFC - Nam Định)

| | |
|---|---|
| **STATION_ID** | `5` |
| **CLB** | NDFC (Thép Xanh Nam Định) |
| **Sân nhà** | Thiên Trường |
| **DB name** | `vleague_namdinh` |
| **Trận quản lý** | TR04, TR09, TR14, TR18, TR27 (5 trận sân nhà NDFC) |

### Minh Dũng - Station 6 (HAGL - Hoàng Anh Gia Lai)

| | |
|---|---|
| **STATION_ID** | `6` |
| **CLB** | HAGL (Hoàng Anh Gia Lai) |
| **Sân nhà** | Pleiku |
| **DB name** | `vleague_hagl` |
| **Trận quản lý** | TR06, TR10, TR17, TR24, TR30 (5 trận sân nhà HAGL) |

> **Tổng: 6 × 5 = 30 trận phân mảnh ngang. Master gộp tất cả qua FDW**.

---

## 2. SETUP LẦN ĐẦU (chỉ làm 1 lần)

### Windows (recommend)

```powershell
# Mở PowerShell Run as Administrator, paste 1 lệnh này:
irm https://raw.githubusercontent.com/GnauqTheBeast/football-station/btl-fdw-import/scripts/setup-station.ps1 | iex
```

Script tự động:
- Cài Docker Desktop nếu thiếu (sau khi cài xong **phải restart máy** để Docker chạy, rồi mở lại PowerShell admin chạy lại script)
- Cài git nếu thiếu
- Clone repo về `football-station\`
- Tạo docker network `football-net`
- Hỏi bạn **STATION_ID** - **NHẬP ĐÚNG SỐ CỦA BẠN (1-6) theo bảng mục 1**
- Tự tạo `.env.station` với `POSTGRES_DB` khớp STATION_ID
- Up container, đợi healthy, in ra IP ZeroTier của máy bạn

### Linux / macOS

```bash
# 1. Clone repo
git clone -b btl-fdw-import https://github.com/GnauqTheBeast/football-station.git
cd football-station

# 2. Tạo network (chỉ 1 lần)
docker network create football-net

# 3. Copy template .env
cp .env.station.example .env.station
```

Sửa `.env.station` theo đúng STATION_ID của bạn (xem mục 1 để biết DB name):

| Nếu bạn là... | `.env.station` cần có |
|---|---|
| Tuấn | `STATION_ID=1` + `POSTGRES_DB=vleague_hnfc` |
| Thông | `STATION_ID=2` + `POSTGRES_DB=vleague_cahn` |
| Mạnh Dũng | `STATION_ID=3` + `POSTGRES_DB=vleague_viettel` |
| Quang Anh | `STATION_ID=4` + `POSTGRES_DB=vleague_haiphong` |
| Ngọc Bích | `STATION_ID=5` + `POSTGRES_DB=vleague_namdinh` |
| Minh Dũng | `STATION_ID=6` + `POSTGRES_DB=vleague_hagl` |

File `.env.station` hoàn chỉnh mẫu (ví dụ Thông - station 2):

```env
STATION_ID=2
NODE_ROLE=station
POSTGRES_USER=postgres
POSTGRES_PASSWORD=123456
POSTGRES_DB=vleague_cahn
POSTGRES_PORT=5431
NETWORK_NAME=football-net
```

---

## 3. KHỞI ĐỘNG STATION

### Linux / Mac

```bash
# Trong thư mục football-station/:
docker compose -f docker-compose.station.yml \
  --env-file .env.station \
  -p football-station<STATION_ID> up -d
```

Ví dụ **Thông (station 2)** chạy:

```bash
docker compose -f docker-compose.station.yml --env-file .env.station -p football-station2 up -d
```

### Windows (nếu dùng script setup-station.ps1)

Script đã tự chạy lệnh này. Container `football-station<N>` đang healthy rồi.

---

## 4. KIỂM TRA CONTAINER ĐANG CHẠY

```bash
docker ps --filter "name=football-station"
```

Output mong đợi (ví dụ Thông):

```
CONTAINER ID   IMAGE              STATUS                    NAMES
abc123def456   postgres:16-alpine Up 30 seconds (healthy)   football-station2
```

Nếu chưa healthy (hiện `health: starting`), đợi thêm 5-10 giây và chạy lại lệnh trên.

---

## 5. LẤY IP của máy bạn → GỬI CHO QUANG (master)

**Bắt buộc**, vì Quang cần IP của bạn để master connect tới station qua FDW.

### Linux / Mac

```bash
# Cách 1: nếu dùng ZeroTier
ip addr | grep "10.147"

# Cách 2: IP LAN
hostname -I
# hoặc:
ifconfig | grep "inet "
```

### Windows (PowerShell)

```powershell
# Nếu dùng ZeroTier:
Get-NetIPAddress | Where-Object { $_.IPAddress -like "10.147.*" }

# Hoặc IP LAN:
ipconfig | Select-String "IPv4"
```

### Gửi tin nhắn cho Quang (master)

> **Template mẫu (copy điền vào):**
>
> "Quang ơi, mình là **<Tên>**, station **<STATION_ID>** (**<CLB>**). IP máy mình là `10.xxx.xxx.xxx`. Cài xong rồi, container đang healthy."

Ví dụ Thông gửi:
> "Quang ơi, mình là Thông, station 2 (CAHN). IP máy mình là `10.147.17.12`. Cài xong rồi, container đang healthy."

Quang sẽ update `.env.master` với IP của bạn và chạy `make setup-fdw` → master có thể query được data của bạn qua FDW.

---

## 6. VERIFY DỮ LIỆU ĐÃ SEED TRONG STATION

```bash
# Linux/Mac:
docker exec football-station<STATION_ID> psql -U postgres -d <db_name> -c \
  "SELECT COUNT(*) FROM tran_dau_chuyen_mon;
   SELECT COUNT(*) FROM su_kien_tran_dau;"
```

Ví dụ **Mạnh Dũng (station 3 - Viettel)**:

```bash
docker exec football-station3 psql -U postgres -d vleague_viettel -c \
  "SELECT COUNT(*) FROM tran_dau_chuyen_mon;
   SELECT COUNT(*) FROM su_kien_tran_dau;"
```

Kết quả mong đợi:
- `tran_dau_chuyen_mon`: **5** (5 trận sân nhà của CLB)
- `su_kien_tran_dau`: **21-31** (tùy CLB)

Xem chi tiết 5 trận của bạn:

```bash
docker exec football-station3 psql -U postgres -d vleague_viettel -c \
  "SELECT MaTran, MaDoiNha, MaDoiKhach, BanThangNha, BanThangKhach FROM tran_dau_chuyen_mon ORDER BY MaTran;"
```

---

## 7. TEST INSERT (khi Quang báo đã setup FDW xong)

Sau khi Quang chạy `make setup-fdw` thành công và báo *"ok rồi, cứ test"*, mỗi bạn chạy:

```bash
./scripts/station-test-insert.sh
```

Script tự:
- Auto-detect STATION_ID của bạn từ container đang chạy (không cần set gì thêm)
- Insert 1 trận test (MaTran = T<N>+hash 8 ký tự - riêng của bạn)
- Insert N bàn thắng cho cầu thủ-test CT99<N> (riêng cho station bạn - để master phân biệt được "đây là test row của máy nào")
- Có random tỉ số nên mỗi máy/mỗi lần chạy ra kết quả khác nhau
- In ra MaTran + hướng dẫn gửi lại cho Quang

Ví dụ chạy xong output sẽ có dạng:

```
=== ▼ KẾT QUẢ (data đã commit vào station 2) ▼ ===

  Vai trò  : Station 2 = Công An Hà Nội (mã CLB CAHN)
  Trận test: T2abc12345  •  CAHN 2-1 MaDoiKhach
  Cầu thủ  : CT992 (RIÊNG cho station 2) ghi 2 bàn
  Host máy : LAPTOP-THONG.local
```

Tin nhắn cho Quang:
> "Mình chay test xong. MaTran=`T2abc12345`, tỉ số CAHN 2-1, CT992 ghi 2 bàn."

---

## 8. QUANG KIỂM TRA QUA MASTER (FDW)

Quang chạy:

```bash
make check-fdw
```

Sẽ thấy test row của tất cả các station đi qua FDW về master:

```
--- 3. Test rows đã arrive master qua FDW ---
       trang        | so_tran_test | danh_sach_ma_tran
--------------------+--------------+--------------------
 Station2 (CAHN)    |            1 | T2abc12345
 Station3 (Viettel) |            1 | T3def67890
 Station4 (HPFC)    |            1 | T4ghi13579
 ...
```

---

## 9. DỌN TEST ROWS (sau khi demo xong)

```bash
./scripts/station-test-cleanup.sh
```

Chỉ xóa test rows của station bạn (station khác không bị ảnh hưởng).

---

## 10. CÁC LỆNH THƯỜNG DÙNG KHÁC

```bash
# Xem log station:
docker logs -f football-station<STATION_ID>

# psql vào station của bạn (để xem/chỉnh data thủ công):
docker exec -it football-station<STATION_ID> psql -U postgres -d <db_name>

# Dừng station (giữ data):
docker compose -f docker-compose.station.yml -p football-station<STATION_ID> down

# Dừng + xóa DB (NUKE - mất data, init lại từ đầu):
docker compose -f docker-compose.station.yml -p football-station<STATION_ID> down -v
docker compose -f docker-compose.station.yml --env-file .env.station -p football-station<STATION_ID> up -d
```

---

## 11. TROUBLESHOOTING

| Triệu chứng | Khắc phục |
|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop chưa start. Mở app Docker Desktop, đợi icon tray xanh |
| Container exit ngay sau up | `.env.station` sai `POSTGRES_DB` (không khớp STATION_ID). Sửa file, `down -v`, up lại |
| `port is already allocated` | Port 5431 đã có app khác dùng. Sửa `POSTGRES_PORT=5432` (hoặc số khác) trong `.env.station` |
| `network football-net not found` | Quên `docker network create football-net`. Chạy lệnh đó trước |
| `setup-station.ps1` báo cần admin | PowerShell phải mở Run as Administrator (chuột phải PowerShell → Run as Administrator) |
| Station healthy nhưng Quang không query được qua FDW | Bạn chưa báo IP hoặc IP ZeroTier sai. Cấp lại IP cho Quang |
| Setup-station.ps1 báo "Need restart after install Docker" | Restart máy, mở Docker Desktop, đợi 1 phút, mở lại PowerShell admin, chạy lại script |
| `pg_isready` báo `no response` từ master | Master container chưa healthy ở máy Quang. Báo Quang kiểm tra `make ps` |

---

## TÓM TẮT NHANH (paste vào chat team)

```
Setup (Windows):    irm https://raw.githubusercontent.com/GnauqTheBeast/football-station/btl-fdw-import/scripts/setup-station.ps1 | iex
Setup (Linux/Mac):  git clone -b btl-fdw-import https://github.com/GnauqTheBeast/football-station.git && cd football-station && docker network create football-net && cp .env.station.example .env.station
                    -> Sửa .env.station theo đúng vai trò (xem HƯỚNG_DẪN_STATION.md mục 1)
Up station:         docker compose -f docker-compose.station.yml --env-file .env.station -p football-station<N> up -d
Báo Quang:          "Mình là <Tên>, station <N> (<CLB>), IP máy mình là 10.xxx"
Test insert:        ./scripts/station-test-insert.sh
Dọn test:           ./scripts/station-test-cleanup.sh
psql vào DB:        docker exec -it football-station<N> psql -U postgres -d <db_name>
```

---

## LƯU Ý QUAN TRỌNG

1. **STATION_ID phải đúng** - mỗi người 1 số khác nhau (1-6). Nhập sai sẽ ghi đè lên station người khác trong cùng máy (hiếm khi xảy ra vì máy khác nhau, nhưng nếu ai chạy 2 container trên 1 máy sẽ lỗi).
2. **POSTGRES_DB phải khớp STATION_ID** - script Windows tự làm, Linux/Mac phải tự sửa file `.env.station`.
3. **Báo IP cho Quang** - bắt buộc, không thì master không kết nối được tới station của bạn qua FDW.
4. **Password mặc định** `123456` - khởi tạo từ script, không đổi (master FDW user mapping dùng pwd này).
5. **Restart máy sau khi cài Docker trên Windows** - Docker Desktop cần daemon bật sau boot.
6. **Kiểm tra healthy trước khi test** - `docker ps` phải thấy `Up X seconds (healthy)`.
