# Football DDB — Hướng dẫn khởi động & vận hành

Hệ thống PostgreSQL logical replication giữa **Master** (máy chủ, sở hữu dữ liệu tham chiếu `ref.*`) và **Station** (máy trạm, sở hữu dữ liệu trận đấu `match.*`). Replication **hai chiều nhưng phân quyền bảng** — không bao giờ loop.

```text
Station  ── match.match_result, match_squad, match_event ──>  Master
Master   ── ref.* (station, season, round, stadium, team, ...) ──>  Station
```

| Schema | Số bảng | Ai có quyền ghi | Hướng replication |
|---|---|---|---|
| `ref.*` | 12 | Master | Master → Station |
| `match.*` | 3 | Station | Station → Master |

Tham khảo thiết kế đầy đủ: [CSDL phân tán giải bóng đá.md](CSDL%20ph%C3%A2n%20t%C3%A1n%20gi%E1%BA%A3i%20b%C3%B3ng%20%C4%91%C3%A1.md).

---

## 1. Yêu cầu chung

- Docker Desktop (hoặc Docker Engine) đang chạy trên cả 2 máy.
- Master và Station ở cùng mạng LAN (hoặc VPN Tailscale/ZeroTier) và **ping được IP nhau**.
- **Cấm** sửa cùng một bảng ở cả 2 chiều → sẽ xung đột. Quy tắc sở hữu bảng:

| Bảng | Ai có quyền ghi | Hướng replication |
|---|---|---|
| `ref.station`, `ref.season`, `ref.round`, `ref.stadium`, `ref.team`, `ref.team_kit`, `ref.player`, `ref.referee`, `ref.role_pay`, `ref.registration`, `ref.fixture`, `ref.match_referee` | Master | Master → Station |
| `match.match_result`, `match.match_squad`, `match.match_event` | Station | Station → Master |

---

## 2. Thứ tự khởi động (BẮT BUỘC)

> **Master phải up TRƯỚC Station.** Station `make start-station` sẽ psql sang master để tạo subscription — nếu master chưa sẵn sàng thì script fail.

### Bước 2.1 — Master (máy chủ, ví dụ `172.18.20.106`)

```bash
cd football-ddb

# Lần đầu: tạo docker network với subnet cố định (tránh xung đột với LAN 172.18.x.x)
docker network create --subnet 10.200.0.0/24 football-net

# Khởi động master (init-node.sh tự chạy: tạo ref.* + match.* + publications + seed)
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

docker exec -e PGPASSWORD=admin123 football-master \
  psql -U admin -d football -c "SELECT count(*) AS teams FROM ref.team; SELECT count(*) AS fixtures FROM ref.fixture;"
#  → teams=4, fixtures=2 (sau khi seed)
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
4. Áp dụng migration `/db/common/*.sql` (ref.* + match.* + triggers + views) + `/db/station/*.sql` (publication)
5. Tạo `master_subscription` trên station (master → station, kéo `ref.*`) — snapshot seed data trôi từ master xuống
6. **Tự psql sang master** tạo `station_subscription` (station → master, master kéo `match.*`)
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

 slot_name      | active | active_pid
 master_slot_s1 | t      | <pid>       ← master → station (master holds slot for the other side)
 station_slot_s1 | t     | <pid>       ← station → master

 state=streaming cho walsender đang kết nối tới station
```

---

## 4. Test 2 chiều

### 4.1 Station → Master (`match.*`) — qua Makefile

```bash
# Insert match.match_result trên Station (station_id=1, fixture_id=1 đã seed):
make verify-station

# Tương đương SQL:
#   INSERT INTO match.match_result(station_id, fixture_id, played_at, home_goals, away_goals, attendance, ticket_price)
#   VALUES (1, 1, now() - interval '1 hour', 2, 1, 5000, 100000)
#   ON CONFLICT (station_id, fixture_id) DO UPDATE SET ...;

# Đợi 2s và đọc trên master:
docker exec -e PGPASSWORD=admin123 football-master \
  psql -U admin -d football -c \
  "SELECT station_id, fixture_id, played_at, home_goals, away_goals, attendance FROM match.match_result ORDER BY played_at DESC LIMIT 5;"
```

→ Phải thấy row mới trên master.

### 4.2 Master → Station (`ref.*`)

```bash
# Sửa ref.team trên Master:
make verify-master

# Tương đương SQL:
#   UPDATE ref.team SET name = 'Master FC <timestamp>' WHERE team_id = 1;

# Đợi 2s và đọc trên Station (query từ master container qua LAN tới station):
sleep 2
docker exec -e PGPASSWORD=admin123 football-master \
  psql -h 172.18.20.9 -p 5431 -U admin -d football -c \
  "SELECT team_id, name, founded_year FROM ref.team ORDER BY team_id LIMIT 5;"
```

→ Station phải thấy `name` đã đổi.

### 4.3 Trigger constraint (test ràng buộc logic)

Trigger validate ở gốc — replication apply thì skip. Thử trên master:

```bash
# Thử thêm 2 main referees cho cùng fixture → phải FAIL (trigger拒绝):
docker exec -e PGPASSWORD=admin123 football-master psql -U admin -d football -c \
  "INSERT INTO ref.match_referee(fixture_id, referee_id, role)
   SELECT fixture_id, 16, 'main' FROM ref.fixture LIMIT 1;" 2>&1 | tail -3
# → ERROR: Fixture <X>: at most 1 main referee
```

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

`make down` chạy cả 2. Volume giữ nguyên → lần up sau luôn có schema + data. **Không** dùng `-v` trừ khi muốn reset toàn bộ.

---

## 6. Reset toàn bộ (khi sửa DDL trong `db/`)

```bash
# Master:
docker compose -p football-master --env-file .env.master down -v
# Station:
docker compose -p football-station --env-file .env.station down -v
# Network (không bắt buộc — subnet đã đúng):
docker network rm football-net 2>/dev/null
docker network create --subnet 10.200.0.0/24 football-net

# Rồi làm lại từ Bước 2.1.
```

Init SQL trong `docker-entrypoint-initdb.d` **chỉ chạy khi volume trống** — `down -v` xóa volume để init chạy lại. Sau khi reset master, **bắt buộc reset cả station** (vì schema `ref.*` đã thay đổi, station replicate sẽ fail nếu schema cũ lệch).

---

## 7. Thêm Station mới (ví dụ Station 2 ở IP `172.18.20.15`)

> Lưu ý quan trọng: khi thiết kế dùng nhiều station song song, mỗi station phải có `station_id` riêng và mỗi subscription trên master phải dùng tên + slot khác nhau.

1. Copy `.env.station` → `.env.station2`, sửa:
   - `STATION_ID=2`
   - `CONTAINER_NAME=football-station2`
   - `POSTGRES_PORT=5432`  *(port host khác station 1)*
   - `NETWORK_ALIAS=station2`
   - `REPLICATION_SLOT=master_slot_s2`
   - `STATION_PUBLIC_HOST=172.18.20.15`
   - `STATION_PUBLIC_PORT=5432`
2. Sửa `scripts/register-with-master.sh`: đổi `station_subscription` → `station2_subscription`, `station_slot` → `station2_slot` (TODO: parameterize theo `STATION_ID`).
3. Trên máy Station 2: `ENV_FILE=.env.station2 make start-station`

---

## 8. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Khắc phục |
|---|---|---|
| `Host is unreachable` khi station connect master | Subnet Docker `172.18.x.x` xung đột LAN | `docker network rm football-net && docker network create --subnet 10.200.0.0/24 football-net`; restart 2 container |
| `publication "station_publication" does not exist` | Volume cũ chưa có publication | `down -v` rồi up lại (init SQL chỉ chạy khi volume trống) |
| `replication slot "X" already exists` | Slot mồ côi từ lần cũ | `SELECT pg_drop_replication_slot('X')` (chỉ drop khi `active=false`) |
| Station không nhận `ref.*` update | `master_subscription` chưa tạo / drop | Trên station: `docker exec football-station bash /subscribe-master.sh` |
| Master không nhận `match.*` | `station_subscription` chưa có trên master | Chạy lại `make start-station` trên station (script tự đăng ký) |
| `ALTER SUBSCRIPTION ... REFRESH PUBLICATION` báo "new table missing on subscriber" | Thêm bảng master sau khi sub đã tạo | Trên station: `ALTER SUBSCRIPTION master_subscription REFRESH PUBLICATION;` để đăng ký thêm bảng mới |
| `DROP SUBSCRIPTION` lỗi "cannot run inside transaction" | Chạy trong block transaction | Issue `DROP SUBSCRIPTION` bằng `psql -c` riêng (không phải heredoc) |
| `session_replication_role` cảnh báo "trigger được skip" | Bình thường — trigger skip khi apply replication | Đây là cơ chế mong muốn: validate 1 lần tại gốc |

---

## 9. Sơ đồ luồng dữ liệu

```text
┌──────────────────────────────────────┐  match.*  ┌──────────────────────────────────────┐
│  MASTER (máy chủ)                    │ ────────> │  STATION (máy trạm)                  │
│  Sở hữu 12 bảng ref.*                 │           │  Sở hữu 3 bảng match.*                │
│                                      │           │                                      │
│  match.match_result   <─── station_subscription  │  match.match_result  ─── station_publication
│  match.match_squad      (master psql sang master) │  match.match_squad                    │
│  match.match_event     để tạo subscription        │  match.match_event                    │
│                                      │   ref.*   │                                      │
│  ref.station          ─── master_publication ───> │  master_subscription                  │
│  ref.team                          │             │  (station psql sang master tạo)      │
│  ref.player                         │           │                                      │
│  ref.fixture                        │           │                                      │
│  ref.match_referee                  │           │                                      │
│  ... ref.* (12 bảng)                 │           │                                      │
└──────────────────────────────────────┘           └──────────────────────────────────────┘
```

Mỗi bảng có đúng 1 chủ ghi → không loop, không xung đột.

---

## 10. File & thư mục quan trọng

```
football-ddb/
├── docker-compose.yml              # Postgres 16-alpine, wal_level=logical
├── .env.master                      # Env cho master (STATION_HOST trỏ station)
├── .env.station                     # Env cho station (MASTER_HOST + STATION_PUBLIC_*)
├── Makefile                         # up/down/subscribe/verify/start-station/stop-station
├── db/
│   ├── common/                      # Chạy trên mọi node (master + station)
│   │   ├── 10_ref_schema.sql       # schema ref + 12 bảng master
│   │   ├── 20_match_schema.sql     # schema match + 3 bảng station
│   │   ├── 30_triggers.sql          # Trigger ràng buộc logic
│   │   └── 40_views.sql             # View thống kê (xếp hạng, top 10, ...)
│   ├── master/
│   │   ├── 10_publication.sql     # CREATE PUBLICATION master_publication (12 bảng ref.*)
│   │   └── 20_seed.sql             # Seed master (stations, season, teams, players, referees)
│   └── station/
│       └── 10_publication.sql     # CREATE PUBLICATION station_publication (3 bảng match.*)
└── scripts/
    ├── init-node.sh                 # Chạy trong container khi khởi tạo (entrypoint)
    ├── subscribe.sh                 # Trên master: tạo station_subscription (master→station, kéo match.*)
    ├── subscribe-master.sh         # Trên station: tạo master_subscription (station pull ref.*)
    ├── register-with-master.sh      # Station tự đăng ký station_subscription trên master
    ├── start-station.sh             # 1 lệnh duy nhất cho station: up+migrate+subscribe+register+listen
    └── setup-station.ps1           # Bootstrap cho Windows: cài git/Docker, clone, hỏi IP, chạy start-station
```

---

## 11. Thiết kế & ràng buộc đầy đủ

Tham khảo [CSDL phân tán giải bóng đá.md](CSDL%20ph%C3%A2n%20t%C3%A1n%20gi%E1%BA%A3i%20b%C3%B3ng%20%C4%91%C3%A1.md).

Thiết kế implement các ràng buộc như sau:

| Ràng buộc | Cách implement |
|---|---|
| PK, FK, NOT NULL, UNIQUE | Native (sẵn trong DDL) |
| `shirt_no` 1-35, `attendance ≥ 0`, position in (GK,DF,MF,FW), v.v. | Native `CHECK` |
| Player chỉ đ.footerFontSize 1 đội cùng thời điểm | `EXCLUDE gist (player_id =, period &&)` |
| Số áo không trùng trong đội cùng thời điểm | `EXCLUDE gist (team_id =, shirt_no =, period &&)` |
| Team có ≥ 2 màu áo | Trigger `team_kit_min_two_colors` |
| MatchReferee: 1 main + 2 linesman + 1 table | Trigger `match_referee_role_dist` |
| Fixture.kickoff trong round | Trigger `fixture_kickoff_in_round` |
| MatchResult.played_at ≤ now() | Trigger `match_result_played_at_past` |
| MatchSquad ≤ 18/team/match | Trigger `match_squad_checks` |
| Cầu thủ trong squad phải đăng ký cho đội vào ngày đá | Trigger `match_squad_checks` |
| MatchEvent.player phải nằm trong squad | Trigger `match_event_player_in_squad` |
| Tổng goal events ≤ MatchResult tổng goals | Trigger `match_event_goal_count_bounds` + `match_result_goals_ge_events` |
| Verify chính xác goals cuối trận | `SELECT match.verify_match_complete(station, fixture)` — app gọi |
| Registration tối đa 30 người/đội | Trigger `reg_max_30_per_team` |
| Double round-robin (8 đội × 2 lượt = 14 vòng) | App-level |
| Trọng tài tối đa 1 trận/vòng | App-level |
| Số đội chẵn, tối thiểu 6 | App-level |

Trigger fires only at origin (default `ENABLE ORIGIN`), không fire trên subscriber → validate 1 lần tại nơi ghi, replication apply không trigger lại.

---

## 12. Views (master-side reads)

| View | Ý nghĩa |
|---|---|
| `ref.v_standings` | Bảng xếp hạng: P/W/D/L/GF/GA/GD/Pts |
| `ref.v_top_scorers` | Top 10 vua phá lưới |
| `ref.v_referee_pay` | Lương trọng tài theo mùa |
| `ref.v_stadium_revenue` | Doanh thu sân theo mùa |
| `ref.v_round_stats` | Thống kê mỗi vòng (goals, cards) |

Đọc ví dụ (chạy trên master):

```bash
docker exec -e PGPASSWORD=admin123 football-master \
  psql -U admin -d football -c "SELECT * FROM ref.v_standings ORDER BY pts DESC;"

docker exec -e PGPASSWORD=admin123 football-master \
  psql -U admin -d football -c "SELECT * FROM ref.v_top_scorers;"
```

---

## Tóm tắt 30 giây

```bash
# Master (máy bạn):
docker network create --subnet 10.200.0.0/24 football-net
make up-master

# Station (team member — Windows, chạy 1 lệnh):
#  Mở PowerShell admin và dán:
& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing `
  "https://raw.githubusercontent.com/GnauqTheBeast/football-station/main/scripts/setup-station.ps1").Content))

# Xong. 2 chiều replication tự chạy.
```

---

## Cho team member (chỉ Windows)

Trên máy trạm Windows: mở PowerShell **dưới quyền admin** (Nhấn nút Windows → gõ "PowerShell" → click phải → "Run as administrator") và dán đúng 1 lệnh:

```powershell
& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing `
  "https://raw.githubusercontent.com/GnauqTheBeast/football-station/main/scripts/setup-station.ps1").Content))
```

Script `scripts/setup-station.ps1` tự động:

1. Cài winget (nếu thiếu, qua Microsoft Store — App Installer)
2. Cài git (nếu chưa có, qua `winget install Git.Git`)
3. Clone repo về `C:\Users\<bạn>\football-station`
4. Cài Docker Desktop (nếu chưa có, qua `winget install Docker.DockerDesktop`); mở & đợi daemon lên
5. Tạo docker network `football-net` (subnet `10.200.0.0/24`, tránh xung đột LAN `172.18.x`) + mở firewall ICMPv4 cho ping
6. Hỏi 2 câu: **IP máy trạm** + **IP master** → tự ghi vào `.env.station` (có gợi ý IP DHCP, có validate)
7. Chạy: `docker compose up -d` → đợi healthy → migration → subscribe master→station → tự đăng ký station→master trên master → in status → listen logs

⚠️ **Master phải đã up trước** (xem Bước 2.1). Nếu chưa, bước cuối báo "Host is unreachable" — chạy lại lệnh trên sau khi master sẵn sàng.

### Yêu cầu từ team member

- Windows 10 21H1+ hoặc Windows 11 (để có winget)
- Có quyền admin máy (cần cho winget install và Docker Desktop)
- ~5GB disk cho Docker Desktop
- Đang ở cùng mạng LAN với master (hoặc VPN Tailscale/ZeroTier)

### Cài thủ công nếu PowerShell không chạy được

```powershell
# Tải file .ps1 về:
Invoke-WebRequest -OutFile setup-station.ps1 `
  "https://raw.githubusercontent.com/GnauqTheBeast/football-station/main/scripts/setup-station.ps1"

# Chạy:
powershell -ExecutionPolicy Bypass -File .\setup-station.ps1
```

### Mở Windows Firewall cho ping (nếu script không chạy với quyền admin)

Chạy PowerShell admin và dán:

```powershell
netsh advfirewall firewall add rule name="Allow ICMPv4" protocol=icmpv4:8,any dir=in action=allow
```

Cần để master có thể ping station (kiểm tra kết nối trước khi tạo subscription).

### Chạy lại nhiều lần

Script idempotent — chạy lại chỉ update `.env.station` và pull code mới nhất. An toàn chạy lại.
