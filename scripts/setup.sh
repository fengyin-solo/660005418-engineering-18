#!/usr/bin/env bash
# =====================================================================
# setup.sh —— 一键准备本地联调环境（可重复执行）
#
# 做三件事：
#   1. 缺少 .env / .env.development 时，从 *.example 拷贝示例配置
#   2. 后端：创建 .venv 并安装 requirements.txt（本机无 pip 时自动引导）
#   3. 前端：npm install
#
# 任意一步失败都会给出明确提示并以非零码退出，绝不静默跳过。
# =====================================================================
set -euo pipefail
source "$(dirname "$0")/_common.sh"

log "${C_BOLD}准备本地联调环境${C_RESET}（仓库: $ROOT_DIR）"

need_cmd python3
need_cmd node
need_cmd npm
need_cmd curl

PY_VER=$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')
PY_OK=$(python3 -c 'import sys;print(1 if sys.version_info>=(3,9) else 0)')
[ "$PY_OK" = "1" ] || die "Python 版本过低（当前 $PY_VER），需要 3.9+"
ok "Python $PY_VER / Node $(node --version)"

# ---------- 1. 示例配置 ----------
if [ ! -f "$BACKEND_DIR/.env" ]; then
  cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"
  ok "已生成 backend/.env（来自 .env.example）"
else
  log "backend/.env 已存在，保留不动"
fi
if [ ! -f "$FRONTEND_DIR/.env.development" ]; then
  cp "$FRONTEND_DIR/.env.development.example" "$FRONTEND_DIR/.env.development"
  ok "已生成 frontend/.env.development（来自 .env.development.example）"
else
  log "frontend/.env.development 已存在，保留不动"
fi

# ---------- 2. 后端虚拟环境 + 依赖 ----------
VENV_OK=0
if [ -x "$VENV_PY" ] && "$VENV_PY" -c 'import fastapi, uvicorn, numpy' >/dev/null 2>&1; then
  VENV_OK=1
  ok "后端虚拟环境与依赖已就绪"
fi

if [ "$VENV_OK" = "0" ]; then
  if [ -d "$VENV_DIR" ] && [ ! -x "$VENV_PY" ]; then
    warn "检测到已存在但不可用的 $VENV_DIR（可能是其他系统/Python 版本创建），删除后重建"
    rm -rf "$VENV_DIR"
  fi
  if [ ! -d "$VENV_DIR" ]; then
    log "创建后端虚拟环境 .venv ..."
    if python3 -m venv "$VENV_DIR" >/dev/null 2>&1; then
      :
    else
      # Debian/Ubuntu 精简镜像常缺 ensurepip（无 root 无法 apt install python3-venv），
      # 退回 --without-pip + get-pip.py 引导。
      warn "python3 -m venv 失败（通常缺少 python3-venv / ensurepip），尝试用 --without-pip 方式创建"
      python3 -m venv --without-pip "$VENV_DIR"
      log "通过 get-pip.py 引导 pip ..."
      curl -fsSL https://bootstrap.pypa.io/get-pip.py -o "$VENV_DIR/get-pip.py" \
        || die "下载 get-pip.py 失败，请检查网络后重试"
      "$VENV_PY" "$VENV_DIR/get-pip.py" --disable-pip-version-check \
        || die "pip 引导失败，请尝试手动安装：apt install python3-venv（需 root）"
      rm -f "$VENV_DIR/get-pip.py"
    fi
  fi

  [ -x "$VENV_PY" ] || die "$VENV_PY 不存在，虚拟环境创建异常，请删除 $VENV_DIR 后重试"
  log "安装后端依赖（requirements.txt）..."
  "$VENV_PY" -m pip install --disable-pip-version-check -r "$BACKEND_DIR/requirements.txt" \
    || die "后端依赖安装失败，请检查网络/pip 源配置后重试"
  "$VENV_PY" -c 'import fastapi, uvicorn, numpy' \
    || die "后端依赖安装后自检失败（fastapi/uvicorn/numpy 无法导入）"
  ok "后端依赖安装完成"
fi

# ---------- 3. 前端依赖 ----------
if [ -d "$FRONTEND_DIR/node_modules" ] && [ -f "$FRONTEND_DIR/node_modules/.bin/vite" ]; then
  ok "前端依赖已存在（node_modules），跳过安装；如需强制刷新请删除该目录"
else
  log "安装前端依赖（npm install，可能需要几分钟）..."
  ( cd "$FRONTEND_DIR" && npm install ) || die "npm install 失败，请检查网络/npm 源配置后重试"
  ok "前端依赖安装完成"
fi

# 端口配置来源以生成的 .env 为准（_common.sh 在文件拷贝前已解析，这里重读）
BACKEND_PORT=$(dotenv_get "$BACKEND_DIR/.env" LOG_API_PORT 8000)
FRONTEND_PORT=$(dotenv_get "$FRONTEND_DIR/.env.development" VITE_DEV_PORT 3000)

cat <<EOF

${C_GREEN}${C_BOLD}环境准备完成${C_RESET}
  启动联调：  scripts/dev.sh
  打包构建：  scripts/build.sh
  冒烟自检：  先启动 dev.sh，再执行 scripts/smoke-test.sh
  后端地址：  http://127.0.0.1:${BACKEND_PORT}
  前端地址：  http://127.0.0.1:${FRONTEND_PORT}
EOF
