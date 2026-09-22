#!/usr/bin/env bash
# 打包构建（可重复执行）：后端语法校验 + 前端 vue-tsc 类型检查与 vite build
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# 依赖检查：缺失时明确提示，而不是静默失败
[ -x "$VENV_DIR/bin/python" ] || die "后端虚拟环境不存在或已损坏，请先执行: scripts/setup.sh"
[ -d "$FRONTEND_DIR/node_modules" ] || die "前端依赖未安装，请先执行: scripts/setup.sh"

load_env_file "$FRONTEND_DIR/.env"

info "后端语法校验"
"$VENV_DIR/bin/python" -m py_compile "$BACKEND_DIR/app/main.py" \
  || die "后端语法校验失败: backend/app/main.py"
ok "后端校验通过"

info "前端构建（vue-tsc && vite build）"
cd "$FRONTEND_DIR"
npm run build || die "前端构建失败，请根据上方输出修复后重试"
ok "构建完成，产物目录: $FRONTEND_DIR/dist"
