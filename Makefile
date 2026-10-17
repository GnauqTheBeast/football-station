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

# Kiểm tra station -> master: chèn demo.message ở station, đọc trên master.
# `verify` là alias cho verify-station (giữ tương thích ngược).
verify: verify-station

verify-station:
	@echo "[verify-station] insert demo.message on station..."
	@$(STATION) exec -T postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -c "INSERT INTO demo.message(station_id, author, body) VALUES ($${STATION_ID:-1}, '"'"'verify'"'"', '"'"'hello from station'"'"')"'
	@echo "[verify-station] waiting for replication..."
	@sleep 2
	@echo "[verify-station] rows on master:"
	@$(MASTER) exec -T postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -c "SELECT station_id, local_id, author, body, created_at FROM demo.message ORDER BY created_at DESC LIMIT 5"'

# Kiểm tra master -> station: đổi ref.team trên master, đọc trên station.
verify-master:
	@echo "[verify-master] insert ref.team on master..."
	@$(MASTER) exec -T postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -c "INSERT INTO ref.team(name, code, city) VALUES ('"'"'PTIT FC'"'"', '"'"'PTT'"'"', '"'"'Hanoi'"'"') ON CONFLICT DO NOTHING"'
	@echo "[verify-master] waiting for replication..."
	@sleep 2
	@echo "[verify-master] rows on station:"
	@$(STATION) exec -T postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -c "SELECT id, name, code, city, updated_at FROM ref.team ORDER BY id DESC LIMIT 5"'

# Chạy trên MÁY TRẠM (laptop bạn): up + migration + subscribe master->station + listen log.
start-station:
	./scripts/start-station.sh

# Dừng station (giữ volume).
stop-station:
	$(STATION) down
