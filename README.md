# Football DDB: Bidirectional replication (per-table ownership)

This repository implements the project's two data flows, kept on separate tables so there is no loop:

```text
Station database ── match.* (match_result, match_squad, match_event) ──> Master database
Master database  ── ref.* (station, season, round, stadium, team, ...) ──> Station database
```

Stations publish their local match data (`match.*`); the master subscribes. The master publishes shared reference data (`ref.*`, 12 tables); each station subscribes. **Each table has exactly one write owner → no loop.**

Tham khảo thiết kế đầy đủ: [CSDL phân tán giải bóng đá.md](CSDL%20ph%C3%A2n%20t%C3%A1n%20gi%E1%BA%A3i%20b%C3%B3ng%20%C4%91%C3%A1.md).

## Hướng dẫn

- **[SETUP.md](SETUP.md)** — Hướng dẫn khởi động & vận hành đầy đủ (tiếng Việt).
- **[STATION_TO_MASTER.md](STATION_TO_MASTER.md)** — Hướng dẫn chi tiết station-to-master replication (giữ lại cho legacy / cross-machine ops).

## Quick start

```bash
# External Docker network (once per machine; subnet cố định tránh xung đột LAN 172.18.x.x)
docker network create --subnet 10.200.0.0/24 football-net

# Trên MASTER:
make up-master
# Master tự init: ref.* + match.* schema, trigger, views, master_publication, seed data.

# Trên STATION (chỉ 1 lệnh):
make start-station
# Script tự: up + migration + master_subscription + register station_subscription + listen.

# Test 2 chiều:
make verify-station   # match.match_result: insert trên station, đọc trên master
make verify-master    # ref.team: update trên master, đọc trên station
```

Or, with raw compose (chạy trên 1 máy thử nghiệm):

```bash
docker compose -p football-master \
  --env-file .env.master -f docker-compose.yml up -d

docker compose -p football-station \
  --env-file .env.station -f docker-compose.yml up -d

# station -> master: match.*
docker compose -p football-master \
  --env-file .env.master -f docker-compose.yml \
  exec postgres bash /subscribe.sh

# master -> station: ref.*
docker compose -p football-station \
  --env-file .env.station -f docker-compose.yml \
  exec postgres bash /subscribe-master.sh
```

Insert match data on the station and query it on the master, edit reference data (`ref.*`) on the master and it replicates back to the station automatically. See [SETUP.md](SETUP.md) section 4.
