#!/usr/bin/env bash
# ===========================================================================
# setup-station.sh — Bootstrap máy trạm football-ddb cho non-tech.
#
# Tự động:
#   1. Cài Homebrew (nếu chưa có)
#   2. Cài git (nếu chưa có)
#   3. Clone repo football-station
#   4. Cài & khởi động Docker Desktop (nếu chưa có / chưa chạy)
#   5. Hỏi IP của máy trạm này, viết vào .env.station
#   6. Chạy `make start-station`
#
# Cách dùng (chỉ macOS):
#   1. Mở "Terminal" ( spotlight → gõ "Terminal" → Enter )
#   2. Dán lệnh này rồi Enter:
#
#      bash -c "$(curl -fsSL https://raw.githubusercontent.com/GnauqTheBeast/football-station/main/scripts/setup-station.sh)"
#
#   Hoặc nếu đã clone repo:    bash scripts/setup-station.sh
# ===========================================================================
set -uo pipefail

REMOTE_URL="https://github.com/GnauqTheBeast/football-station.git"
REPO_DIR="$HOME/football-station"
MASTER_HOST_DEFAULT="172.18.20.106"
MASTER_PORT_DEFAULT="5430"
STATION_PORT_DEFAULT="5431"

# --- màu ---
B='\033[1m'; C='\033[1;36m'; G='\033[1;32m'; Y='\033[1;33m'; R='\033[1;31m'; N='\033[0m'
say() { printf "${C}[setup]${N} %s\n" "$*"; }
ok()  { printf "${G}✓ %s${N}\n" "$*"; }
warn(){ printf "${Y}! %s${N}\n" "$*"; }
err() { printf "${R}✗ %s${N}\n" "$*" >&2; }
die() { err "$*"; exit 1; }

# Chỉ hỗ trợ macOS
if [ "$(uname -s)" != "Darwin" ]; then
  die "Script này hỗ trợ macOS. Trên Windows/Linux phải tự set thủ công."
fi

# ===========================================================================
# Bước 1: Homebrew
# ===========================================================================
say "Bước 1/6: kiểm tra Homebrew"
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew đã cài: $(brew --version | head -1)"
else
  warn "Homebrew chưa có — tiến hành cài (yêu cầu mật khẩu Mac 1 lần)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "Cài Homebrew thất bại. Cài thủ công: https://brew.sh"
  # Apple Silicon: thêm brew vào PATH
  if [ -d /opt/homebrew/bin ] && ! echo "$PATH" | grep -q /opt/homebrew/bin; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  ok "Homebrew đã cài"
fi

# ===========================================================================
# Bước 2: git
# ===========================================================================
say "Bước 2/6: kiểm tra git"
if command -v git >/dev/null 2>&1; then
  ok "git đã cài: $(git --version)"
else
  say "cài git..."
  brew install git || die "Cài git thất bại"
  ok "git đã cài"
fi

# ===========================================================================
# Bước 3: clone repo
# ===========================================================================
say "Bước 3/6: clone repo về $REPO_DIR"
if [ -d "$REPO_DIR/.git" ]; then
  say "repo đã có — pull mới"
  git -C "$REPO_DIR" pull --ff-only || warn "pull thất bại, tiếp tục với code hiện có"
else
  rm -rf "$REPO_DIR"
  git clone "$REMOTE_URL" "$REPO_DIR" || die "clone repo thất bại"
  ok "repo đã clone"
fi
cd "$REPO_DIR" || die "không vào được $REPO_DIR"

# ===========================================================================
# Bước 4: Docker Desktop
# ===========================================================================
say "Bước 4/6: kiểm tra Docker Desktop"
DOCKER_APP="/Applications/Docker.app"

need_install_docker=0
if ! [ -d "$DOCKER_APP" ]; then
  need_install_docker=1
else
  if ! docker info >/dev/null 2>&1; then
    need_install_docker=0  # đã cài nhưng chưa chạy
  fi
fi

if ! [ -d "$DOCKER_APP" ]; then
  warn "Docker Desktop chưa cài — cài qua Homebrew (chỉ bản core, nhẹ hơn tải gốc)..."
  brew install --cask docker || die "Cài Docker Desktop thất bại. Tải thủ công: https://docker.com/products/docker-desktop"
  ok "Docker Desktop đã cài"
fi

say "khởi động Docker Desktop..."
open -a Docker 2>/dev/null || true

# Đợi daemon (tối đa 5 phút — lần đầu Docker start chậm)
say "đợi Docker daemon sẵn sàng (vòng tròn Docker Desktop dưới cùng phải dừng xoay)..."
spin='|/-\'
for i in $(seq 1 150); do
  if docker info >/dev/null 2>&1; then
    printf "\n"
    ok "Docker daemon sẵn sàng"
    break
  fi
  c="${spin:$((i % 4)):1}"
  printf "\r  đợi Docker... [%s] %ds " "$c" "$((i*2))"
  sleep 2
  if [ "$i" -eq 150 ]; then
    printf "\n"
    die "Docker daemon không lên sau 300s. Mở Docker Desktop thủ công rồi chạy lại script."
  fi
done

# ===========================================================================
# Bước 5: hỏi IP máy trạm → viết .env.station
# ===========================================================================
say "Bước 5/6: cấu hình .env.station"

# Lấy IP LAN hiện tại đề xuất (192.168.x hoặc 10.x — tránh Docker 172.18).
hint_ip=$(ipconfig getifaddr en0 2>/dev/null || true)
if [ -z "$hint_ip" ] || [[ "$hint_ip" == 172.* ]]; then
  hint_ip=$(ipconfig getifaddr en1 2>/dev/null || true)
fi
if [[ "$hint_ip" == 172.* ]] || [ -z "$hint_ip" ]; then
  hint_ip=""
fi

printf "${B}Nhập IP của máy trạm này trên LAN${N}"
[ -n "$hint_ip" ] && printf " (gợi ý: ${G}%s${N}, nhấn Enter để chọn)" "$hint_ip"
printf ": "
read -r station_ip
station_ip="${station_ip:-$hint_ip}"
[ -n "$station_ip" ] || die "phải nhập IP máy trạm"

# Validate dạng x.y.z.t đúng
if ! echo "$station_ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  die "IP không hợp lệ: $station_ip (phải dạng a.b.c.d)"
fi
warn "khuyến cáo: 1 dùng IP LAN thật của máy mình (192.168.x hoặc 10.x), KHÔNG dùng 172.18.x (trùng subnet Docker)."

printf "${B}Nhập IP của máy chủ (master)${N} (Enter cho mặc định ${MASTER_HOST_DEFAULT}): "
read -r master_ip
master_ip="${master_ip:-$MASTER_HOST_DEFAULT}"
if ! echo "$master_ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  die "IP master không hợp lệ: $master_ip"
fi

# Kiểm tra reach tới master (không bắt buộc — chỉ warn)
if ! nc -z -w3 "$master_ip" "$MASTER_PORT_DEFAULT" 2>/dev/null; then
  warn "chưa kết nối được tới master $master_ip:$MASTER_PORT_DEFAULT — chắc master chưa up? Hãy bảo người chạy master up trước, rồi chạy lại bước 6."
else
  ok "đã thấy master $master_ip:$MASTER_PORT_DEFAULT mở port"
fi

# Đảm bảo IP máy trạm không trùng subnet Docker 172.18.x — chọn lại port host trạm nếu cần
case "$station_ip" in
  172.18.*) warn "IP máy trạm là 172.18.x — trùng Docker subnet, có thể master không reach lại được. Nếu sau bước 6 báo 'Host is unreachable', đổi sang IP LAN thật (192.168.x or 10.x)." ;;
esac

# Tạo .env.station từ template đã commit
cat > .env.station <<EOF
# .env.station — tạo bởi setup-station.sh
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123
POSTGRES_DB=football
POSTGRES_PORT=${STATION_PORT_DEFAULT}
NODE_ROLE=station
STATION_ID=1
CONTAINER_NAME=football-station
NETWORK_NAME=football-net
NETWORK_ALIAS=station
REPLICATION_SLOT=master_slot
# Master (máy chủ):
MASTER_HOST=${master_ip}
MASTER_PORT=${MASTER_PORT_DEFAULT}
MASTER_DB=football
# Địa chỉ master dùng để quay lại station này (demo.message station -> master):
STATION_PUBLIC_HOST=${station_ip}
STATION_PUBLIC_PORT=${STATION_PORT_DEFAULT}
STATION_PUBLIC_DB=football
EOF
ok ".env.station đã ghi: MASTER_HOST=$master_ip  STATION_PUBLIC_HOST=$station_ip"

# ===========================================================================
# Bước 6: make start-station
# ===========================================================================
say "Bước 6/6: chạy make start-station (up + migration + subscribe 2 chiều + listen log)"

# Cài make nếu thiếu (rất ít máy có make sẵn — Xcode CLI tools có)
if ! command -v make >/dev/null 2>&1; then
  warn "make chưa có — cài Xcode Command Line Tools (yêu cầu mật khẩu 1 lần)..."
  xcode-select --install 2>/dev/null
  say "sau khi Xcode tools cài xong, nhấn Enter để tiếp tục..."
  read -r
  command -v make >/dev/null 2>&1 || die "make vẫn chưa có sau khi cài Xcode tools. Mở Terminal gõ: xcode-select --install"
fi

echo
ok "BẮT ĐẦU — để script chạy tới khi thấy dòng [start-station] theo dõi log station."
ok "Đang chạy: make start-station"
echo
make start-station
