# ZeroTier - hướng dẫn thiết lập VPN mesh cho team 7 người

ZeroTier cho phép 7 máy (1 master + 6 station) kết nối trực tiếp với nhau thông qua IP cố định trong virtual network, không cần mở port, hoạt động được bất kể thành viên đang ở WiFi nhà/ quán cafe/ 4G nào. Đây là hạ tầng networking cần thiết khi master và station không cùng LAN.

## 1. Tổng quan vai trò

| Vai trò | Số lượng | IP ZeroTier (đề xuất) | Ghi chú |
|---|---|---|---|
| Master | 1 | `10.147.17.10` (đề xuất set IP cố định) | Bạn - 172.18.20.106 là host LAN |
| Station 1 | 1 | `10.147.17.11` | Member 1 |
| Station 2 | 1 | `10.147.17.12` | Member 2 |
| Station 3 | 1 | `10.147.17.13` | Member 3 |
| Station 4 | 1 | `10.147.17.14` | Member 4 |
| Station 5 | 1 | `10.147.17.15` | Member 5 |
| Station 6 | 1 | `10.147.17.16` | Member 6 |

Subnet ZeroTier mặc định khi tạo network: `10.147.17.0/24` (có thể đổi trong admin console). Mỗi network có 1 Network ID dạng 16 ký tự hex (`1a2b3c4d5e6f7g8h`).

## 2. Thiết lập Master (bạn làm 1 lần)

### 2.1 Đăng ký tài khoản ZeroTier

1. Mở https://my.zerotier.com/ -> **Sign Up**
2. Đăng ký bằng email hoặc Google/GitHub
3. Login vào dashboard
4. **Networks** -> **Create Network** -> đặt tên "Football DDB"

### 2.2 Cài ZeroTier trên máy master

macOS (khuyến nghị qua Homebrew):

```bash
brew install --cask zerotier-one

# Bật daemon (cần sudo):
sudo zerotier-cli info                    # kiểm tra daemon đã lên
sudo zerotier-cli join <NETWORK_ID>       # thêm máy vào network - thay NETWORK_ID từ admin console
```

Hoặc tải installer GUI tại https://www.zerotier.com/download/ -> chạy app -> click "Join Network" -> nhập Network ID.

Windows:

Tải https://www.zerotier.com/download/ -> chọn Windows installer -> cài như app bình thường -> mở ZeroTier GUI từ system tray -> **Join Network** -> nhập Network ID.

### 2.3 Authorize peer trong admin console

1. Vào https://my.zerotier.com/ -> **Networks** -> click network "Football DDB"
2. Tab **Members** thấy máy bạn (Node ID = 10 ký tự hex)
3. Check checkbox **"Allow"** (mặc định off) - bước này bắt buộc, nếu không peer không join được
4. Đọc IP cấp cho máy bạn (cột "Managed IP")

### 2.4 Set IP cố định cho master (khuyến nghị)

Trong admin console -> **Members** -> click máy bạn -> cột **Managed IPs**:

1. Click icon edit (bút chì)
2. Xóa IP tự động (nếu có)
3. Add IP: `10.147.17.10/24`
4. Save

Lý do: master cần IP cố định để các station luôn trỏ tới đúng.

### 2.5 Verify ping master và NETWORK_ID

```bash
# macOS/Linux: xem IP ZeroTier của máy bạn
ifconfig | grep -A2 "zt[0-9]"          # tên interface là zt0, zt1, ...

# Test ping IP của chính mình:
ping -c 3 10.147.17.10
```

### 2.6 Mời team member vào network

Không cần mời qua email - chỉ cần phát Network ID cho team. Mỗi member:

1. Cài ZeroTier client (như phần 2.2)
2. Join Network ID (bạn phát)
3. **Báo bạn vào admin console để Authorize peer của họ** (phải làm bước này - mặc định peers chưa authorize sẽ không kết nối được)

> Khác mô hình invite-email: ZeroTier không cần tạo setup key - chỉ chia sẻ Network ID, bạn (admin) authorize mỗi peer. Đơn giản hơn cho team - member không cần account ZeroTier.

## 3. Thiết lập Station (team member làm, 6 người)

### 3.1 Cài ZeroTier trên Windows

1. Tải https://www.zerotier.com/download/ -> chọn Windows installer
2. Cài như app bình thường (admin quyền)
3. Mở ZeroTier GUI từ Start Menu hoặc system tray icon

### 3.2 Tham gia mạng (join network)

1. Click chuột phải icon ZeroTier trong system tray
2. **Join Network** -> nhập Network ID (bạn phát)
3. Báo bạn vào admin console để Authorize node của member đó
4. Sau khi bạn authorize, ZeroTier GUI sẽ hiện network "Football DDB" với trạng thái OK

### 3.3 Lấy IP ZeroTier của member

```powershell
# PowerShell:
ipconfig | Select-String "10\."
#  -> ra dòng dạng: IPv4 Address. . . . . . : 10.147.17.11

# Hoặc PowerShell chi tiết:
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -like "10.147.*" -and $_.PrefixOrigin -eq "WellKnown" } |
  Select-Object IPAddress, InterfaceAlias
```

Member báo lại IP (hoặc bạn xem trong admin console **Members** tab).

### 3.4 Verify kết nối tới master

```powershell
# Trên máy member, ping master:
ping 10.147.17.10
#  -> 4 gói reply OK
```

Nếu không ping được:

- Check ZeroTier GUI đang connect (system tray icon màu xanh)
- Check đã **Authorize** trong admin console
- Check firewall Windows chưa chặn interface ZeroTier
- Báo bạn check master ZeroTier đang connect

## 4. Cấu hình .env dùng IP ZeroTier

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
STATION_HOST=10.147.17.11
STATION_PORT=5431
STATION_DB=football
REPLICATION_SLOT=station_slot_s1
```

> Lưu ý: `STATION_HOST` ở `.env.master` chỉ dùng bởi `make subscribe` (legacy master-side pull); với thiết kế hiện tại, station tự đăng ký qua `register-with-master.sh` rồi, nên bạn không cần sửa `.env.master` mỗi station.

### 4.2 Station - `.env.station` chọn theo station_id

**Station 1** (`STATION_ID=1`, IP `10.147.17.11`):

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
MASTER_HOST=10.147.17.10
MASTER_PORT=5430
MASTER_DB=football
STATION_PUBLIC_HOST=10.147.17.11
STATION_PUBLIC_PORT=5431
STATION_PUBLIC_DB=football
```

**Station 2** (`STATION_ID=2`, IP `10.147.17.12`): copy và sửa các dòng sau:

```env
STATION_ID=2
CONTAINER_NAME=football-station2
NETWORK_ALIAS=station2
POSTGRES_PORT=5432
REPLICATION_SLOT=master_slot_s2
STATION_PUBLIC_HOST=10.147.17.12
STATION_PUBLIC_PORT=5432
```

Lặp lại cho Station 3..6, đổi số tương ứng.

> Lưu ý: containers chạy cùng 1 máy phải có `POSTGRES_PORT` khác nhau. Nếu mỗi station ở 1 máy riêng, có thể giữ default 5431.

## 5. Thiết lập cho 1 station cụ thể

### 5.1 Trên máy của Station được giao

Tạo file `.env.station_sN` (với N là station_id):

```bash
# Clone repo trước:
git clone https://github.com/GnauqTheBeast/football-station.git
cd football-station

# Tạo .env.station từ template đã sửa IP ZeroTier và số station
```

### 5.2 Khởi động

```bash
# Chạy script bootstrap (PowerShell trên Windows):
# - Sẽ hỏi IP máy trạm và IP master - nhập IP ZeroTier thay vì IP LAN
# - Script tự ghi vào .env.station
# - Bạn cần chỉnh STATION_ID trong file này trước khi chạy tiếp
```

**Quan trọng**: script `setup-station.ps1` hỏi `STATION_ID` (1..6, mỗi người 1 số khác nhau) khi chạy. Tên subscription & slot tự động thêm hậu tố theo `STATION_ID`:

| `STATION_ID` | Subscription name (master) | Slot name |
|---|---|---|
| 1 | `station1_subscription` | `station1_slot` |
| 2 | `station2_subscription` | `station2_slot` |
| ... | ... | ... |
| 6 | `station6_subscription` | `station6_slot` |

Script `register-with-master.sh` và `subscribe.sh` đều tự sinh tên này từ `STATION_ID`, không cần sửa script thủ công. Mỗi team member chạy script trên máy mình với `STATION_ID` riêng.

### 5.3 Đổi port host nếu 2 station trên 1 máy

Nếu 2 station cùng chạy trên 1 máy (vd test gộp), đổi `POSTGRES_PORT` và `CONTAINER_NAME` để không xung đột:

```env
STATION_ID=2
CONTAINER_NAME=football-station2
POSTGRES_PORT=5432
STATION_PUBLIC_PORT=5432
```

## 6. Kiểm tra replication trên master (sau khi 6 stations all up)

```bash
# Master + 6 Station subscriptions:
docker exec -e PGPASSWORD=admin123 football-master psql -U admin -d football -c "
SELECT subname, subenabled, subslotname FROM pg_subscription ORDER BY subname;"

# Mong đợi: 6 dòng station1_subscription ... station6_subscription.
# (master không có master_subscription - cái đó nằm trên station dùng để pull ref.*)

# Replication slots:
docker exec -e PGPASSWORD=admin123 football-master psql -U admin -d football -c "
SELECT slot_name, active FROM pg_replication_slots;"

# Walsenders đang kết nối tới master (= 6 streams):
docker exec -e PGPASSWORD=admin123 football-master psql -U admin -d football -c "
SELECT pid, application_name, client_addr, state FROM pg_stat_replication;"

# Mong đợi: application_name = station1_subscription..station6_subscription,
# client_addr = IP ZeroTier từng station (10.147.17.x)
```

## 7. Sơ đồ luồng mạng

```text
              [ZeroTier Mesh 10.147.17.x]
                       |
     +-----------------+-----------------+
     |                 |                 |
 [Master]           [Station 1]       [Station 2..6]
 10.147.17.10       10.147.17.11      10.147.17.12..
     |                 |                 |
     |   match.*       |                 |
     | <---------------+                 |
     | <----------------------------------+
     |                 |                 |
     | ref.* (xuống)   |                 |
     | +-------------->      (replicated)|
     | +---------------------------------->|
```

Khác biệt với 1 LAN: mỗi station/master tự kết nối mesh point-to-point (P2P UDP), không cần forward port ở router. Tốc độ tốt nếu ZeroTier NAT punch được (P2P trực tiếp); nếu không sẽ qua root server (moon/planet) - chậm hơn một chút.

## 8. Lưu ý mạng

- **IP ZeroTier phải được áp dụng cho `MASTER_HOST` và `STATION_PUBLIC_HOST`** trong các file `.env` - không dùng IP LAN 192.168/172.18 nữa.
- **Port Postgres 5430/5431 vẫn cần bind 0.0.0.0 trong container** (đã DEFAULT qua Docker - không làm gì thêm).
- **Firewall Windows/macOS**: không cần mở port do ZeroTier dùng UDP P2P. Chỉ cần firewall cho phép ZeroTier client chạy (thường tự động allow).
- Subnet `10.147.17.0/24` của ZeroTier không xung đột với 172.18.x.x subnet của internal docker bridge - sạch.
- ZeroTier micro-network không cấp DGW (Default Gateway), không ảnh hưởng routing máy host - chỉ tạo 1 virtual interface `zt0`.

## 9. Test end-to-end qua ZeroTier

### 9.1 Từ Station 1, kiểm tra tới master

```bash
# Test port master mở:
nc -zv 10.147.17.10 5430
#  -> Connection succeeded

# Test Postgres reachability:
psql -h 10.147.17.10 -p 5430 -U admin -d football -c "SELECT 1;"
#  -> 1

# Hoặc test từ Docker container station sang master:
docker exec football-station sh -c 'pg_isready -h 10.147.17.10 -p 5430 -U admin -d football'
```

### 9.2 Từ Master, ping ngược Station 1

```bash
# Master -> Station 1:
docker exec football-master sh -c 'pg_isready -h 10.147.17.11 -p 5431 -U admin -d football'
#  -> accepting connections
```

Nếu "no response" - station member check:
1. Docker container station đang chạy không (docker ps thấy football-station)?
2. ZeroTier GUI connect thành công không (system tray icon xanh)?
3. Port 5431 có đang listen (docker ps thấy `0.0.0.0:5431->5432`)?
4. Member đã được **Authorize** trong admin console?

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
#  -> thấy 6 dòng cho station 1..6
```

## 10. Troubleshooting ZeroTier

| Triệu chứng | Nguyên nhân | Khắc phục |
|---|---|---|
| `Host is unreachable` với IP ZeroTier | Peer chưa authorize trong admin console | Vào my.zerotier.com -> **Members** -> check checkbox "Allow" cho peer đó |
| Peer coi như đã joined nhưng không có IP | Daemon ZeroTier chưa chạy | Restart ZeroTier GUI hoặc `sudo zerotier-cli info` để xem daemon |
| `connection refused` thay vì unreachable | ZeroTier OK, container station chưa chạy | Member chạy `make start-station` |
| IP ZeroTier không thấy trong `ipconfig` | Driver ZeroTier chưa install | Reinstall ZeroTier với admin quyền |
| Ping OK nhưng `pg_isready` fail | Postgres có firewall trong station chặn ZeroTier interface | Member chạy `netsh advfirewall firewall add rule name="Allow ICMPv4" protocol=icmpv4:8,any dir=in action=allow` (đã có trong setup-station.ps1) |
| Master thấy `client_addr=10.147.x` trong pg_stat_replication | Replication đang qua ZeroTier OK | Bình thường - đúng luồng |
| Master thấy `client_addr=172.18.x` | Replication ĐANG QUA docker bridge, không qua ZeroTier | Cần check lại `MASTER_HOST`/`STATION_PUBLIC_HOST` đã trỏ IP ZeroTier chưa |
| Ping có packet loss cao | Connection fallback qua moon/planet server | Cài ZeroTier Moon tại máy của bạn để giảm latency - xem ZeroTier docs |

## 11. Tổ chức ZeroTier Moon (tùy chọn, giảm latency)

Nếu team ở cùng khu vực (vd cùng city, cùng ISP) và muốn giảm latency (traffic bị qua planet server chậm), có thể setup 1 ZeroTier Moon tại máy master. Moon là root server riêng của bạn.

Yêu cầu: VPS hoặc máy có public IP có thể port-forward UDP 9993.

```bash
# Trên máy master (vd có public IP):
sudo zerotier-cli info -j | grep identity -A1      # lấy node ID
sudo zerotier-idtool initmoon /var/lib/zerotier-one/identity.public > moon.json
# Edit moon.json để thêm stablePublicEndpoint IP của máy master
sudo zerotier-cli genmoon moon.json                # tạo .moon file
sudo cp 000000000.moon /var/lib/zerotier-one/moons.d/

# Mở port UDP 9993 trên firewall.
# Member join moon:
sudo zerotier-cli orbit <MOON_ID> <MOON_ID>         # trên mỗi station
```

Rồi kế hoạch chi tiết: https://docs.zerotier.com/zerotier/moons
