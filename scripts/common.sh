#!/usr/bin/env bash
# 公共函数：日志输出、依赖检查、环境配置加载、端口占用检查
# 被 scripts/setup.sh、scripts/dev.sh、scripts/build.sh source 使用

if [ -t 1 ]; then
  C_RED='\033[31m'; C_GREEN='\033[32m'; C_YELLOW='\033[33m'; C_BLUE='\033[34m'; C_RESET='\033[0m'
else
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_RESET=''
fi

info()  { printf "${C_BLUE}[INFO]${C_RESET} %s\n" "$*"; }
ok()    { printf "${C_GREEN}[OK]${C_RESET} %s\n" "$*"; }
warn()  { printf "${C_YELLOW}[WARN]${C_RESET} %s\n" "$*"; }
error() { printf "${C_RED}[ERROR]${C_RESET} %s\n" "$*" >&2; }
die()   { error "$*"; exit 1; }

# 项目目录（scripts/ 的上一级）
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"
VENV_DIR="$BACKEND_DIR/.venv"

# 缺少命令时明确报错并给出安装提示
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少依赖命令: $1。$2"
}

# 加载 env 文件（KEY=VALUE，支持 # 整行注释与成对引号）；
# 已存在的同名环境变量优先，不会被文件覆盖
load_env_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  info "加载环境配置: $file"
  local line key value
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    key="${line%%=*}"
    value="${line#*=}"
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    value="${value%\"}"; value="${value#\"}"
    value="${value%\'}"; value="${value#\'}"
    [ -n "$key" ] || continue
    if [ -z "${!key:-}" ]; then
      export "$key=$value"
    fi
  done < "$file"
}

# 端口是否有服务在监听（同时检查 IPv4 与 IPv6 的 localhost）
_port_listen() {
  python3 - "$1" <<'EOF'
import socket, sys
port = int(sys.argv[1])
for family, addr in ((socket.AF_INET, "127.0.0.1"), (socket.AF_INET6, "::1")):
    try:
        s = socket.socket(family)
        s.settimeout(0.5)
        if s.connect_ex((addr, port)) == 0:
            sys.exit(0)
    except OSError:
        pass
sys.exit(1)
EOF
}

# 端口被占用时列出占用进程并退出，而不是静默继续
check_port_free() {
  local port="$1" name="$2"
  if ! _port_listen "$port"; then
    return 0
  fi
  error "$name 端口 $port 已被占用："
  if command -v ss >/dev/null 2>&1; then
    ss -ltnp 2>/dev/null | grep -E "[:.]$port[[:space:]]" | sed 's/^/    /' >&2 || true
  elif command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | sed 's/^/    /' >&2 || true
  fi
  die "请先停止占用进程，或在 .env 配置中修改端口后重试。"
}
