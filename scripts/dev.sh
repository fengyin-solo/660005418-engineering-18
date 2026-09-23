#!/usr/bin/env bash
# =====================================================================
# dev.sh —— 本地一键联调（可重复执行）
#
#   - 缺依赖时给出明确提示（并建议运行 scripts/setup.sh）
#   - 启动前检查端口占用，占用则直接报错退出，不静默失败
#   - 同时拉起后端日志接口与前端 Vite dev server
#   - 等待双方就绪后打印访问地址；Ctrl+C 一并停止全部子进程
# =====================================================================
set -euo pipefail
source "$(dirname "$0")/_common.sh"

# ---------- 配置缺失则补齐，然后重新加载端口变量 ----------
[ -f "$BACKEND_DIR/.env" ] || cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"
[ -f "$FRONTEND_DIR/.env.development" ] || cp "$FRONTEND_DIR/.env.development.example" "$FRONTEND_DIR/.env.development"
source "$(dirname "$0")/_common.sh"

log "${C_BOLD}启动本地联调环境${C_RESET}"

# ---------- 依赖自检 ----------
[ -x "$VENV_PY" ] || die "后端虚拟环境不存在，请先执行 scripts/setup.sh"
"$VENV_PY" -c 'import fastapi, uvicorn, numpy' >/dev/null 2>&1 \
  || die "后端依赖不完整（fastapi/uvicorn/numpy 缺失），请执行 scripts/setup.sh"
[ -f "$FRONTEND_DIR/node_modules/.bin/vite" ] \
  || die "前端依赖不完整（node_modules 缺失），请执行 scripts/setup.sh"

# ---------- 端口占用检查 ----------
assert_port_free "$BACKEND_PORT" "后端日志接口"
assert_port_free "$FRONTEND_PORT" "前端 dev server"

# ---------- 启动 ----------
BACKEND_PID=""; FRONTEND_PID=""
cleanup() {
  # 仅回收进程，不打印；由 shutdown / die 决定输出
  [ -n "$FRONTEND_PID" ] && kill "$FRONTEND_PID" 2>/dev/null || true
  [ -n "$BACKEND_PID" ] && kill "$BACKEND_PID" 2>/dev/null || true
  # 兜底：清掉 vite/esbuild 等残留子进程
  pkill -P $$ 2>/dev/null || true
  wait 2>/dev/null || true
}
shutdown() {
  log "正在停止服务 ..."
  cleanup
  ok "已停止"
  exit 0
}
trap cleanup EXIT
trap shutdown INT TERM

log "启动后端日志接口：http://$BACKEND_HOST:$BACKEND_PORT"
( cd "$BACKEND_DIR" && "$VENV_PY" run.py ) &
BACKEND_PID=$!

if ! wait_for_http "http://127.0.0.1:$BACKEND_PORT/health" 30; then
  die "后端日志接口在 30s 内未就绪（http://127.0.0.1:$BACKEND_PORT/health 无响应），请查看上方后端日志"
fi
ok "后端已就绪：/health 通过"

log "启动前端 dev server：http://127.0.0.1:$FRONTEND_PORT"
( cd "$FRONTEND_DIR" && npm run dev -- --host 127.0.0.1 ) &
FRONTEND_PID=$!

if ! wait_for_http "http://127.0.0.1:$FRONTEND_PORT" 30; then
  die "前端 dev server 在 30s 内未就绪，请查看上方前端日志"
fi

cat <<EOF

${C_GREEN}${C_BOLD}联调环境已就绪${C_RESET}
  前端页面：  http://127.0.0.1:${FRONTEND_PORT}
  日志接口：  http://127.0.0.1:${BACKEND_PORT}（健康检查 /health）
  接口代理：  /api、/ws -> 由 frontend/.env.development 的 VITE_LOG_API_TARGET 决定
  验证链路：  页面点「生成日志」→「检测异常」，或另开终端运行 scripts/smoke-test.sh

  按 Ctrl+C 停止全部服务。
EOF

# 任一子进程退出则整体退出
wait -n "$BACKEND_PID" "$FRONTEND_PID" || true
die "有服务提前退出，请查看上方日志"
