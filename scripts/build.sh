#!/usr/bin/env bash
# =====================================================================
# build.sh —— 打包构建（可重复执行）
#
#   - 后端：在虚拟环境中做语法/导入自检
#   - 前端：vue-tsc 类型检查 + vite build，产物输出到 frontend/dist
# =====================================================================
set -euo pipefail
source "$(dirname "$0")/_common.sh"

log "${C_BOLD}开始打包构建${C_RESET}"

[ -x "$VENV_PY" ] || die "后端虚拟环境不存在，请先执行 scripts/setup.sh"
[ -f "$FRONTEND_DIR/node_modules/.bin/vite" ] || die "前端依赖不完整，请先执行 scripts/setup.sh"

log "后端自检（语法 + 导入）..."
( cd "$BACKEND_DIR" && "$VENV_PY" -m py_compile app/*.py run.py ) \
  || die "后端 Python 语法检查失败"
( cd "$BACKEND_DIR" && "$VENV_PY" -c "from app.main import app; from app.config import LOG_API_PORT; print('backend import ok, port =', LOG_API_PORT)" ) \
  || die "后端导入检查失败"
ok "后端自检通过"

log "前端类型检查 + 构建（vite build）..."
( cd "$FRONTEND_DIR" && npm run build ) || die "前端构建失败，请查看上方 TypeScript / Vite 报错"
ok "前端构建完成，产物位于 frontend/dist/"

cat <<EOF

${C_GREEN}${C_BOLD}构建成功${C_RESET}
  前端产物：  $FRONTEND_DIR/dist
  生产运行：  后端使用任意 ASGI Server，例如
              cd backend && .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port $BACKEND_PORT
             （HOST/PORT 同样支持 LOG_API_HOST / LOG_API_PORT 环境变量覆盖）
EOF
