"""本地开发启动入口：地址与端口统一来自环境配置。

用法：
    python run.py
等价于 uvicorn app.main:app，但 HOST/PORT 不再散落在命令行里写死。
"""
from __future__ import annotations

import uvicorn

from app.config import LOG_API_HOST, LOG_API_PORT, ENV_FILE

if __name__ == "__main__":
    print(
        f"[backend] 日志接口: http://{LOG_API_HOST}:{LOG_API_PORT}"
        f"  (配置来源: 环境变量 / {ENV_FILE})"
    )
    uvicorn.run("app.main:app", host=LOG_API_HOST, port=LOG_API_PORT, reload=False)
