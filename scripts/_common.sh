#!/usr/bin/env bash
# 各脚本共用的工具函数与配置解析。
# 约定：本文件只被 source，不直接执行。

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"
VENV_DIR="$BACKEND_DIR/.venv"
VENV_PY="$VENV_DIR/bin/python"

# ---------- 终端输出 ----------
if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[36m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_BOLD=''; C_RESET=''
fi

log()  { printf '%s\n' "${C_BLUE}[$(date +%H:%M:%S)]${C_RESET} $*"; }
ok()   { printf '%s\n' "${C_GREEN}[$(date +%H:%M:%S)] ✔${C_RESET} $*"; }
warn() { printf '%s\n' "${C_YELLOW}[$(date +%H:%M:%S)] !${C_RESET} $*"; }
die()  { printf '%s\n' "${C_RED}[$(date +%H:%M:%S)] ✘ $*${C_RESET}" >&2; exit 1; }

# ---------- .env 解析 ----------
# 用法: dotenv_get <env文件> <key> [默认值]
# 已导出的同名环境变量优先于 .env 文件。
dotenv_get() {
  _file=$1; _key=$2; _default=${3:-}
  eval "_cur=\${$_key:-}"
  if [ -n "${_cur:-}" ]; then printf '%s' "$_cur"; return 0; fi
  if [ -f "$_file" ]; then
    _line=$(sed -n "s/^[[:space:]]*${_key}[[:space:]]*=[[:space:]]*//p" "$_file" | tail -n1)
    _line=${_line%"${_line##*[![:space:]]}"}
    _line=${_line#\"}; _line=${_line%\"}
    _line=${_line#\'}; _line=${_line%\'}
    if [ -n "$_line" ]; then printf '%s' "$_line"; return 0; fi
  fi
  printf '%s' "$_default"
}

BACKEND_HOST=$(dotenv_get "$BACKEND_DIR/.env" LOG_API_HOST 127.0.0.1)
BACKEND_PORT=$(dotenv_get "$BACKEND_DIR/.env" LOG_API_PORT 8000)
FRONTEND_PORT=$(dotenv_get "$FRONTEND_DIR/.env.development" VITE_DEV_PORT 3000)

# ---------- 依赖检查 ----------
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "未找到命令 '$1'，请先安装后重试（详见 README.md「环境要求」）。"
}

# ---------- 端口检查 ----------
# 用法: assert_port_free <port> <服务名>
assert_port_free() {
  _port=$1; _name=$2
  if python3 - "$_port" <<'PY' 2>/dev/null
import socket, sys
sys.exit(0 if socket.socket().connect_ex(("127.0.0.1", int(sys.argv[1]))) != 0 else 1)
PY
  then
    return 0
  fi
  printf '%s\n' "${C_RED}端口 $_port 已被占用，$_name 无法启动：${C_RESET}" >&2
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$_port" -sTCP:LISTEN 2>/dev/null | sed 's/^/    /' >&2
  elif command -v ss >/dev/null 2>&1; then
    ss -ltnp "sport = :$_port" 2>/dev/null | sed 's/^/    /' >&2
  fi
  die "请先停止占用进程，或在 backend/.env 与 frontend/.env.development 中改用其他端口（两处需同步修改）。"
}

# ---------- 就绪探针 ----------
# 用法: wait_for_http <url> <超时秒数>
wait_for_http() {
  _url=$1; _timeout=${2:-30}
  python3 - "$_url" "$_timeout" <<'PY'
import sys, time, urllib.request
url, timeout = sys.argv[1], int(sys.argv[2])
deadline = time.time() + timeout
while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=2) as r:
            if 200 <= r.status < 500:
                sys.exit(0)
    except Exception:
        time.sleep(0.5)
sys.exit(1)
PY
}
