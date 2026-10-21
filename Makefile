.PHONY: up up-master up-station down reset ps logs subscribe subscribe-master subscribe-all psql-master psql-station verify verify-station verify-master start-station stop-station

COMPOSE := docker compose -f docker-compose.yml
MASTER := $(COMPOSE) -p football-master --env-file .env.master
STATION := $(COMPOSE) -p football-station --env-file .env.station

up: up-master up-station

up-master:
	$(MASTER) up -d

up-station:
	$(STATION) up -d

down:
	$(MASTER) down
	$(STATION) down

# Xoá toàn bộ volume và dựng lại từ DDL trong /db (dùng mỗi khi sửa DDL).
# Reset cả hai project master + station, không phải stack default.
reset:
	$(MASTER) down -v
	$(STATION) down -v
	$(MAKE) up

ps:
	$(MASTER) ps
	$(STATION) ps

logs:
	$(MASTER) logs -f --tail=50

# Chạy trên master: tạo subscription kéo data từ station.
subscribe:
	$(MASTER) exec -T postgres bash /subscribe.sh

# Chạy trên station: tạo subscription kéo ref.* từ master (master -> station).
subscribe-master:
	$(STATION) exec -T postgres bash /subscribe-master.sh

# Tạo cả hai subscription (station -> master và master -> station).
subscribe-all:
	$(MASTER) exec -T postgres bash /subscribe.sh
	$(STATION) exec -T postgres bash /subscribe-master.sh

psql-master:
	$(MASTER) exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

psql-station:
	$(STATION) exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

# Kiểm tra station -> master: chèn match.match_result ở station, đọc trên master.
# `verify` là alias cho verify-station (giữ tương thích ngược).
verify: verify-station

# Insert 1 kết quả trận ở station Station 1, fixture 1 (đã seed trên master).
# Match_Kết quả cần played_at <= now() (trigger), nên dùng now() - 1 hour.
verify-station:
	@echo "[verify-station] insert match.match_result on station (station_id=1, fixture_id=1)..."
	@$(STATION) exec -T postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -c "INSERT INTO match.match_result(station_id, fixture_id, played_at, home_goals, away_goals, attendance, ticket_price) VALUES (1, 1, now() - interval '"'"'1 hour'"'"', 2, 1, 5000, 100000) ON CONFLICT (station_id, fixture_id) DO UPDATE SET home_goals = excluded.home_goals, away_goals = excluded.away_goals, attendance = excluded.attendance, ticket_price = excluded.ticket_price"'
	@echo "[verify-station] waiting for replication..."
	@sleep 2
	@echo "[verify-station] rows on master:"
	@$(MASTER) exec -T postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -c "SELECT station_id, fixture_id, played_at, home_goals, away_goals, attendance FROM match.match_result ORDER BY played_at DESC LIMIT 5"'

# Kiểm tra master -> station: đổi tên 1 ref.team trên master, đọc trên station.
verify-master:
	@echo "[verify-master] UPDATE ref.team name on master (team_id=1)..."
	@$(MASTER) exec -T postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -c "UPDATE ref.team SET name = '"'"'Master FC '"'"'||to_char(now(),'"'"'HH24MISS'"'"') WHERE team_id = 1"'
	@echo "[verify-master] waiting for replication..."
	@sleep 2
	@echo "[verify-master] rows on station:"
	@$(STATION) exec -T postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -c "SELECT team_id, name, founded_year FROM ref.team ORDER BY team_id LIMIT 5"'

# Chạy trên MÁY TRẠM (laptop bạn): up + migration + subscribe master->station + listen log.
start-station:
	./scripts/start-station.sh

# Dừng station (giữ volume).
stop-station:
	$(STATION) down
