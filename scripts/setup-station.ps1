# ============================================================================
# setup-station.ps1 - Bootstrap cho member (Windows) chạy station trên máy bạn.
# Mô phỏng theo	BTL-CSDL postgres_fdw architecture.
# Tự động:
#   1. Cài winget/git/Docker Desktop nếu thiếu (qua scoop/winget)
#   2. Clone repo (nếu chưa có)
#   3. Tạo network football-net
#   4. Hỏi STATION_ID (1=HNFC, 2=CAHN, 3=Viettel, 4=HPFC, 5=NDFC, 6=HAGL)
#   5. Tạo .env.station + chọn POSTGRES_DB phù hợp
#   6. Up station container, đợi healthy
#   7. Hướng dẫn báo IP ZeroTier cho admin master để master tạo FDW tới máy bạn
# ============================================================================
#Requires -Version 5.1
[CmdletBinding()]
param(
    [string] $RepoUrl = "https://github.com/GnauqTheBeast/football-station.git",
    [string] $Branch = "btl-fdw-import",
    [string] $CloneDir = "football-station"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Step($msg) { Write-Host "=> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "! $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "X $msg" -ForegroundColor Red }

# ----------------------------------------------------------------------------
# 0. Check admin quyền (cần cho Docker install + firewall)
# ----------------------------------------------------------------------------
Write-Step "Kiem tra admin quyen"
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "Script nay can admin quyen de cai Docker va mo firewall."
    Write-Warn "Xin chay lai PowerShell bat Run as Administrator."
    pause
    exit 1
}

# ----------------------------------------------------------------------------
# 1. Cài winget + git + Docker Desktop (nếu thiếu)
# ----------------------------------------------------------------------------
Write-Step "Kiem tra Docker Desktop"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Warn "Docker chua cai. Dang cai Docker Desktop..."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        # Cài winget nếu thiếu (Windows 10 1809+)
        $progressPreference = 'SilentlyContinue'
        Add-AppxPackage -RegisterBySystemLaunch -Path "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" -ErrorAction SilentlyContinue
    }
    winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
    Write-Warn "Docker Desktop da cai xong. VUI LONG DANG XUAT / KHOI DONG LAI MAY de Docker daemon co hieu luc, roi chay lai script nay."
    pause
    exit 0
} else {
    Write-OK "Docker da san sang."
}

Write-Step "Kiem tra git"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warn "Git chua cai. Dang cai git..."
    winget install -e --id Git.Git --accept-source-agreements --accept-package-agreements
    $env:Path += ";C:\Program Files\Git\cmd"
}
Write-OK "Git da san sang."

# ----------------------------------------------------------------------------
# 2. Clone repo
# ----------------------------------------------------------------------------
Write-Step "Clone/Update repo $RepoUrl (branch $Branch)"
if (Test-Path $CloneDir) {
    Write-Warn "$CloneDir da ton tai. Pull moi nhat tu branch $Branch..."
    Push-Location $CloneDir
    git fetch origin
    git checkout $Branch
    git pull origin $Branch
    Pop-Location
} else {
    git clone -b $Branch $RepoUrl $CloneDir
    if (-not $?) { Write-Err "Clone that bai. Kiem tra mang / repo URL."; pause; exit 1 }
}
Write-OK "Repo da san sang tai $CloneDir"
Push-Location $CloneDir

# ----------------------------------------------------------------------------
# 3. Tạo docker network nếu thiếu
# ----------------------------------------------------------------------------
Write-Step "Tao docker network football-net"
docker network inspect football-net *> $null
if ($LASTEXITCODE -ne 0) {
    docker network create football-net
    if ($LASTEXITCODE -ne 0) { Write-Err "Khong tao duoc network"; pause; exit 1 }
}
Write-OK "football-net da san sang."

# ----------------------------------------------------------------------------
# 4. Hỏi STATION_ID + sinh .env.station
# ----------------------------------------------------------------------------
Write-Host ""
Write-Host "Chon STATION_ID (1=HNFC, 2=CAHN, 3=Viettel, 4=HPFC, 5=NDFC, 6=HAGL):" -ForegroundColor Yellow
do {
    $stationId = Read-Host "Nhap STATION_ID (1-6)"
    $n = 0
    if ([int]::TryParse($stationId, [ref]$n) -and $n -ge 1 -and $n -le 6) { break }
    Write-Warn "Nhap so tu 1 den 6."
} while ($true)

$dbNames = @{ 1="vleague_hnfc"; 2="vleague_cahn"; 3="vleague_viettel"; 4="vleague_haiphong"; 5="vleague_namdinh"; 6="vleague_hagl" }
$dbName = $dbNames[$n]

# Hỏi port host (mặc định 5431)
$port = Read-Host "Nhap host port (Enter de lay mac dinh 5431)"
if ([string]::IsNullOrWhiteSpace($port)) { $port = "5431" }

# Có thể override POSTGRES_PASSWORD nếu master dùng pwd khác
$pwd = Read-Host "Nhap POSTGRES_PASSWORD (Enter de lay mac dinh 123456)"
if ([string]::IsNullOrWhiteSpace($pwd)) { $pwd = "123456" }

$envFile = ".env.station"
Write-Step "Tao $envFile"
$envContent = @"
STATION_ID=$n
NODE_ROLE=station
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$pwd
POSTGRES_DB=$dbName
POSTGRES_PORT=$port
NETWORK_NAME=football-net
"@
$envContent | Out-File -FilePath $envFile -Encoding ascii -NoNewline
Write-OK "$envFile da tao (STATION_ID=$n DB=$dbName PORT=$port)"

# ----------------------------------------------------------------------------
# 5. Up station container
# ----------------------------------------------------------------------------
Write-Step "Khoi dong station container (docker compose up -d)"
docker compose -f docker-compose.station.yml --env-file $envFile -p "football-station$n" up -d
if ($LASTEXITCODE -ne 0) { Write-Err "docker compose up that bai"; pause; Pop-Location; exit 1 }

Write-Step "Cho station healthy..."
$healthy = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    $status = (docker inspect --format='{{.State.Health.Status}}' "football-station$n" 2>$null)
    if ($status -eq "healthy") { $healthy = $true; break }
    Write-Host -NoNewline "."
}
Write-Host ""
if (-not $healthy) { Write-Err "Station chua healthy sau 60s. Chay 'docker logs football-station$n' de xem."; pause; Pop-Location; exit 1 }
Write-OK "Station $n healthy!"

# ----------------------------------------------------------------------------
# 6. Lấy IP ZeroTier + hướng dẫn báo lại cho admin master
# ----------------------------------------------------------------------------
Write-Step "Lay IP ZeroTier cua may ban"
$ztIPs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -like "10.147.*" } |
    Select-Object -ExpandProperty IPAddress
if (-not $ztIPs) {
    Write-Warn "KHONG TIM THAY IP ZeroTier (10.147.x.x)."
    Write-Warn "Vui long cai ZeroTier client va join Network ID cua ban admin master, roi chay lai script nay."
} else {
    $ztIP = $ztIPs | Select-Object -First 1
    Write-OK "IP ZeroTier cua ban: $ztIP"
}

# Verify data đã nạp
Write-Step "Kiem tra data station (5 tran + 21..31 su kien)"
docker exec "football-station$n" psql -U postgres -d $dbName -c "SELECT COUNT(*) AS tran FROM tran_dau_chuyen_mon;"
docker exec "football-station$n" psql -U postgres -d $dbName -c "SELECT COUNT(*) AS su_kien FROM su_kien_tran_dau;"

Pop-Location

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " STATION $n KHOI DONG THANH CONG!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Database: $dbName"
Write-Host " Container: football-station$n"
Write-Host " ZeroTier IP: $ztIP" -ForegroundColor Yellow
Write-Host ""
Write-Host " BUOC CUOI CUNG:" -ForegroundColor Cyan
Write-Host " 1. Bao admin master IP ZeroTier cua ban: $ztIP"
Write-Host " 2. Admin master them IP vao .env.master (STATION${n}_HOST=$ztIP)"
Write-Host " 3. Admin master chay 'make setup-fdw' de ket noi FDW den may ban."
Write-Host " 4. Tu luc nay, master thay duoc tran/su kien cua ban qua vw_global_tran_dau."
Write-Host ""
Write-Host " Cach dung lai sau khi reset DB:" -ForegroundColor Cyan
Write-Host "   docker compose -f docker-compose.station.yml --env-file .env.station -p football-station$n down -v"
Write-Host "   docker compose -f docker-compose.station.yml --env-file .env.station -p football-station$n up -d"
Write-Host ""
Write-Host " psql vao station cua ban:" -ForegroundColor Cyan
Write-Host "   docker exec -it football-station$n psql -U postgres -d $dbName"
Write-Host ""
Write-Host " TEST E2E (chay luc demo/bao ve):" -ForegroundColor Cyan
Write-Host "   - Mac ban (station):  ./scripts/station-test-insert.sh"
Write-Host "     -> Insert 1 tran_test rieng cua ban (MaTran=T$n+hash, cau_thu CT99$n)"
Write-Host "   - Mac admin master:    make check-fdw"
Write-Host "     -> Thay test row cua 5-6 station traverse FDW ve master"
Write-Host "   - Kick tuong thich: 6 ban chay song song khong conflict (moi ban 1 STATION_ID)"
Write-Host "   - Cleanup sau demo: ./scripts/station-test-cleanup.sh"
Write-Host ""
pause
