#!/usr/bin/env bash
# 启动前后端开发服务（可重复执行；Ctrl+C 同时停止两个进程）
# 配置来源：backend/.env、frontend/.env（示例见对应 .env.example），同名 shell 环境变量优先
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# 1. 加载环境配置
load_env_file "$BACKEND_DIR/.env"
load_env_file "$FRONTEND_DIR/.env"
BACKEND_HOST="${BACKEND_HOST:-127.0.0.1}"
BACKEND_PORT="${BACKEND_PORT:-8000}"
DEV_PORT="${VITE_DEV_PORT:-3000}"
# 未显式配置 VITE_BACKEND_URL 时按后端配置推导，保证前后端口径一致
export VITE_BACKEND_URL="${VITE_BACKEND_URL:-http://$BACKEND_HOST:$BACKEND_PORT}"

# 2. 依赖检查：缺失时明确提示，而不是静默失败
[ -x "$VENV_DIR/bin/python" ] || die "后端虚拟环境不存在或已损坏，请先执行: scripts/setup.sh"
[ -d "$FRONTEND_DIR/node_modules" ] || die "前端依赖未安装，请先执行: scripts/setup.sh"

# 3. 端口检查：被占用时列出占用进程并退出
check_port_free "$BACKEND_PORT" "后端日志接口($BACKEND_HOST)"
check_port_free "$DEV_PORT" "前端开发服务器"

# 4. 启动前后端，任一退出则整体结束
PIDS=()

# 收集进程树（uvicorn --reload / npm 都会派生子进程），避免停止后遗留孤儿进程
descendants() {
  local pid="$1" child
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    echo "$child"
    descendants "$child"
  done
}

cleanup() {
  info "停止开发服务..."
  local targets=() pid
  for pid in "${PIDS[@]}"; do
    targets+=("$pid" $(descendants "$pid"))
  done
  kill "${targets[@]}" 2>/dev/null || true
  sleep 1
  kill -9 "${targets[@]}" 2>/dev/null || true
  wait "${PIDS[@]}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

info "启动后端日志接口: http://$BACKEND_HOST:$BACKEND_PORT"
cd "$BACKEND_DIR"
BACKEND_HOST="$BACKEND_HOST" BACKEND_PORT="$BACKEND_PORT" \
  "$VENV_DIR/bin/python" -m app.main &
PIDS+=($!)

info "启动前端开发服务器: http://localhost:$DEV_PORT （代理 /api -> $VITE_BACKEND_URL）"
cd "$FRONTEND_DIR"
npm run dev &
PIDS+=($!)

# 5. 等待前后端就绪，进程异常退出或超时都明确报错
wait_ready() {
  local name="$1" pid="$2" port="$3"
  local i
  for i in $(seq 1 30); do
    if _port_listen "$port"; then
      ok "$name 已就绪（端口 $port）"
      return 0
    fi
    kill -0 "$pid" 2>/dev/null || die "$name 进程异常退出，请检查上方日志"
    sleep 1
  done
  die "$name 30s 内未就绪（端口 $port），请检查上方日志"
}

info "等待服务就绪..."
wait_ready "后端日志接口" "${PIDS[0]}" "$BACKEND_PORT"
wait_ready "前端开发服务器" "${PIDS[1]}" "$DEV_PORT"

ok "开发环境已就绪：前端 http://localhost:$DEV_PORT ，日志接口 http://$BACKEND_HOST:$BACKEND_PORT/api"
info "在页面点击「生成日志」→「检测异常」即可验证告警链路；Ctrl+C 停止全部服务"
wait -n
