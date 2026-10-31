# Football DDB - Hệ CSDL phân tán V-League (postgres_fdw)

Demo kiến trúc **Cơ sở dữ liệu phân tán** cho giải bóng đá chuyên nghiệp V-League, dùng **PostgreSQL 16 + postgres_fdw**.

## Mô hình

- **1 Master (Trung tâm / VFF)** - máy của bạn (admin)
- **6 Station (CLB)** - máy 6 thành viên trong nhóm qua ZeroTier VPN mesh

```
                       [Master] vleague_master (Trung tâm)
                          | postgres_fdw IMPORT FOREIGN SCHEMA
              +-----------+-----------+-----------+-----------+-----------+
              |           |           |           |           |           |
[Station1] vleague_hnfc  |[Station2] |[Station3] |[Station4] |[Station5] |[Station6]
  5 trận sân nhà HNFC    vleague_cahn vleague_viettel vleague_haiphong vleague_namdinh vleague_hagl
  SU_KIEN_TRAN_DAU       (tương tự - mỗi CLB 5 trận sân nhà)
```

Master nắm:
- `TRAN_DAU_DOANH_THU` - mảnh dọc tài chính (GiaVe, SoKhach)
- `CAU_THU` - danh mục cầu thủ (chỉ để JOIN tên cho vua phá lưới)
- Foreign schemas `site1_hnfc` .. `site6_hagl` - trỏ tới TRAN_DAU_CHUYEN_MON + SU_KIEN_TRAN_DAU của từng station

Station nắm:
- `TRAN_DAU_CHUYEN_MON` - 5 trận sân nhà của CLB đó (PK MaTran, CHECK MaDoiNha = mã CLB)
- `SU_KIEN_TRAN_DAU` - sự kiện (bàn thắng, thẻ)
- Bản sao local `SAN_VAN_DONG`, `DOI_BONG`, `CAU_THU`, `TRONG_TAI`, `VONG_DAU` (read-only replica của master)

## Quick start

### Trên máy MASTER (bạn làm admin)

```bash
git clone -b btl-fdw-import https://github.com/GnauqTheBeast/football-station.git
cd football-station

# Tạo network (1 lần)
docker network create football-net

# Khởi động master
make up                          # hoặc: docker compose --env-file .env.master up -d

# Setup ZeroTier IP cho 6 bạn (xem ZEROTIER.md). Sửa .env.master:
#   STATION1_HOST=10.147.17.11 ... STATION6_HOST=10.147.17.16

# Force substituted template file đã có sẵn, chạy fdw setup:
make setup-fdw                   #IMPORT FOREIGN SCHEMA từ 6 station về master
make verify                      # test vw_global_tran_dau, BXH, vua phá lưới
```

### Trên máy TRẠM (6 thành viên)

Windows (non-tech, dùng bootstrap script):

```powershell
# Chay PowerShell Run as Administrator
irm https://raw.githubusercontent.com/GnauqTheBeast/football-station/btl-fdw-import/scripts/setup-station.ps1 | iex
# Hoặc tải file scripts/setup-station.ps1 rồi chay
```

Script tự cài Docker/git/ZeroTier, hỏi bạn là `STATION_ID` nào (1..6), tạo `.env.station`, up container, lấy IP ZeroTier báo lại cho admin master.

Linux/Mac:

```bash
git clone -b btl-fdw-import https://github.com/GnauqTheBeast/football-station.git
cd football-station
docker network create football-net

# Copy .env.station.example -> .env.station, sửa STATION_ID & POSTGRES_DB phù hợp
cp .env.station.example .env.station
vim .env.station
# (STATION_ID=1..6, POSTGRES_DB=vleague_hnfc|vleague_cahn|...|vleague_hagl)

# Up station
docker compose -f docker-compose.station.yml --env-file .env.station -p football-station1 up -d

# Báo admin master IP ZeroTier của bạn để admin thêm vào .env.master (STATION<N>_HOST)
```

## Targets (make)

```bash
make up             # start master container
make setup-fdw      # IMPORT FOREIGN SCHEMA tu 6 station (master container) - can stations da healthy
make verify         # test vw_global_tran_dau (30 tran), BXH, vua pha luoi
make psql-master    # psql vao master
make psql-station1  # ... station6 - psql vao station N
make reset          # down -v + up lai (NUKE master DB, mat data)
make up-app         # build + start Next.js app (profile "app", port 3000)
make dev            # Next.js dev mode tren host machine
```

## Files

```
db/
  centralized/    # verbatim copy từ BTL-CSDL: schema_ddl, triggers, procedures, views, mock_data
  reference/      # verbatim copy distributed_nodes từ BTL-CSDL (master + 6 worker + demo queries)
  master/        # master init: 10_local_data.sql + 20_fdw_setup.sql (template cho sed)
  station_1/..6/ # 1 file init.sql mỗi station (verbatim worker_*.sql)
  queries/       # demo test queries
scripts/
  init-node.sh         # chay trong docker-entrypoint-initdb.d - phan loai theo NODE_ROLE
  setup-fdw.sh         # substitute template + psql exec trong master container
  setup-station.ps1    # bootstrap cho ban win (tu cai Docker/git/ZeroTier)
docker-compose.yml          # chi master + app (de ban admin chay)
docker-compose.station.yml  # single station service (de ban bè chay)
.env.master                 # IP 6 station de FDW
.env.station.example        # template
```

## Docs

- `SETUP.md` - hướng dẫn chi tiết 10 section
- `ZEROTIER.md` - setup ZeroTier VPN mesh cho 6 máy thành viên
- `db/reference/07_demo_test_queries.sql` - các câu lệnh demo test khi bảo vệ

## Bối cảnh

Đồ án môn Các hệ thống cơ sở dữ liệu (M26CQ02 - Nhóm 2):
- Nguyễn Ngọc Quang (Master - HNFC)
- Hoàng Anh Tuấn (Station 2 - CAHN)
- Đào Duy Thông (Station 2 - CAHN)
- Mạnh Dũng (Station 3 - Viettel)
- Hồ Quang Anh (Station 4 - HPFC)
- Ngọc Bích (Station 5 - NDFC)
- Minh Dũng (Station 6 - HAGL)
