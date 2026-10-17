# AGENTS.md

PostgreSQL logical-replication demo: one station DB publishes `demo.message` (station → master), and the master publishes the shared `ref` schema (master → station). No application code — the "system" is Docker Compose + init SQL + a few bash scripts. The two flows use *different* tables, so there is no replication loop.

## Layout

- `docker-compose.yml` — single `postgres:16-alpine` service, run **twice** with different env files and `-p` project names (`football-master`, `football-station`). `wal_level=logical` is set via `command:`.
- `db/common/*.sql` — run on every node; `db/<role>/*.sql` (e.g. `db/station/10_publication.sql`, `db/master/10_publication.sql`) — run only on that role. Executed by `scripts/init-node.sh` from `/docker-entrypoint-initdb.d`. `db/common/00_demo.sql` creates `demo.message` (flows station → master); `db/common/10_ref_schema.sql` creates `ref.team` / `ref.match` (flow master → station). Both exist on every node since logical replication copies rows, not schema.
- `scripts/subscribe.sh` — run manually on the master; idempotent (checks `pg_subscription`). Now sets `copy_data = true` explicitly so the initial snapshot of `demo.message` is copied on first sync.
- `scripts/subscribe-master.sh` — run manually on the station; idempotent. Creates `master_subscription` pulling `ref.*` from the master's `master_publication` so admin-edited reference data flows master → station.
- `.env.master` / `.env.station` are committed and drive the two-node demo (demo creds, not secrets). `.env` is gitignored. Master listens on host port 5430, station on 5431.

## Commands

```bash
docker network create football-net            # external network, required once or compose fails

make up             # brings up both football-master and football-station
make subscribe      # creates the station -> master subscription (demo.message)
make subscribe-master  # creates the master -> station subscription (ref.*)
make subscribe-all  # both subscriptions in one go
make verify         # inserts on station, reads on master (demo.message check)
make verify-station # same as verify: station -> master (demo.message)
make verify-master  # edits ref.team on master, reads on station (master->station check)
make psql-master   # psql into the master container
make psql-station  # psql into the station container
make reset         # tears down both projects (-v) and rebuilds from DDL
```

The Makefile is now project-aware: `up`/`down`/`reset` operate on **both** the `football-master` and `football-station` projects; `subscribe`/`verify`/`psql-*` target the right project automatically. There is no longer a separate `.env`-driven default stack.

## Gotchas

- **Init SQL runs only on an empty volume.** After editing anything in `db/`, delete the volume (`down -v`) and recreate both containers, then re-run `make subscribe-all` (or `/subscribe.sh` on the master AND `/subscribe-master.sh` on the station). Symptom otherwise: `publication "station_publication" does not exist` or `publication "master_publication" does not exist`.
- **Logical replication copies rows, not schema.** The target table must already exist on the subscriber; `db/common/00_demo.sql` and `db/common/10_ref_schema.sql` exist on both sides for this reason.
- `DROP SUBSCRIPTION` cannot run inside a transaction block — issue it as its own `psql -c`, then re-run the relevant `/subscribe*.sh`.
- Replication is **per-table one-way**: `demo.message` flows station → master, `ref.*` flows master → station. Test `ref` changes by editing on the master; test `demo.message` changes by inserting/updating on the station. Do NOT publish the same table in both directions or you'll create a loop.
- Tables use composite key `(station_id, local_id)` so multiple stations can never collide on the master. Keep this pattern for any new replicated table.
- Cross-laptop setups replace `STATION_HOST` in `.env.master` with the station's VPN IP and use the station's host port, and replace `MASTER_HOST` in `.env.station` with the master's VPN IP and use the master's host port (`5432` Docker names don't resolve across Docker hosts).

## Docs

`STATION_TO_MASTER.md` (plus a Vietnamese `.vi.md` copy) is the full setup/troubleshooting guide; `README.md` is a short quick start. Where docs and scripts disagree, trust the scripts.
