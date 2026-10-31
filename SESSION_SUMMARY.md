# Session Summary - Hệ CSDL phân tán V-League (postgres_fdw)

> Tóm tắt phiên làm việc xây dựng hệ CSDL phân tán 1 master + 5 station (BTL-CSDL),
> từ kiến trúc logical replication cũ → chuyển sang `postgres_fdw`.
>
> **Branch**: `btl-fdw-import`
> **Repo**: https://github.com/GnauqTheBeast/football-station.git
> **Ngày**: 2026-10-31 → 2026-11-01

---

## 1. Mục tiêu

- Xây hệ CSDL phân tán V-League: **1 Master (Quang)** + **5 Station (5 bạn bè)**
- Dùng kiến trúc `postgres_fdw` (master `IMPORT FOREIGN SCHEMA` từ 6 station)
- Chạy qua Docker Compose + LAN/ZeroTier VPN mesh
- 6 bạn bè chạy test insert đồng thời KHÔNG được conflict
- Master phải query được data tới từ máy nào (gắn metadata station)
- Script cho non-tech Windows members
- Tiếng Việt có dấu, không em-dash, không ký tự CJK trong docs/scripts

## 2. Kiến trúc đã chọn

```
MÁY MASTER (Quang - 10.19.227.12)             MÁY STATION (5 bạn bè)
┌──────────────────────────────┐             ┌──────────────────────────┐
│ public.CAU_THU (22 cầu thủ)  │ mảnh dọc     │ public.CAU_THU (replica)  │
│ public.TRAN_DAU_DOANH_THU    │ (master       │ public.SAN_VAN_DONG ...   │
│                              │  độc quyền)    │ public.TRAN_DAU_CHUYEN_MON│ ← mảnh ngang
│ public.vw_global_tran_dau    │               │ public.SU_KIEN_TRAN_DAU  │ ← mảnh ngang
│ public.vw_bang_xep_hang      │               └──────────────────────────┘
│ public.fn_top10_vua_pha_luoi │
│                              │
│ site1_hnfc.tran_dau_chuyen_mon ────FDW────────►  vleague_hnfc
│ site2_cahn.su_kien_tran_dau  ────FDW────────►  vleague_cahn
│ ...                          │
└──────────────────────────────┘
```

**Chỉ 2 bảng station "đăng ký" với master qua FDW** (xem `20_fdw_setup.sql`):
- `tran_dau_chuyen_mon` (mảnh ngang - 5 trận sân nhà mỗi CLB)
- `su_kien_tran_dau`     (phụ thuộc FK vào tran_dau)

**3 nhóm bảng trong hệ thống**:
| Nhóm | Bảng | Lưu ở | Master FOREIGN TABLE? |
|---|---|---|---|
| Mảnh ngang (truth ở station) | `tran_dau_chuyen_mon`, `su_kien_tran_dau` | Mỗi station 5 trận | CÓ |
| Replica read-only (station) | `san_van_dong`, `doi_bong`, `cau_thu`, `trong_tai`, `vong_dau` | Mỗi station có bản sao | KHÔNG |
| Mảnh dọc (master độc quyền) | `tran_dau_doanh_thu`, `cau_thu` (22) | Master | (master JOIN local) |

---

## 3. Việc đã làm

### 3.1. Setup base (commit `7f908c9`)

- Switch kiến trúc: logical replication → `postgres_fdw`
- Copy verbatim từ `BTL-CSDL/sql/`: `db/centralized/`, `db/reference/`
- Tạo `db/master/10_local_data.sql` (TRAN_DAU_DOANH_THU 30 trận + CAU_THU 22 cầu thủ)
- Tạo `db/master/20_fdw_setup.sql` - FDW template idempotent (DROP trước CREATE)
- `db/station_1..6/00_init.sql` - verbatim worker SQL từ BTL-CSDL
- `docker-compose.yml` (master only) + `docker-compose.station.yml` (parameterize theo STATION_ID)
- `.env.master` + `.env.station.example`, update `.gitignore`

### 3.2. Scripts (commit `0d767db`, `8c54d2e`, `c3435c0`, `4c601d7`, ...)

- `scripts/init-node.sh` - in-container, branch theo NODE_ROLE (master/station)
- `scripts/setup-fdw.sh` - substitute template `__STATION<N>_HOST__` qua sed
- `scripts/setup-station.ps1` - Windows bootstrap cho non-tech members
- `scripts/station-test-insert.sh` - mỗi station insert test row (MaTran=T<N>+hash8, CT99<N>)
- `scripts/station-test-cleanup.sh` - xóa test rows của 1 station
- `scripts/master-check-fdw.sh` - 8-step report trên master
- `scripts/check-stations-ready.sh` - verify 6 station ready từ master
- `scripts/station-check.sh` - station tự verify sẵn sàng
- `scripts/station-fix-and-test.sh` - hardcode `.env.station` + test tới master

### 3.3. Makefile (commit `da5b3a3`, `80f685e`)

- `include .env.master` để auto-export cho mọi target
- Targets: `up`, `setup-fdw`, `check-stations`, `check-fdw`, `verify`,
  `test-insert`, `test-cleanup`, `station-check`, `station-fix`,
  `psql-master`, `psql-station<N>`, `reset`

### 3.4. Docs (commit `5f37e75`)

- `HƯỚNG_DẪN_STATION.md` - tiếng Việt, chia role trực tiếp 5 bạn:
  - Tuấn=Station 1 (HNFC)
  - Thông=Station 2 (CAHN)
  - Quang Anh=Station 4 (HPFC)
  - Ngọc Bích=Station 5 (NDFC)
  - Minh Dũng=Station 6 (HAGL)
  - **Bỏ Station 3 (Viettel)** vì team không có người (`EXCLUDED_STATIONS=3`)
- `SETUP.md` (10 sections), `ZEROTIER.md` rewrite cho FDW,
  `AGENTS.md`, `README.md` updated

### 3.5. Test thực tế E2E

- Trước: 6 station mimic trong docker local, insert song song OK,
  master thấy 5 test rows khác nhau qua FDW
- Sau: 4 bạn bè thật báo IP, mimic station local xóa đi

---

## 4. Khó khăn gặp phải & cách resolve

### Khó khăn 1: INSERT fail - MaTran / MaDoiKhach quá dài

**Lỗi**: `value too long for type character varying(10)`

**Nguyên nhân**: Test script dùng `MaTran = TEST_<STATION_ID>_<TIMESTAMP>` = 21 ký tự,
vượt `VARCHAR(10)`.

**Resolve**:
- MaTran format mới: `T<N>+hash8` = 10 ký tự (vd `T2abc12345`)
- MaDoiKhach: `P<N>+hash7` = 9 ký tự
- MaSuKien: `S<N><i>+hash7` = 10 ký tự (fit `VARCHAR(15)`)
- Cleanup script update để xóa cả pattern cũ + mới (`LIKE 'TEST_<N>_%' OR LIKE 'T<N>%'`)

### Khó khăn 2: `make setup-fdw` không load `.env.master` (commit `da5b3a3`)

**Lỗi**: `could not translate host name "station2" to address: Name does not resolve`

**Nguyên nhân**:
- Makefile target `setup-fdw` chỉ gọi script, không source env-file
- Script `setup-fdw.sh` dùng `${STATION2_HOST:-station2}` default - không load file env
- Sửa `.env.master` xong chạy `make setup-fdw` → script vẫn thấy default docker alias

**Resolve**: 2 lớp:
- Makefile `include .env.master + export` (skip cho help/ps/logs/dev)
- Script `setup-fdw.sh` tự `set -a; . ./.env.master; set +a` khi file tồn tại

### Khó khăn 3: `setup-fdw` abort khi 1 station fail (commit `f93e1e7`)

**Lỗi**: `IMPORT FOREIGN SCHEMA` station 1 fail (IP chưa set) → toàn bộ SQL script abort
→ `CREATE VIEW` không chạy → master thiếu 3 views + 1 function

**Nguyên nhân**: 1 file SQL nguyên với `ON_ERROR_STOP=1` chạy tuần tự, lỗi 1 câu → dừng hết

**Resolve**: Rewrite `setup-fdw.sh` thành 6 bước riêng:
- Bước 1-3: DROP + CREATE SERVER + USER MAPPING + SCHEMA (luôn OK)
- Bước 4: Loop 6 station, IMPORT FOREIGN SCHEMA từng cái riêng với tolerant
- Bước 5: CREATE VIEW động - UNION chỉ schema IMPORT thành công
- Bước 6: Recreate BXH + top scorer function từ template

### Khó khăn 4: `check-fdw` query thẳng vào schema không tồn tại (commit `f93e1e7`)

**Lỗi**: `relation "site1_hnfc.tran_dau_chuyen_mon" does not exist`

**Nguyên nhân**: script `master-check-fdw.sh` query cứng `site<N>.<table>`
- khi station chưa IMPORT → ERROR

**Resolve**: Query `information_schema.tables WHERE table_type='FOREIGN'` để biết schema nào đã có,
- in "NOT IMPORTED" cho station chưa có thay vì ERROR.

### Khó khăn 5: Station 4 (Quang Anh) - `connect refused` (commit `5f37e75`)

**Lỗi**: `could not connect to server "srv_quanganh_hpfc"` dù ping OK, `pg_isready` OK ở port 5431

**Nguyên nhân**:
- `20_fdw_setup.sql` hardcode `port '5432'` cho cả 6 station
- Quang Anh dùng Docker với `POSTGRES_PORT=5431`
- Master FDW trỏ tới `10.19.227.127:5432` (port trống) → no response

**Resolve**:
- `20_fdw_setup.sql` parameterize port: `port '__STATION<N>_PORT__'`
- `setup-fdw.sh` substitute cả port từ `.env.master` (`STATION<N>_PORT`)
- `check-stations-ready.sh` đọc port riêng mỗi station
- `.env.master` thêm `STATION<N>_PORT` line

### Khó khăn 6: `check-stations` báo PG FAIL dù station OK

**Lỗi**: Station 5 (Ngọc Bích) reports `PG FAIL` dù thực tế query được

**Nguyên nhân**: Script dùng `docker exec psql` không set `PGPASSWORD` → station có auth yêu cầu password → fail với `fe_sendauth: no password supplied`

**Resolve**: Mọi `docker exec psql` và `pg_isready` trong `check-stations-ready.sh`
đều thêm `-e PGPASSWORD=123456`.

### Khó khăn 7: Máy Ngọc Bích có CT101/CT102 trong CAU_THU - master không thấy

**Câu hỏi**: Tại sao station insert cầu thủ mà master không có?

**Phát hiện**: Theo thiết kế:
- Station có bảng CAU_THU nhưng chỉ là REPLICA read-only (cho FK trigger)
- Master có public.CAU_THU (22 cầu thủ) là mảnh dọc độc quyền
- `fn_top10_vua_pha_luoi` master JOIN public.CAU_THU local, KHÔNG JOIN site<N>.cau_thu
- IMPORT FOREIGN SCHEMA chỉ `LIMIT TO (tran_dau_chuyen_mon, su_kien_tran_dau)` - không IMPORT cau_thu

**Resolve**: Document rõ kiến trúc này trong hướng dẫn. Nếu muốn thêm cầu thủ mới,
INSERT vào master `public.CAU_THU` chứ không phải station.

### Khó khăn 8: Mạnh Dũng không có trong team

**Phát hiện**: BTL-CSDL gốc có 6 station, gán 6 người (Tuấn, Thông, Mạnh Dũng, Quang Anh, Ngọc Bích, Minh Dũng).
- Team thực tế: 5 bạn station + 1 master (Quang) = 6 người
- "Mạnh Dũng" (Station 3 Viettel) không có thật

**Resolve** (commit `5f37e75`):
- User quyết định **bỏ Station 3 khỏi demo**
- `EXCLUDED_STATIONS=3` trong `check-stations-ready.sh` → auto SKIP, không báo FAIL
- Xóa section Mạnh Dũng trong `HƯỚNG_DẪN_STATION.md`
- Ghi rõ `STATION_ID phải 1, 2, 4, 5, 6 - KHÔNG nhập 3`
- Tổng 5x5 = 25 trận (thay vì 30)

### Khó khăn 9: Minh Dũng setup sai role

**Phát hiện**: IP `10.19.227.199:5431` có DB `vleague_hnfc` (của Tuấn)
thay vì `vleague_hagl` (của Minh Dũng)

**Nguyên nhân**: Minh Dũng chạy `setup-station.ps1` nhập nhầm `STATION_ID=1`

**Resolve**: Hướng dẫn Minh Dũng chạy:
```bash
STATION_ID=6 ./scripts/station-fix-and-test.sh
```
Script ghi đè `.env.station` với `POSTGRES_DB=vleague_hagl` + test tới master.

### Khó khăn 10: `make setup-fdw` timeout 120s (commit `5f37e75`)

**Lỗi**: Shell timeout giết script khi 4 station offline
- Script `setup-fdw` đợi `psql` FOREIGN SCHEMA tới station offline ~60s mỗi cái
- 6 station x 60s = ~360s, vượt 120s timeout của shell tool
- Bước 5-6 (CREATE VIEW + FUNCTION) không được tạo → master thiếu schemas

**Nguyên nhân sâu**: PostgreSQL FDW `CREATE SERVER` không có `connect_timeout` mặc định → TCP retry vô tận

**Resolve**: Thêm `connect_timeout '5'` vào options của `CREATE SERVER` trong `20_fdw_setup.sql`:
```sql
CREATE SERVER srv_thong_cahn FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host '...', port '...', dbname '...', connect_timeout '5');
```
- Khi station offline, FDW chỉ đợi 5s → fail nhanh
- 6 station offline total ~30s thay vì 360s

### Khó khăn 11: Heredoc không work với `docker exec psql`

**Lỗi**: `docker exec psql <<'SQL'` không echo output ra stdout trong zsh

**Nguyên nhân**: stdin redirect interaction issue với `docker exec` không -i flag trong zsh shell

**Resolve**: Dùng `-c "..."` flag thay vì heredoc cho mọi `psql` command trong scripts.

---

## 5. Trạng thái cuối session

### Master container (`football-master`)

| Schema/Object | Trạng thái | Số rows |
|---|---|---|
| `public.cau_thu` | ✅ | 22 |
| `public.tran_dau_doanh_thu` | ✅ | 30 |
| `public.vw_global_tran_dau` | ✅ (mới tạo) | 5 (chỉ HAGL online) |
| `public.vw_global_su_kien_tran_dau` | ✅ | 21 |
| `public.vw_bang_xep_hang` | ✅ | 6 |
| `public.fn_top10_vua_pha_luoi` | ✅ | 9 |
| `site6_hagl.*` (Minh Dũng) | ✅ 2 foreign tables | 5 tran / 21 su_kien |
| `site1_hnfc.*` (Tuấn) | ⏳ IP set nhưng offline lúc IMPORT | 0 |
| `site2_cahn.*` (Thông) | ⏳ offline | 0 |
| `site4_hpfc.*` (Quang Anh) | ⏳ offline | 0 |
| `site5_ndfc.*` (Ngọc Bích) | ⏳ offline | 0 |
| `site3_viettel` | SKIP (bỏ demo) | - |

### IP máy các bạn (đã set trong `.env.master`)

| Station | Bạn | IP | Port | Status |
|---|---|---|---|---|
| 1 HNFC | Tuấn | 10.19.227.140 | 5431 | IP OK, có lúc online rồi off |
| 2 CAHN | Thông | 10.19.227.149 | 5432 | Native Postgres, offline |
| 3 VTT | (bỏ) | - | - | SKIP |
| 4 HPFC | Quang Anh | 10.19.227.127 | 5431 | Docker, offline |
| 5 NDFC | Ngọc Bích | 10.19.227.4 | 5432 | Native Postgres, offline |
| 6 HAGL | Minh Dũng | 10.19.227.199 | 5431 | ✅ Online, đã fix role HNFC→HAGL |
| Master | Quang (tôi) | 10.19.227.12 | 5430 | ✅ Healthy |

---

## 6. Commits đã push

| Hash | Title |
|---|---|
| `7f908c9` | Switch architecture: BTL-CSDL postgres_fdw (master + 6 station) |
| `e2515a7` | Add Next.js SSR web app (cũ từ trước session) |
| `0d767db` | Add E2E test scripts for 6-station concurrent insert (FDW demo) |
| `8c54d2e` | Add huong dan station (Vietnamese, per-member role assignment) |
| `c3435c0` | Add station-fix-and-test: hardcode `.env.station` + test tới master |
| `4c601d7` | Add station-check.sh (committed standalone) |
| `da5b3a3` | Auto-load `.env.master` in Makefile + setup-fdw.sh |
| `80f685e` | Add check-stations-ready: verify 6 station ready before setup-fdw |
| `f93e1e7` | setup-fdw + check-fdw: tolerant khi station chưa sẵn sàng |
| `5f37e75` | Support STATION<N>_PORT trong FDW + skip Station 3 + update docs |

---

## 7. Workflow chuẩn khi demo (cho lần sau)

### Phía admin (Quang)

```bash
# Khi 4 bạn báo online lại:
make check-stations   # verify ALL OK (trừ station 3 SKIP)
make setup-fdw        # IMPORT 5 station + recreate views (timeout 5s mỗi station)
make check-fdw        # xem 25 tran + ~150 su_kien + BXH + top scorer
```

### Phía mỗi bạn station

```bash
# Setup 1 lần đầu (Windows):
irm https://raw.githubusercontent.com/GnauqTheBeast/football-station/btl-fdw-import/scripts/setup-station.ps1 | iex

# Setup 1 lần đầu (Linux/Mac):
git clone -b btl-fdw-import https://github.com/GnauqTheBeast/football-station.git
cd football-station
docker network create football-net
cp .env.station.example .env.station

# Hardcode + test tới master (khi gặp lỗi config):
STATION_ID=<1/2/4/5/6> ./scripts/station-fix-and-test.sh

# Báo Quang IP + port (xem `ip addr | grep 10`)

# Test insert (demo phân tán):
./scripts/station-test-insert.sh

# Dọn test:
./scripts/station-test-cleanup.sh
```

---

## 8. Còn TODO

- [ ] Khi 4 bạn online trở lại: `make check-stations` phải ALL OK, rồi `make setup-fdw`
- [ ] Commit `connect_timeout '5'` cho `20_fdw_setup.sql` (chưa commit cuối session)
- [ ] (Optional) Rewrite Next.js app để query schema BTL-CSDL (`vw_global_tran_dau` / `vw_bang_xep_hang` / `fn_top10_vua_pha_luoi`) - code app vẫn dùng arch cũ `ref.*/match.*`
- [ ] (Optional) Khi user OK, merge `btl-fdw-import` vào `main`
- [ ] Cleanup test rows cũ còn sót (Ngọc Bích có CT101/CT102 câu thủ-test trong local station)
