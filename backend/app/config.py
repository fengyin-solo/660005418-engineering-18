"""统一环境配置入口。

所有联调参数（日志接口地址、端口、跨域来源）均由环境变量提供，
未设置时读取 backend/.env，再回退到内置默认值。不在代码里写死。

仅使用标准库实现 .env 解析，避免在虚拟环境尚未就绪时引入额外依赖。
真实环境（容器/CI）注入的环境变量优先级最高，不会被 .env 覆盖。
"""
from __future__ import annotations

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = BASE_DIR / ".env"

_DEFAULTS = {
    "LOG_API_HOST": "127.0.0.1",
    "LOG_API_PORT": "8000",
    "CORS_ORIGINS": "http://localhost:3000,http://127.0.0.1:3000",
}


def _load_dotenv(path: Path) -> None:
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        # 已存在的环境变量（shell / CI 注入）优先
        if key and key not in os.environ:
            os.environ[key] = value


_load_dotenv(ENV_FILE)


def _port(value: str) -> int:
    try:
        port = int(value)
    except ValueError:
        raise ValueError(f"LOG_API_PORT 必须是数字，当前值: {value!r}")
    if not 1 <= port <= 65535:
        raise ValueError(f"LOG_API_PORT 超出范围: {port}")
    return port


LOG_API_HOST = os.environ.get("LOG_API_HOST", _DEFAULTS["LOG_API_HOST"])
LOG_API_PORT = _port(os.environ.get("LOG_API_PORT", _DEFAULTS["LOG_API_PORT"]))
CORS_ORIGINS = [
    origin.strip()
    for origin in os.environ.get("CORS_ORIGINS", _DEFAULTS["CORS_ORIGINS"]).split(",")
    if origin.strip()
]
