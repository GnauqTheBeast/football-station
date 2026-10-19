# Football DDB — Hướng dẫn khởi động & vận hành

Hệ thống PostgreSQL logical replication giữa **Master** (máy chủ, sở hữu dữ liệu tham chiếu `ref.*`) và **Station** (máy trạm, sở hữu dữ liệu nghiệp vụ `demo.message`). Replication **hai chiều nhưng phân quyền bảng** — không bao giờ loop.

```text
Station  ── demo.message ──>  Master
Master   ── ref.team/ref.match ──>  Station
```

---

## 1. Yêu cầu chung

- Docker Desktop (hoặc Docker Engine) đang chạy trên cả 2 máy.
- Master và Station ở cùng mạng LAN (hoặc VPN Tailscale/ZeroTier) và **ping được IP nhau**.
- **Cấm** sửa cùng một bảng ở cả 2 chiều → sẽ xung đột. Quy tắc sở hữu bảng:

| Bảng | Ai có quyền ghi | Hướng replication |
|---|---|---|
| `demo.message` | Station | Station → Master |
| `ref.team`, `ref.match` | Master | Master → Station |

---

## 2. Thứ tự khởi động (BẮT BUỘC)

> **Master phải up TRƯỚC Station.** Station `start-station.sh` sẽ psql sang master để tạo subscription — nếu master chưa sẵn sàng thì script fail.

### Bước 2.1 — Master (máy chủ, ví dụ `172.18.20.106`)

```bash
cd football-ddb

# Lần đầu: tạo docker network với subnet cố định (tránh xung đột với LAN 172.18.x.x)
docker network create --subnet 10.200.0.0/24 football-net

# Khởi động master
make up-master
# hoặc: docker compose -p football-master --env-file .env.master -f docker-compose.yml up -d

# Đợi healthy (Status phải = "healthy")
docker inspect -f '{{.State.Health.Status}}' football-master
```

Kiểm tra master sẵn sàng:

```bash
docker exec -e PGPASSWORD=admin123 football-master \
  psql -U admin -d football -c "SELECT pubname FROM pg_publication;"
#  → phải thấy: master_publication
```

### Bước 2.2 — Station (máy trạm, ví dụ `172.18.20.9`)

```bash
cd football-station
git pull           # lấy script mới nhất

# Chạy 1 lệnh duy nhất — script tự lo cả 2 chiều:
make start-station
```

`make start-station` sẽ tự động:

1. Tạo/join docker network `football-net` (subnet `10.200.0.0/24`)
2. `docker compose up -d` station container (port `5431`)
3. Đợi postgres healthy
4. Áp dụng migration `/db/common/*.sql` + `/db/station/*.sql` (idempotent)
5. Tạo `master_subscription` trên station (master → station, kéo `ref.*`)
6. **Tự psql sang master** tạo `station_subscription` (station → master, master kéo `demo.message`)
7. In trạng thái subscription cả 2 phía
8. Listen log station — `Ctrl-C` để thoát listen (replication vẫn chạy nền)

> 🟢 Sau bước này **không cần thao tác thủ công nào trên master nữa** — 2 chiều replication đã lên.

---

## 3. Verify 2 chiều đang chạy

Chạy trên **Master**:

```bash
# Subscription trên master (phải có station_subscription):
docker exec -e PGPASSWORD=admin123 football-master \
  psql -U admin -d football -c \
  "SELECT subname, subenabled FROM pg_subscription;"

# Replication slot (active=t là đang streaming):
docker exec -e PGPASSWORD=admin123 football-master \
  psql -U admin -d football -c \
  "SELECT slot_name, active, active_pid FROM pg_replication_slots;"

# Walsender đang kết nối tới master:
docker exec -e PGPASSWORD=admin123 football-master \
  psql -U admin -d football -c \
  "SELECT pid, application_name, client_addr, state FROM pg_stat_replication;"
```

Kết quả mong đợi:

```
 subname             | subenabled
 station_subscription | t

 slot_name   | active | active_pid
 master_slot | t      | <pid>      ← master → station
 station_slot | t     | <pid>      ← station → master

 state=streaming cho cả 2 walsender
```

---

## 4. Test thường xuyên

### 4.1 Station → Master (`demo.message`)

```bash
# Insert trên Station:
docker exec -e PGPASSWORD=admin123 football-station \
  psql -U admin -d football -c \
  "INSERT INTO demo.message(station_id, author, body) VALUES (1, 'test', 'hello from station');"

# Đợi 2s và select trên Master:
sleep 2
docker exec -e PGPASSWORD=admin123 football-master \
  psql -U admin -d football -c \
  "SELECT station_id, local_id, author, body, created_at FROM demo.message ORDER BY created_at DESC LIMIT 5;"
```

→ Phải thấy row "hello from station" trên master.

### 4.2 Master → Station (`ref.team`, `ref.match`)

```bash
# Sửa trên Master:
docker exec -e PGPASSWORD=admin123 football-master \
  psql -U admin -d football -c \
  "UPDATE ref.team SET city='Ho Chi Minh', updated_at=now() WHERE code='HNN';"

# Đợi 2s và select trên Station (query từ master container qua LAN tới station):
sleep 2
docker exec -e PGPASSWORD=admin123 football-master \
  psql -h 172.18.20.9 -p 5431 -U admin -d football -c \
  "SELECT id, name, code, city, updated_at FROM ref.team WHERE code='HNN';"
```

→ Station phải thấy `city='Ho Chi Minh'` và `updated_at` mới.

---

## 5. Shutdown (ngược thứ tự startup)

> **Station down trước, Master down sau.** Tránh station đang giữ slot trên master.

```bash
# Bước 1 — Station:
make stop-station
# hoặc: docker compose -p football-station --env-file .env.station down

# Bước 2 — Master:
make down-master
# hoặc: docker compose -p football-master --env-file .env.master down
```

Volume giữ nguyên → lần up sau luôn có schema + data. **Không** dùng `-v` trừ khi muốn reset toàn bộ.

---

## 6. Reset toàn bộ (khi sửa DDL trong `db/`)

```bash
# Master:
docker compose -p football-master --env-file .env.master down -v
# Station:
docker compose -p football-station --env-file .env.station down -v
# Network:
docker network rm football-net

# Rồi làm lại từ Bước 2.1.
```

Init SQL trong `docker-entrypoint-initdb.d` **chỉ chạy khi volume trống** — `down -v` xóa volume để init chạy lại.

---

## 7. Thêm Station mới (ví dụ Station 2 ở IP `172.18.20.15`)

1. Copy `.env.station` → `.env.station2`, sửa:
   - `STATION_ID=2`
   - `CONTAINER_NAME=football-station2`
   - `POSTGRES_PORT=5432`  *(port host khác station 1)*
   - `NETWORK_ALIAS=station2`
   - `REPLICATION_SLOT=master_slot_s2`
   - `STATION_PUBLIC_HOST=172.18.20.15`
   - `STATION_PUBLIC_PORT=5432`
2. Trên máy Station 2: `ENV_FILE=.env.station2 make start-station`
3. Lưu ý: script hiện dùng subscription name cố định `station_subscription` và slot `station_slot` — cần đổi tên thành `station2_subscription` / `station2_slot` trong `scripts/register-with-master.sh` nếu chạy song song nhiều station vào cùng 1 master. (TODO: parameterize theo `STATION_ID`.)

---

## 8. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Khắc phục |
|---|---|---|
| `Host is unreachable` khi station connect master | Subnet Docker `172.18.x.x` xung đột LAN | `docker network rm football-net && docker network create --subnet 10.200.0.0/24 football-net` |
| `publication "station_publication" does not exist` | Volume cũ chưa có publication | `down -v` rồi up lại (init SQL chỉ chạy khi volume trống) |
| `replication slot "X" already exists` | Slot mồ côi từ lần cũ | `SELECT pg_drop_replication_slot('X')` (chỉ drop khi `active=f`) |
| Station không nhận `ref.*` update | `master_subscription` chưa tạo / drop | Trên station: `docker exec football-station bash /subscribe-master.sh` |
| Master không nhận `demo.message` | `station_subscription` chưa có trên master | Chạy lại `make start-station` trên station (script tự đăng ký) |
| `DROP SUBSCRIPTION` lỗi "cannot run inside transaction" | Chạy trong block transaction | Issue `DROP SUBSCRIPTION` bằng `psql -c` riêng (không phải heredoc) |

---

## 9. Sơ đồ luồng dữ liệu

```text
┌─────────────────────────────┐        ┌─────────────────────────────┐
│  MASTER (máy chủ)           │        │  STATION (máy trạm)         │
│  ref.team, ref.match        │        │  demo.message               │
│                             │        │                             │
│  master_publication ────────┼───────>│  master_subscription        │
│  (publish ref.*)            │  ref.* │  (subscribe ref.*)          │
│                             │        │                             │
│  station_subscription <──────┼────────│  station_publication        │
│  (subscribe demo.message)   │ demo.  │  (publish demo.message)     │
│                             │message │                             │
└─────────────────────────────┘        └─────────────────────────────┘
```

Mỗi bảng có đúng 1 chủ ghi → không loop, không xung đột.

---

## 10. File & thư mục quan trọng

```
football-ddb/
├── docker-compose.yml          # Postgres 16-alpine, wal_level=logical
├── .env.master                  # Env cho master (STATION_HOST trỏ station)
├── .env.station                 # Env cho station (MASTER_HOST + STATION_PUBLIC_*)
├── Makefile                     # up/down/subscribe/verify/start-station/stop-station
├── db/
│   ├── common/                  # Chạy trên mọi node (tạo cả 2 schema)
│   │   ├── 00_demo.sql          # schema demo + demo.message
│   │   └── 10_ref_schema.sql    # schema ref + ref.team/ref.match
│   ├── master/
│   │   └── 10_publication.sql   # CREATE PUBLICATION master_publication
│   └── station/
│       └── 10_publication.sql   # CREATE PUBLICATION station_publication (idempotent)
└── scripts/
    ├── init-node.sh             # Chạy trong container khi khởi tạo (entrypoint)
    ├── subscribe.sh              # Trên master: tạo station_subscription (master→station pull demo.message)
    ├── subscribe-master.sh      # Trên station: tạo master_subscription (master→station pull ref.*)
    ├── register-with-master.sh   # Station tự đăng ký station_subscription trên master
    └── start-station.sh         # 1 lệnh duy nhất cho station: up+migrate+subscribe+register+listen
```

---

## Tóm tắt 30 giây

```bash
# Master (máy bạn):
docker network create --subnet 10.200.0.0/24 football-net
make up-master

# Station (máy bạn bè):
git pull
make start-station

# Xong. 2 chiều replication tự chạy.
```

---

## Cho team member non-tech (không cần bik terminal)

Trên máy trạm, mở Terminal (Spotlight → gõ "Terminal") và dán đúng 1 lệnh:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/GnauqTheBeast/football-station/main/scripts/setup-station.sh)"
```

Script `setup-station.sh` tự động:

1. Cài Homebrew (nếu chưa có)
2. Cài git (nếu chưa có)
3. Clone repo về `~/football-station`
4. Cài & khởi động Docker Desktop (nếu chưa có / chưa chạy) — đợi daemon lên
5. Hỏi 2 câu: IP máy trạm và IP master → viết vào `.env.station` tự động
6. Chạy `make start-station` — up + migration + subscribe 2 chiều + listen log

⚠️ Master phải **đã up trước** (xem Bước 2.1). Nếu chưa, bước 6 sẽ báo "Host is unreachable" — chạy lại bước 6 sau khi master sẵn sàng.

> Có thể chạy lại lệnh này nhiều lần — script idempotent (chỉ update IP trong `.env.station` và pull code mới nhất).
