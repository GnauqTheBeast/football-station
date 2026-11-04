# ============================================================================
# station-rebuild.ps1 - Dựng lại station (xóa volume + chạy lại migration)
# Chạy TRÊN MÁY TRẠM (Windows). Đọc STATION_ID + POSTGRES_DB từ .env.station.
#
# Vì sao cần xóa volume: scripts/init-node.sh CHỈ chạy khi volume TRỐNG
# (docker-entrypoint-initdb.d). Muốn chạy lại migration mới phải xóa volume.
#
# Cách dùng:
#   cd <thư mục repo>
#   powershell -ExecutionPolicy Bypass -File scripts\station-rebuild.ps1
# ============================================================================
$ErrorActionPreference = "Stop"

$envFile = ".env.station"
if (-not (Test-Path $envFile)) {
    Write-Host "KHONG tim thay $envFile. Chay script nay trong thu muc repo." -ForegroundColor Red
    exit 1
}

# Doc .env.station (duong dong KEY=VALUE, bo dong comment)
$pairs = @{}
Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and $line -notlike '#*' -and $line -match '^([A-Za-z_]+)=(.*)$') {
        $pairs[$matches[1]] = $matches[2].Trim()
    }
}
$stationId = $pairs['STATION_ID']
$dbName    = $pairs['POSTGRES_DB']
if (-not $stationId) {
    Write-Host "KHONG tim thay STATION_ID trong $envFile" -ForegroundColor Red
    exit 1
}

$project   = "football-station$stationId"
$container = "football-station$stationId"

Write-Host ""
Write-Host "=== Rebuild station $stationId (DB: $dbName) ===" -ForegroundColor Cyan

# 1. Kéo code moi (file 00_init.sql moi nhat)
Write-Host "=> [1/4] git pull..." -ForegroundColor Cyan
git pull
if ($LASTEXITCODE -ne 0) { Write-Host "git pull that bai." -ForegroundColor Red; exit 1 }

# 2. Xoa volume (de init chay lai)
Write-Host "=> [2/4] docker compose down -v (xoa volume)..." -ForegroundColor Cyan
docker compose -f docker-compose.station.yml --env-file $envFile -p $project down -v
if ($LASTEXITCODE -ne 0) { Write-Host "down -v that bai." -ForegroundColor Red; exit 1 }

# 3. Up lai (init-node.sh chay 00_init.sql)
Write-Host "=> [3/4] docker compose up -d (init lai)..." -ForegroundColor Cyan
docker compose -f docker-compose.station.yml --env-file $envFile -p $project up -d
if ($LASTEXITCODE -ne 0) { Write-Host "up -d that bai." -ForegroundColor Red; exit 1 }

# 4. Doi healthy + verify
Write-Host "=> [4/4] Doi station healthy..." -ForegroundColor Cyan
$healthy = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    $status = (docker inspect --format='{{.State.Health.Status}}' $container 2>$null)
    if ($status -eq "healthy") { $healthy = $true; break }
    Write-Host -NoNewline "."
}
Write-Host ""
if (-not $healthy) {
    Write-Host "Station chua healthy sau 60s. Chay: docker logs $container" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Station $stationId healthy!" -ForegroundColor Green

Write-Host ""
Write-Host "=== Verify (mong: 11 bang, 5 tran, 6 trigger) ===" -ForegroundColor Cyan
docker exec $container psql -U postgres -d $dbName -c "SELECT COUNT(*) AS so_bang FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';"
docker exec $container psql -U postgres -d $dbName -c "SELECT COUNT(*) AS so_tran_sau_nha FROM tran_dau_chuyen_mon;"
docker exec $container psql -U postgres -d $dbName -c "SELECT COUNT(*) AS so_trigger FROM pg_trigger WHERE NOT tgisinternal;"

Write-Host ""
Write-Host "=== XONG. Station $stationId da dung lai voi 11 bang + 6 trigger + 5 SP ===" -ForegroundColor Green