# Football DDB: Bidirectional replication (per-table ownership)

This repository demonstrates the project's two data flows, kept on separate tables so there is no loop:

```text
Station database ── demo.message ──> Master database
Master database  ── ref.* (teams, fixtures) ──> Station database
```

Stations publish their local operational data (`demo.message`); the master subscribes. The master publishes shared reference data (`ref.team`, `ref.match`); each station subscribes. Each table has exactly one write owner.

Read the complete setup guide:

- [Station → Master Replication](STATION_TO_MASTER.md)

The guide covers:

- why PostgreSQL was selected;
- Docker network setup;
- running master and station databases locally;
- `make verify` — inserts on station, reads on master (`demo.message`)
- `make verify-master` — edits `ref.team` on master, reads on station
- station-to-master and master-to-station logical replication;
- connecting across laptops through Tailscale, ZeroTier, or another VPN;
- Docker container access to a VPN IP;
- schema creation, publications, subscriptions, inserts, updates, and verification;
- reset and troubleshooting commands.

## Quick start

```bash
# External Docker network (once per machine)
docker network create football-net

# Bring up master + station, create both subscriptions, verify both flows:
make up
make subscribe-all
make verify           # demo.message: insert on station, read on master
make verify-master    # ref.team: edit on master, read on station
```

Or, with raw compose:

```bash
docker network create football-net

docker compose -p football-master \
  --env-file .env.master -f docker-compose.yml up -d

docker compose -p football-station \
  --env-file .env.station -f docker-compose.yml up -d

# station -> master: demo.message
docker compose -p football-master \
  --env-file .env.master -f docker-compose.yml \
  exec postgres bash /subscribe.sh

# master -> station: ref.team, ref.match
docker compose -p football-station \
  --env-file .env.station -f docker-compose.yml \
  exec postgres bash /subscribe-master.sh
```

Insert station data and query it on the master as shown in [STATION_TO_MASTER.md](STATION_TO_MASTER.md). Edit reference data (`ref.team`, `ref.match`) on the master and it replicates back to the station automatically.
