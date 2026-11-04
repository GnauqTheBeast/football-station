# Makefile - Hệ thống CSDL phân tán V-League (postgres_fdw)
# 1 master + 6 stations. Mặc định chạy all 7 trên 1 máy dev.

COMPOSE      = docker compose
PROJECT      = football-ddb
APP          = $(COMPOSE) --profile app

# Auto-source .env.master nếu file tồn tại (chứa STATION<N>_HOST,
# POSTGRES_PASSWORD, MASTER_CONTAINER). setup-fdw.sh tự load nhưng này
# giữ cho target khác cũng kế thừa env khi cần.
ifeq (,$(filter $(MAKECMDGOALS),help ps logs dev))
  ifneq (,$(wildcard .env.master))
    include .env.master
    export
  endif
endif

# Services
MASTER       = master
STATIONS     = station1 station2 station3 station4 station5 station6
ALL_SVC      = $(MASTER) $(STATIONS)

.PHONY: help up up-master up-station1 up-station2 up-station3 up-station4 up-station5 up-station6 up-app up-all down down-all reset ps logs setup-fdw check-stations verify verify-test check-fdw test-insert psql-master psql-station1 psql-station2 psql-station3 psql-station4 psql-station5 psql-station6 dev station-check station-fix station-rebuild-remote station-check-remote

help:
	@echo "=== Football DDB (postgres_fdw distributed) ==="
	@echo "up-all          Start all 7 containers (master + 6 stations)"
	@echo "setup-fdw       Run fdw import sau khi all containers healthy"
	@echo "check-stations  Check 6 station ready (env IP + reachable + Postgres SELECT 1)"
	@echo "station-check  (chạy trên máy trạm) Check station tự sẵn sàng để master connect"
	@echo "station-fix   (chạy trên máy trạm) Ghi đè .env.station + test tới master"
	@echo "station-rebuild-remote  (chạy trên master) Rebuild remote station online qua psql ZeroTier"
	@echo "station-check-remote    (chạy trên master) Check connectivity 6 station qua ZeroTier"
	@echo "verify          Test views toan cuc sau khi setup-fdw"
	@echo "psql-master     psql vao master DB (vleague_master)"
	@echo "psql-stationN   psql vao station N (N=1..6)"
	@echo "down-all        Stop + remove all containers (giữ volumes)"
	@echo "reset           down-all + xóa volumes (NUKE) + up again"
	@echo "up-app          Start Next.js app (port 3000) - opt-in profile"
	@echo "dev             Next.js dev mode host machine (app/.env.local)"

# === Up / Down ===
up:
	$(COMPOSE) up -d --build

up-master:
	$(COMPOSE) up -d master

up-station1:
	$(COMPOSE) up -d station1
up-station2:
	$(COMPOSE) up -d station2
up-station3:
	$(COMPOSE) up -d station3
up-station4:
	$(COMPOSE) up -d station4
up-station5:
	$(COMPOSE) up -d station5
up-station6:
	$(COMPOSE) up -d station6

up-all:
	$(COMPOSE) up -d $(ALL_SVC)

# Chờ healthy tất cả các service
wait-healthy:
	@for svc in $(ALL_SVC); do \
		echo "Chờ $$svc healthy..."; \
		until [ "$$(docker inspect --format='{{.State.Health.Status}}' football-$${svc} 2>/dev/null)" = "healthy" ]; do \
			printf "."; sleep 1; \
		done; \
		echo " OK"; \
	done

down:
	$(COMPOSE) down

down-all:
	$(COMPOSE) down

# NUKE: down -v + up lại từ đầu (init SQL chạy lại)
reset:
	$(COMPOSE) down -v
	$(COMPOSE) up -d $(ALL_SVC)
	@echo "=== Chờ all healthy (~10s) ==="
	@sleep 10
	@$(MAKE) --no-print-directory wait-healthy
	@echo "=== Chạy setup-fdw ==="
	@./scripts/setup-fdw.sh

# === Check 6 station ready trước khi setup-fdw ===
check-stations:
	./scripts/check-stations-ready.sh

# === Check station-cua-ban tu-sẵn-sàng (chạy TRÊN máy trạm) ===
station-check:
	./scripts/station-check.sh

# === Fix .env.station + test tới master (chạy TRÊN máy trạm) ===
station-fix:
	./scripts/station-fix-and-test.sh

# === Rebuild station REMOTE qua psql ZeroTier (chạy TRÊN máy master) ===
# Khong can SSH/docker tren may tram. Init idempotent, bọc trong transaction.
# Chi dinh station cu the: make station-rebuild-remote STATIONS="2 6"
station-rebuild-remote:
	./scripts/station-rebuild-remote.sh $(STATIONS)

# === Check connectivity 6 station qua ZeroTier (chạy TRÊN máy master) ===
station-check-remote:
	./scripts/station-rebuild-remote.sh --check

# === fdw: import foreign schema từ 6 stations về master ===
setup-fdw:
	./scripts/setup-fdw.sh

# === Verify: test global views trên master ===
verify:
	@echo "=== 1. Đếm trận từ vw_global_tran_dau (để xem = 30) ==="
	@docker exec football-master psql -U postgres -d vleague_master -c "SELECT COUNT(*) AS tong_tran FROM vw_global_tran_dau;"
	@echo "=== 2. Đếm sự kiện từ vw_global_su_kien_tran_dau ==="
	@docker exec football-master psql -U postgres -d vleague_master -c "SELECT COUNT(*) AS tong_su_kien FROM vw_global_su_kien_tran_dau;"
	@echo "=== 3. BXH (vw_bang_xep_hang) ==="
	@docker exec football-master psql -U postgres -d vleague_master -c "SELECT ViTri, MaDoi, SoTranDaDau, SoTranThang, SoTranHoa, SoTranThua, DiemSo FROM vw_bang_xep_hang ORDER BY ViTri;"
	@echo "=== 4. Top 10 vua phá lười ==="
	@docker exec football-master psql -U postgres -d vleague_master -c "SELECT * FROM fn_top10_vua_pha_luoi();"
	@echo "=== 5. Phân mảnh: số trận mỗi station ==="
	@docker exec football-master psql -U postgres -d vleague_master -c "SELECT 'Site1 HNFC'    AS tram, COUNT(*) FROM site1_hnfc.tran_dau_chuyen_mon UNION ALL SELECT 'Site2 CAHN',    COUNT(*) FROM site2_cahn.tran_dau_chuyen_mon UNION ALL SELECT 'Site3 Viettel', COUNT(*) FROM site3_viettel.tran_dau_chuyen_mon UNION ALL SELECT 'Site4 HPFC',    COUNT(*) FROM site4_hpfc.tran_dau_chuyen_mon UNION ALL SELECT 'Site5 NDFC',    COUNT(*) FROM site5_ndfc.tran_dau_chuyen_mon UNION ALL SELECT 'Site6 HAGL',    COUNT(*) FROM site6_hagl.tran_dau_chuyen_mon;"

# === E2E test demo (FDW cross-site) ===
# Trên TRẠM (bạn bè): chèn 1 test match + event
test-insert:
	@./scripts/station-test-insert.sh --commit

test-insert-dry:
	@./scripts/station-test-insert.sh --rollback

test-cleanup:
	@./scripts/station-test-cleanup.sh

# Trên MASTER (admin): kiểm tra test rows đã tới qua FDW
check-fdw:
	@./scripts/master-check-fdw.sh

# Tên alias cho đầy đủ: verify-test = check-fdw
verify-test: check-fdw

# === Trạng thái ===
ps:
	@docker compose ps

logs:
	@docker compose logs -f --tail=50

# === psql vào từng DB ===
psql-master:
	@docker exec -it football-master psql -U postgres -d vleague_master

psql-station1:
	@docker exec -it football-station1 psql -U postgres -d vleague_hnfc
psql-station2:
	@docker exec -it football-station2 psql -U postgres -d vleague_cahn
psql-station3:
	@docker exec -it football-station3 psql -U postgres -d vleague_viettel
psql-station4:
	@docker exec -it football-station4 psql -U postgres -d vleague_haiphong
psql-station5:
	@docker exec -it football-station5 psql -U postgres -d vleague_namdinh
psql-station6:
	@docker exec -it football-station6 psql -U postgres -d vleague_hagl

# === App ===
up-app:
	$(APP) up -d --build app

down-app:
	$(APP) down

dev:
	cd app && npm install && npm run dev
