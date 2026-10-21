# Netbird - hướng dẫn thiết lập VPN mesh cho team 7 người

Netbird cho phép 7 máy (1 master + 6 station) kết nối trực tiếp với nhau thông qua IP cố định `100.x.x.x`, không cần mở port, hoạt động được bất kể thành viên đang ở WiFi nhà/ quán cafe/ 4G nào. Đây là canvas networking cần thiết khi master và station không ở cùng LAN.

## 1. Tổng quan vai trò

| Vai trò | Số lượng | IP Netbird (đề xuất) | Ghi chú |
|---|---|---|---|
| Master | 1 | `100.x.x.10` (đề xuất set IP cố định) | Bạn - 172.18.20.106 là host |
| Station 1 | 1 | `100.x.x.11` | Member 1 |
| Station 2 | 1 | `100.x.x.12` | Member 2 |
| Station 3 | 1 | `100.x.x.13` | Member 3 |
| Station 4 | 1 | `100.x.x.14` | Member 4 |
| Station 5 | 1 | `100.x.x.15` | Member 5 |
| Station 6 | 1 | `100.x.x.16` | Member 6 |

Subnet Netbird default: `100.64.0.0/10`, bạn có thể tùy chỉnh trong admin console.

## 2. Setup Master (bạn làm 1 lần)

### 2.1 Đăng ký tài khoản Netbird

1. Mở https://app.netbird.io/signup
2. Đăng ký bằng email hoặc Google/GitHub
3. Tạo network mới: vào dashboard -> Network Settings -> đặt tên "Football DDB"
4. Trong **Network Settings -> Routing**:
   - Network Range: giữ `100.64.0.0/10` hoặc đổi sang `100.96.0.0/11`
   - Default DNS: giữ default

### 2.2 Cài Netbird trên máy master (máy bạn)

macOS:

```bash
brew install --cask netbird
# Khởi động ứng dụng Netbird
open -a Netbird
```

Windows (dùng pc khác hoặc team member):

Tải từ https://netbird.io/downloads và cài đặt.

### 2.3 Login và join network

1. Mở ứng dụng Netbird trên máy bạn
2. Login bằng cùng tài khoản vừa đăng ký
3. Chọn network "Football DDB"
4. Netbird cấp 1 IP `100.x.x.x` cho máy bạn

### 2.4 Set IP cố định cho master (khuyến nghị)

Trong admin console https://app.netbird.io -> Peers:

1. Tìm peer Master của bạn
2. Click peer -> **Set static IP** -> nhập `100.64.0.10` (hoặc IP bạn muốn)

Lý do: master cần IP cố định để các station luôn trỏ tới đúng.

### 2.5 Verify ping tới chính mình

```bash
# macOS/Linux:
ip addr show | grep "100\." # xem IP Netbird
ping -c 3 100.64.0.10
```

### 2.6 Mời team member vào network

Trong admin console: **Peers -> Invite peer** -> nhập email từng member -> họ nhận invite qua email.

Có 2 lựa chọn mời:

- **Mời theo email**: gửi link invite tới email member, họ click link và dùng account riêng
- **Setup key** (nhanh hơn): tạo setup key dùng chung - Network Settings -> Setup Keys -> Generate Key. Phát key cho team. Họ dùng xác thực bằng mã OTP.

Khuyến nghị dùng setup key cho nhanh - member không cần tạo account:

1. Network Settings -> Setup Keys -> **Create setup key**
2. Tên: "Football DDB Station Setup"
3. Type: **Reusable** (1 key cho 6 member) hoặc **Single-use** (6 key riêng)
4. Expires: chọn date kết thúc dự án
5. Copy key string

## 3. Setup Station (team member làm, 6 người)

### 3.1 Cài Netbird trên Windows

Tải client từ https://netbird.io/downloads -> chọn Windows -> cài như app bình thường.

### 3.2 Join bằng Setup Key

1. Mở ứng dụng Netbird từ Start Menu
2. Click **Connect to Netbird**
3. Chọn **Login with a Setup Key** (nếu config nâng cao) - HOẶC đơn giản hơn:
   - Member click invite link gửi từ email -> login -> auto-join network
4. Nhập Setup Key mà bạn phát
5. Member sẽ thấy IP `100.x.x.x` được cấp hiển thị trong app

### 3.2 Lấy IP Netbird của member

```powershell
# Chạy trên PowerShell:
ipconfig | Select-String "100\."
#  → ra dòng dạng:  IPv4 Address. . . . . . : 100.64.0.11
```

Member báo lại IP này cho bạn.

### 3.3 Verify kết nối tới master

```powershell
# Trên máy member, ping master:
ping 100.64.0.10
#  → 4 gói reply OK
```

Nếu không ping được:

- Check Netbird app đang connect (icon tray)
- Check firewall Windows chưa chặn interface Netbird
- Báo bạn check master Netbird đang connect

## 4. Cấu hình .env dùng IP Netbird

### 4.1 Master - sửa `.env.master` trên máy bạn

```env
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123
POSTGRES_DB=football
POSTGRES_PORT=5430
NODE_ROLE=master
STATION_ID=0
CONTAINER_NAME=football-master
NETWORK_NAME=football-net
NETWORK_ALIAS=master
# Trỏ tới Station 1 (sửa khi test station khác):
STATION_HOST=100.64.0.11
STATION_PORT=5431
STATION_DB=football
REPLICATION_SLOT=station_slot_s1
```

> Lưu ý: `STATION_HOST` ở `.env.master` chỉ dùng bởi `make subscribe` (legacy master-side pull); với thiết kế hiện tại, station tự đăng ký qua `register-with-master.sh` rồi, nên bạn không cần sửa`.env.master` mỗi station.

### 4.2 Station - `.env.station` thay đổi tùy theo station_id

**Station 1** (`STATION_ID=1`, IP `100.64.0.11`):

```env
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123
POSTGRES_DB=football
POSTGRES_PORT=5431
NODE_ROLE=station
STATION_ID=1
CONTAINER_NAME=football-station
NETWORK_NAME=football-net
NETWORK_ALIAS=station
REPLICATION_SLOT=master_slot_s1
MASTER_HOST=100.64.0.10
MASTER_PORT=5430
MASTER_DB=football
STATION_PUBLIC_HOST=100.64.0.11
STATION_PUBLIC_PORT=5431
STATION_PUBLIC_DB=football
```

**Station 2** (`STATION_ID=2`, IP `100.64.0.12`): copy và sửa 3 dòng:

```env
STATION_ID=2
CONTAINER_NAME=football-station2
NETWORK_ALIAS=station2
POSTGRES_PORT=5432
REPLICATION_SLOT=master_slot_s2
STATION_PUBLIC_HOST=100.64.0.12
STATION_PUBLIC_PORT=5432
```

Lặp lại cho Station 3..6, đổi số tương ứng.

> Lưu ý containers chạy trên cùng máy phải có `POSTGRES_PORT` khác nhau. Nếu mỗi station ở 1 máy riêng, có thể giữ default 5431.

## 5. Setup cho 1 station cụ thể

### 5.1 Trên máy của Station được giao

Tạo file `.env.station_sN` (với N là station_id):

```bash
# Clone repo trước
git clone https://github.com/GnauqTheBeast/football-station.git
cd football-station

# Tạo .env.station từ template trên (đã sửa IP và số station)
```

### 5.2 Khởi động

```bash
# Chạy script bootstrap (PowerShell trên Windows):
# - Sẽ hỏi IP máy trạm và IP master của bạn - nhập IP Netbird thay vì IP LAN
# - Script tự ghi vào .env.station
# - Bạn cần chỉnh STATION_ID trong file này trước khi chạy tiếp
```

**Quan trọng**: script `setup-station.ps1` hiện mặc định `STATION_ID=1` và subscription name cố định`. Để chạy 6 stations song song vào chung 1 master, mỗi station cần `STATION_ID` riêng (1..6) - script tự động sinh tên subscription theo `STATION_ID`:

| `STATION_ID` | Subscription name (master) | Slot name |
|---|---|---|
| 1 | `station1_subscription` | `station1_slot` |
| 2 | `station2_subscription` | `station2_slot` |
| ... | ... | ... |
| 6 | `station6_subscription` | `station6_slot` |

Yêu cầu team member mở `.env.station`, sửa dòng:

```env
STATION_ID = N    # (1..6, mỗi người 1 số khác)
```

rồi chạy `make start-station`.

### 5.3 Đổi port host nếu 2 station trên 1 máy

Nếu 2 station cùng chạy trên 1 máy (vd test gộp), đổi `POSTGRES_PORT` và `CONTAINER_NAME` để không xung đột:

```env
STATION_ID=2
CONTAINER_NAME=football-station2
POSTGRES_PORT=5432
STATION_PUBLIC_PORT=5432
```

## 6. Verify replication trên master (sau khi 6 stations all up)

```bash
# 1 Master + 6 Station subscriptions:
docker exec -e PGPASSWORD=admin123 football-master psql -U admin -d football -c "
SELECT subname, subenabled, subslotname FROM pg_subscription ORDER BY subname;"

# Mong đợi: 6 dòng station1_subscription ... station6_subscription + 1 không (master_subscription
# thực ra là trên station, không phải trên master), nên master chỉ có 6 subscriptions.

# Replication slots:
docker exec -e PGPASSWORD=admin123 football-master psql -U admin -d football -c "
SELECT slot_name, active FROM pg_replication_slots;"

# Walsenders đang connect tới master (= 6 streams):
docker exec -e PGPASSWORD=admin123 football-master psql -U admin -d football -c "
SELECT pid, application_name, client_addr, state FROM pg_stat_replication;"

# Mong đợi: application_name = station1_subscription..station6_subscription,
# client_addr = IP Netbird từng station
```

## 7. Sơ đồ luồng mạng

```text
              [Netbird Mesh 100.x.x.x]
                       │
     ┌─────────────────┼─────────────────┐
     │                 │                 │
 [Master]           [Station 1]       [Station 2..6]
 100.64.0.10        100.64.0.11       100.64.0.12..
     │                 │                 │
     │   match.*       │                 │
     │ <───────────────┤                 │
     │ <──────────────────────────────────┤
     │                 │                 │
     │ ref.* (xuống)   │                 │
     │ ───────────────>                  │
     │ ──────────────────────────────────>│
```

Khác biệt vs 1 LAN: mỗi station/master tự kết nối mesh point-to-point (NAT traversal UDP), không cần forward port ở router. Tốc độ tốt nếu có NAT hole-punching được; nếu không sẽ qua relay server (chậm hơn một chút).

## 8. Lưu ý mạng

- **Netbird IP phải được áp dụng cho `MASTER_HOST` và `STATION_PUBLIC_HOST`** trong `.env` files - không dùng IP LAN 192.168/172.18 nữa.
- **Port Postgres 5430/5431 vẫn cần bind 0.0.0.0 trong container** (đã DEFAULT qua Docker - không làm gì thêm).
- **Firewall Windows/macOS**: Không cần mở port do Netbird dùng UDP mesh. Chỉ cần firewall cho phép Netbird client chạy.
- Nếu thành viên ở sau các corporate VPN/strict NAT có thể cần dùng Netbird relay (turn on "Use relay" trong admin console → Setup Default DNS).
- Subnet `100.64.0.0/10` của Netbird không xung đột với 172.18.x.x subnet của internal docker bridge - sạch.

## 9. Test end-to-end qua Netbird

### 9.1 Từ Station 1, kiểm tra tới master

```bash
# Test port master mở:
nc -zv 100.64.0.10 5430
#  → Connection succeeded

# Test Postgres reachability:
psql -h 100.64.0.10 -p 5430 -U admin -d football -c "SELECT 1;"
#  → 1
```

### 9.2 Từ Master, ping ngược Station 1

```bash
# Master -> Station 1:
docker exec football-master sh -c 'pg_isready -h 100.64.0.11 -p 5431 -U admin -d football'
#  → accepting connections
```

Nếu "no response" - station member check:
1. Docker container station đang chạy không (docker ps thấy football-station)?
2. Netbird app connect thành công không (icon tray màu xanh)?
3. Port 5431 có đang listen (docker ps thấy `0.0.0.0:5431->5432`)?

### 9.3 Replication test mỗi station

Lặp lại 6 lần (mỗi station làm):

```bash
# Trên station N - ghi match_result:
docker exec -e PGPASSWORD=admin123 football-station-N \
  psql -U admin -d football -c "
INSERT INTO match.match_result(station_id, fixture_id, played_at, home_goals, away_goals, attendance, ticket_price)
VALUES (N, 1, now() - interval '1 hour', 2, 1, 5000, 100000);"

# Trên master - kiểm tra:
sleep 2
docker exec -e PGPASSWORD=admin123 football-master psql -U admin -d football -c "
SELECT station_id, fixture_id, played_at FROM match.match_result ORDER BY station_id;"
#  → thấy 6 dòng cho station1..6
```

## 10. Troubleshooting Netbird

| Triệu chứng | Nguyên nhân | Khắc phục |
|---|---|---|
| `Host is unreachable` trong Netbird IP | Netbird app chưa connect | Member mở app, click Connect; check DNS config không chặn `*.netbird.cloud` |
| `connection refused` thay vì unreachable | Netbird OK, container station chưa chạy | Member chạy `make start-station` |
| IP Netbird không thấy trong `ipconfig` | Client Netbird chưa install driver | Reinstall client với admin quyền |
| Ping OK nhưng `pg_isready` fail | Postgres có firewall داخل station chặn Netbird interface | Member chạy `netsh advfirewall firewall add rule name="Allow ICMPv4" protocol=icmpv4:8,any dir=in action=allow` (đã có trong setup-station.ps1) |
| Master thấy `client_addr=100.x` trong pg_stat_replication | Replication đang qua Netbird OK | Bình thường - đúng luồng |
| Master thấy `client_addr=172.18.x` | Replication ĐANG QUA docker bridge, không qua Netbird | Cần check lại `MASTER_HOST`/`STATION_PUBLIC_HOST` đã trỏ IP Netbird chưa |
| Ping cóPacket loss cao | Connection fallback qua relay server | Trong admin console -> Setup Default DNS -> bằng relay; hoặc báo member đổi mạng |
