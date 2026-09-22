#!/usr/bin/env bash
# 安装前后端依赖（可重复执行）：backend/.venv + requirements.txt，frontend npm install
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

info "检查基础依赖..."
need_cmd python3 "请先安装 Python 3.9+（如 apt install python3）"
need_cmd node    "请先安装 Node.js 18+（https://nodejs.org）"
need_cmd npm     "请先安装 npm（通常随 Node.js 一起安装）"
ok "python3=$(python3 --version 2>&1 | awk '{print $2}') node=$(node --version) npm=$(npm --version)"

# ---------- 后端 ----------
if [ -x "$VENV_DIR/bin/python" ] && "$VENV_DIR/bin/python" --version >/dev/null 2>&1; then
  ok "后端虚拟环境已存在且可用，跳过创建"
else
  [ -d "$VENV_DIR" ] && warn "检测到损坏的虚拟环境 $VENV_DIR，重新创建"
  rm -rf "$VENV_DIR"
  # 系统缺少 ensurepip（未装 python3-venv）时 venv 会返回非零，但解释器已就绪，下面单独引导 pip
  python3 -m venv "$VENV_DIR" 2>/dev/null || true
  [ -x "$VENV_DIR/bin/python" ] || die "虚拟环境创建失败。Debian/Ubuntu 请先执行: sudo apt install python3-venv"
  ok "后端虚拟环境已创建: $VENV_DIR"
fi

if ! "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then
  warn "虚拟环境缺少 pip，使用 get-pip.py 引导安装"
  GET_PIP="$(mktemp /tmp/get-pip.XXXXXX.py)"
  "$VENV_DIR/bin/python" -c "import urllib.request; urllib.request.urlretrieve('https://bootstrap.pypa.io/get-pip.py', '$GET_PIP')" \
    || die "get-pip.py 下载失败，请检查网络后重试"
  "$VENV_DIR/bin/python" "$GET_PIP" || die "pip 引导安装失败"
  rm -f "$GET_PIP"
fi

info "安装后端依赖 backend/requirements.txt"
"$VENV_DIR/bin/python" -m pip install -r "$BACKEND_DIR/requirements.txt"
ok "后端依赖就绪"

# ---------- 前端 ----------
info "安装前端依赖（frontend/npm install）"
cd "$FRONTEND_DIR"
npm install || die "npm install 失败，请检查网络或 npm registry 配置后重试"
ok "前端依赖就绪"

ok "依赖安装完成，执行 scripts/dev.sh 启动开发环境"
