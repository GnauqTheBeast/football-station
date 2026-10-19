# ==========================================================================
# setup-station.ps1 — Bootstrap máy trạm football-ddb trên Windows.
#
# Tự động:
#   1. Cài Git (nếu chưa có) qua winget
#   2. Clone repo football-station về C:\football-station
#   3. Cài Docker Desktop (nếu chưa có) qua winget
#   4. Đợi Docker daemon sẵn sàng
#   5. Hỏi IP máy trạm + IP master → viết vào .env.station
#   6. Chạy docker compose up + migration + subscribe 2 chiều + listen log
#
# Cách dùng (chạy trên máy trạm Windows):
#   1. Nhấn nút Windows, gõ "PowerShell", click phải → "Run as administrator"
#   2. Dán lệnh này rồi Enter:
#
#      & ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing `
#        "https://raw.githubusercontent.com/GnauqTheBeast/football-station/main/scripts/setup-station.ps1").Content))
#
#   Hoặc nếu đã clone repo:    powershell -ExecutionPolicy Bypass -File .\scripts\setup-station.ps1
# ==========================================================================

# Cho phép script chạy (cần nêu người dùng chạy PowerShell admin)
$ErrorActionPreference = "Stop"

$RemoteUrl = "https://github.com/GnauqTheBeast/football-station.git"
$RepoDir = "$env:USERPROFILE\football-station"
$MasterHostDefault = "172.18.20.106"
$MasterPortDefault = "5430"
$StationPortDefault = "5431"

function Say($m) { Write-Host "[setup] $m" -ForegroundColor Cyan }
function Ok($m)  { Write-Host "✓ $m" -ForegroundColor Green }
function Warn($m) { Write-Host "! $m" -ForegroundColor Yellow }
function Err($m)  { Write-Host "✗ $m" -ForegroundColor Red }
function Die($m) { Err $m; exit 1 }

# Chỉ chạy trên Windows
if ($PSVersionTable.Platform -and $PSVersionTable.Platform -ne "Win32NT") {
    Die "Script này chỉ hỗ trợ Windows. Trên macOS chạy scripts/setup-station.sh."
}

# Yêu cầu quyền admin (cần cho winget / Docker install)
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Warn "script chưa chạy với quyền admin — một số bước cài đặt có thể skip."
    Warn "nếu gặp lỗi 'access denied', đóng PowerShell và mở lại bằng Run as administrator."
}

# ===========================================================================
# Bước 0: winget sẵn có không (Windows 10 1809+ / Windows 11)
# ===========================================================================
Say "Bước 0/6: kiểm tra winget (trình cài đặt Windows App)"
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Warn "winget chưa có. Mở Microsoft Store cài 'App Installer' rồi chạy lại."
    Warn "(Windows 11 và Windows 10 21H1+ đã có sẵn winget — nếu không thấy, update Windows.)"
    $cont = Read-Host "tiếp tục dù winget không có? (y/N)"
    if ($cont -ne "y") { Die "cần winget để cài git + docker tự động." }
}

# ===========================================================================
# Bước 1: Git
# ===========================================================================
Say "Bước 1/6: kiểm tra git"
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Say "cài git..."
    if ($winget) {
        winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + `
                    [System.Environment]::GetEnvironmentVariable("Path","User")
    } else { Die "winget không có — cài git thủ công: https://git-scm.com/download/win" }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { Die "git vẫn chưa có sau khi cài — mở PowerShell mới và chạy lại script." }
}
Ok "git đã cài: $(git --version)"

# ===========================================================================
# Bước 2: clone repo
# ===========================================================================
Say "Bước 2/6: clone repo về $RepoDir"
if (Test-Path "$RepoDir\.git") {
    Say "repo đã có — pull mới"
    git -C $RepoDir pull --ff-only
} else {
    if (Test-Path $RepoDir) { Remove-Item -Recurse -Force $RepoDir }
    git clone $RemoteUrl $RepoDir
    if (-not $?) { Die "clone repo thất bại" }
}
Set-Location $RepoDir
Ok "repo đã sẵn sàng"

# ===========================================================================
# Bước 3: Docker Desktop
# ===========================================================================
Say "Bước 3/6: kiểm tra Docker Desktop"
$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
    $dockerInstalled = Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (-not $dockerInstalled) {
        Say "cài Docker Desktop (qua winget)..."
        if ($winget) {
            winget install --id Docker.DockerDesktop --silent `
                --accept-package-agreements --accept-source-agreements
        } else {
            Die "winget không có — tải Docker Desktop thủ công: https://docker.com/products/docker-desktop"
        }
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + `
                    [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    Say "khởi động Docker Desktop..."
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
} else {
    # đã cài, kiểm tra daemon có chạy không — nếu không thì mở app
    docker info | Out-Null
    if (-not $?) {
        Say "Docker daemon chưa chạy — mở Docker Desktop..."
        Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    }
}

Say "đợi Docker daemon (góc dưới-phải Docker Desktop phải hiện 'Engine running')..."
for ($i = 1; $i -le 150; $i++) {
    if (docker info 2>$null | Out-Null; $LASTEXITCODE -eq 0) {
        Ok "Docker daemon sẵn sàng"
        break
    }
    if ($i % 5 -eq 0) { Write-Host "  đợi Docker... $(( $i * 2 ))s" }
    Start-Sleep -Seconds 2
    if ($i -eq 150) { Die "Docker daemon không lên sau 300s. Mở Docker Desktop thủ công rồi chạy lại script." }
}

# ===========================================================================
# Bước 4: docker network (subnet 10.200.0.0/24 — tránh trùng LAN 172.x)
# + mở Windows Firewall cho ICMPv4 (ping) từ master tới station
# ===========================================================================
Say "Bước 4/6: tạo docker network football-net (subnet 10.200.0.0/24) + mở firewall ICMPv4"
docker network inspect football-net 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    docker network create --subnet 10.200.0.0/24 football-net
    if ($LASTEXITCODE -ne 0) { Die "tạo network thất bại" }
    Ok "đã tạo network football-net"
} else {
    # Kiểm tra subnet có đang là 172.x không (trùng LAN)
    $subnet = docker network inspect football-net --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'
    if ($subnet -like "172.18.*") {
        Warn "network football-net đang dùng subnet $subnet — trùng LAN, sẽ rebuild"
        docker network rm football-net
        docker network create --subnet 10.200.0.0/24 football-net
    }
    Ok "network football-net đã có"
}

# Cho phép ping (ICMPv4 echo request) vào máy này — master cần ping station để check.
# Yêu cầu quyền admin. Nếu không admin sẽ warn và skip (vẫn tiếp tục).
$icmpRule = 'netsh advfirewall firewall add rule name="Allow ICMPv4" protocol=icmpv4:8,any dir=in action=allow'
try {
    Invoke-Expression $icmpRule | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Ok "đã cho phép ICMPv4 inbound — master có thể ping station"
    } else {
        Warn "không thêm được rule ICMPv4 (code $LASTEXITCODE) — cần chạy PowerShell admin."
    }
} catch {
    Warn "không thêm được rule ICMPv4 — chạy lệnh thủ công dưới quyền admin:"
    Warn "  $icmpRule"
}

# ===========================================================================
# Bước 5: hỏi IP → viết .env.station
# ===========================================================================
Say "Bước 5/6: cấu hình .env.station"

# Lấy IP LAN hiện tại làm gợi ý (192.168.x hoặc 10.x — tránh 172.18.x)
$ipHints = @()
try {
    $ipHints = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.PrefixOrigin -eq "Dhcp" -and $_.IPAddress -notlike "169.254.*" } |
        Select-Object -ExpandProperty IPAddress)
} catch {}
$hintIp = ($ipHints | Where-Object { $_ -notlike "172.*" } | Select-Object -First 1)

$prompt = "Nhập IP của máy trạm này trên LAN"
if ($hintIp) { $prompt += " (gợi ý: $hintIp — nhấn Enter để chọn)" }
$prompt += ": "
$stationIp = Read-Host $prompt
$stationIp = $stationIp.Trim()
if (-not $stationIp -and $hintIp) { $stationIp = $hintIp }
if (-not $stationIp -match '^\d+\.\d+\.\d+\.\d+$') { Die "IP máy trạm không hợp lệ: $stationIp" }
if ($stationIp -like "172.18.*") {
    Warn "IP máy trạm là 172.18.x — trùng Docker subnet, có thể không kết nối được. Nên dùng 192.168.x hoặc 10.x."
}

$prompt2 = "Nhập IP của máy chủ (master) (Enter cho mặc định $MasterHostDefault): "
$masterIp = Read-Host $prompt2
$masterIp = $masterIp.Trim()
if (-not $masterIp) { $masterIp = $MasterHostDefault }
if (-not $masterIp -match '^\d+\.\d+\.\d+\.\d+$') { Die "IP master không hợp lệ: $masterIp" }

# Test kết nối tới master (không bắt buộc)
$tcpTest = Test-NetConnection -ComputerName $masterIp -Port $MasterPortDefault -WarningAction SilentlyContinue
if ($tcpTest.TcpTestSucceeded) {
    Ok "đã thấy master $masterIp`:$MasterPortDefault mở port"
} else {
    Warn "chưa kết nối được tới master $masterIp`:$MasterPortDefault."
    Warn "bảo người chạy master 'make up-master' xong trước, rồi tiếp tục bước 6."
}

# Sinh .env.station
$envContent = @"
# .env.station — tạo bởi setup-station.ps1
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123
POSTGRES_DB=football
POSTGRES_PORT=$StationPortDefault
NODE_ROLE=station
STATION_ID=1
CONTAINER_NAME=football-station
NETWORK_NAME=football-net
NETWORK_ALIAS=station
REPLICATION_SLOT=master_slot
# Master (máy chủ):
MASTER_HOST=$masterIp
MASTER_PORT=$MasterPortDefault
MASTER_DB=football
# Địa chỉ master dùng để quay lại station này (demo.message station -> master):
STATION_PUBLIC_HOST=$stationIp
STATION_PUBLIC_PORT=$StationPortDefault
STATION_PUBLIC_DB=football
"@
$envContent | Set-Content -Path "$RepoDir\.env.station" -Encoding ASCII
Ok ".env.station đã ghi: MASTER_HOST=$masterIp  STATION_PUBLIC_HOST=$stationIp"

# ===========================================================================
# Bước 6: up + migration + subscribe (làm trọn 2 chiều)
# ===========================================================================
Say "Bước 6/6: khởi động station container + migration + subscribe 2 chiều"

$compose = "docker compose -f docker-compose.yml -p football-station --env-file .env.station"
Say "docker compose up -d..."
Invoke-Expression "$compose up -d"
if ($LASTEXITCODE -ne 0) { Die "docker compose up thất bại" }

# Đợi healthy
Say "đợi postgres healthy..."
for ($i = 1; $i -le 60; $i++) {
    $h = docker inspect -f '{{.State.Health.Status}}' football-station 2>$null
    if ($h -eq "healthy") { Ok "postgres sẵn sàng"; break }
    Start-Sleep -Seconds 2
    if ($i -eq 60) { Die "postgres không healthy sau 120s" }
}

# Migration
Say "chạy migration (common + station)..."
docker exec football-station bash /docker-entrypoint-initdb.d/init-node.sh
if ($LASTEXITCODE -ne 0) { Warn "migration báo lỗi — có thể đã chạy rồi, tiếp tục" }

# Subscribe: master -> station (ref.*)
Say "tạo master_subscription (master -> station, ref.*)..."
docker exec football-station bash /subscribe-master.sh
if ($LASTEXITCODE -ne 0) { Warn "master_subscription chưa tạo — kiểm tra master đã healthy?" }

# Register: station -> master (demo.message) — station tự psql sang master
if (Test-Path "$RepoDir\scripts\register-with-master.sh") {
    Say "đăng ký station_subscription trên master (demo.message station -> master)..."
    $pub = $envContent | Select-String "STATION_PUBLIC_HOST=(\S+)" | % { $_.Matches.Groups[1].Value }
    docker exec -e PGPASSWORD=admin123 football-station bash /register-with-master.sh
    if ($LASTEXITCODE -ne 0) { Warn "đăng ký station_subscription thất bại — kiểm tra master có thể reach lại station không" }
}

# In trạng thái subscription
Say "trạng thái subscription trên station:"
docker exec -e PGPASSWORD=admin123 football-station psql -U admin -d football `
    -c "SELECT subname, subenabled, subpublications FROM pg_subscription ORDER BY subname;"

Say "trạng thái subscription trên master:"
docker exec -e PGPASSWORD=admin123 football-station `
    psql -h $masterIp -p $MasterPortDefault -U admin -d football `
    -c "SELECT subname, subenabled, subpublications FROM pg_subscription ORDER BY subname;"

# Listen log
Say "theo dõi log station (Ctrl-C để thoát, replication vẫn chạy nền)."
Say "Ping master từ Station container: $masterIp`:$MasterPortDefault"
docker exec football-station pg_isready -h $masterIp -p $MasterPortDefault -U admin -d football

Say "logs:"
docker compose -f docker-compose.yml -p football-station --env-file .env.station logs -f --tail=50
