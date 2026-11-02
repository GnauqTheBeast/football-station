# AGENTS.md

Hệ thống CSDL phân tán V-League (1 Master + 6 Station) kiến trúc **postgres_fdw** - master `IMPORT FOREIGN SCHEMA` từ 6 station DBs qua ZeroTier VPN mesh.

## Layout

- `docker-compose.yml` - **master only** (run trên máy admin). Service `app` opt-in qua profile `["app"]` (Next.js SSR).
- `docker-compose.station.yml` - **single station** service, parameterize bằng `STATION_ID` (1..6) + `NODE_ROLE=station` trong `.env.station`. Mỗi bạn bè chạy 1 instance trên máy mình.
- `db/centralized/` - verbatim copy từ `BTL-CSDL/sql/`: `01_schema_ddl.sql` (11 bảng public), `02_triggers.sql` (5 trigger), `03_transactions_procedures.sql` (5 SP), `04_views_statistics.sql`, `05_mock_data.sql`. **Tham chiếu-only**, không chạy trực tiếp (chạy trên station qua `db/station_<N>/00_init.sql` đã app-data).
- `db/reference/` - verbatim copy `BTL-CSDL/sql/distributed_nodes/` (master + 6 worker + demo queries). Tham chiếu cho repo gốc.
- `db/master/10_local_data.sql` - init master local: `TRAN_DAU_DOANH_THU` (mảnh dọc tài chính 30 trận) + `CAU_THU` (22 cầu thủ master để JOIN vua phá lưới). Chạy bởi `scripts/init-node.sh` qua `docker-entrypoint-initdb.d`.
- `db/master/20_fdw_setup.sql` - template FDW setup (idempotent - DROP cũ trước CREATE mới). Substitute `__STATION<N>_HOST__` qua `scripts/setup-fdw.sh`.
- `db/station_1/..6/00_init.sql` - mỗi file = 1 worker SQL từ BTL-CSDL, tạo schema local cho station đó (TRAN_DAU_CHUYEN_MON + SU_KIEN_TRAN_DAU + replica SAN_VAN_DONG/DOI_BONG/CAU_THU/TRONG_TAI/VONG_DAU + 5 trận sân nhà + ~25 sự kiện).
- `db/queries/07_demo_test_queries.sql` - demo queries khi báo cáo bảo vệ (top scorer, BXH, real-time cross-site update).

## Scripts

- `scripts/init-node.sh` - chạy trong container Postgres khi volume trống. Phân luồng theo `NODE_ROLE`:
  - `master` → chạy `/db/master/10_local_data.sql`
  - `station` (hoặc `station<N>`) + `STATION_ID=1..6` → chạy `/db/station_<ID>/00_init.sql`
- `scripts/setup-fdw.sh` - chạy **sau khi 6 station healthy**. Substitute template file `db/master/20_fdw_setup.sql` với `STATION<N>_HOST` từ `.env.master`, `docker exec -i football-master psql < template`. Tạo `site1_hnfc..site6_hagl` foreign schemas + `vw_global_tran_dau`, `vw_global_su_kien_tran_dau`, `vw_bang_xep_hang`, `fn_top10_vua_pha_luoi`.
- `scripts/setup-station.ps1` - bootstrap Windows cho non-tech members. Tự cài Docker/git/ZeroTier, hỏi `STATION_ID`, tạo `.env.station`, up station, lấy IP ZeroTier báo admin master.

## Env

- `.env.master` (committed) - master-only vars + `STATION1_HOST`..`STATION6_HOST` (ZeroTier IPs để FDW).
- `.env.station.example` (committed) - template cho station.
- `.env.station`, `.env.station1..6`, `.env.master.local`, `app/.env.local` - **gitignored** (mỗi máy 1 bản local).

## Commands

```bash
# Trên máy MASTER (admin):
docker network create football-net      # 1 lần
make up                                 # master container up
make setup-fdw                          # sau khi 6 station healthy qua ZeroTier
make verify                             # test vw_global_tran_dau + BXH + top scorer
make psql-master                        # psql vào master DB
make reset                              # NUKE + init lại master
make dev                                # Next.js dev mode (host machine)
make up-app                             # up Next.js app container (profile app)

# Trên máy STATION (bạn bè, qua setup-station.ps1 hoặc):
docker compose -f docker-compose.station.yml --env-file .env.station -p football-station<N> up -d
docker exec -it football-station<N> psql -U postgres -d <db_name>
```

## Gotchas

- **Init SQL chỉ chạy khi volume trống.** Sau khi sửa bất kỳ file nào trong `db/`, `down -v` (cả master lẫn station) rồi up lại. Muốn station reload schema mới: `docker compose -p football-station<N> -f docker-compose.station.yml --env-file .env.station down -v && up -d`. Tương tự master: `make reset`.
- **FDW setup idempotent** - `20_fdw_setup.sql` DROP server/schema cũ trước khi CREATE mới. An toàn chạy `make setup-fdw` nhiều lần (vd sau khi station đổi IP ZeroTier).
- **Station Docker DB name cố định theo STATION_ID**: không phải `POSTGRES_DB=vleague_station1` mà là `vleague_hnfc` (HNFC), `vleague_cahn` (CAHN), `vleague_viettel` (Viettel), `vleague_haiphong` (HPFC), `vleague_namdinh` (NDFC), `vleague_hagl` (HAGL). Match tên DB mà master FDW trỏ tới trong `20_fdw_setup.sql`.
- **ZeroTier IP phải dùng cho `STATION<N>_HOST`** không phải IP LAN. Nếu để default `station1` (docker alias), FDW sẽ fail trên môi trường thực tế qua ZeroTier.
- **Station password phải khớp master user mapping**. Default cả 2: `POSTGRES_PASSWORD=123456`, `password '123456'` trong `20_fdw_setup.sql`. Đổi 1 nơi phải đổi cả 2.
- **`IMPORT FOREIGN SCHEMA` chỉ kéo** `tran_dau_chuyen_mon` và `su_kien_tran_dau` - không kéo `SAN_VAN_DONG` (station chỉ có bản sao replica read-only, master không trỏ tới để query).
- **DB pha origin**: Station là **truth source** của `TRAN_DAU_CHUYEN_MON` + `SU_KIEN_TRAN_DAU` (station có thể INSERT/UPDATE qua SP `sp_ghi_nhan_ket_qua_tran_dau` từ BTL-CSDL). Master chỉ SELECT qua FDW.
- **App Next.js hiện trỏ tới master DB** (`vleague_master`) - đọc thông qua `vw_global_*` views. App không kết nối trực tiếp tới station DBs.

## Docs

- `SETUP.md` - hướng dẫn chi tiết 10 section (master + station + ZeroTier + FDW setup + verify + demo)
- `ZEROTIER.md` - setup ZeroTier VPN mesh cho 7 máy
- `README.md` - quick start
- `db/reference/07_demo_test_queries.sql` - demo queries khi báo cáo bảo vệ

Nơi docs / scripts bất đồng: **trust the scripts**.
