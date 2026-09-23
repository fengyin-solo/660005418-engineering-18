# 分布式日志聚合与智能异常检测平台

基于 Vue 3 + FastAPI 的企业级日志分析平台，正则/Grok 解析、滑动窗口聚合、3-sigma+IQR 双算法异常检测、全文检索。

## 目标用户
SRE 工程师、DevOps 团队、系统运维人员

## 技术栈
- 前端：Vue 3 + TypeScript + Vite + Pinia + Element Plus + ECharts
- 后端：Python FastAPI + NumPy + Uvicorn

## 核心功能
1. 多源日志流接入：支持 Apache/NGINX/应用 JSON/自定义格式四种日志类型模拟
2. 正则/Grok 日志解析引擎：自动提取 timestamp/level/source/message 字段
3. 滑动时间窗口聚合统计：按窗口统计日志级别、来源与关键词命中
4. 3-sigma + IQR 双算法异常检测：分别基于正态分布和四分位距的异常分数计算
5. 倒排索引全文搜索：词频匹配 + 布尔 AND/OR 查询
6. 告警规则管理：阈值告警 + 异常分数告警 + 关键词命中告警三级
7. ECharts 日志量趋势 + 异常分布热力图 + 告警时间线

---

## 环境要求

| 依赖 | 版本 | 说明 |
| --- | --- | --- |
| Python | 3.9+ | 后端运行环境 |
| Node.js | 18+（推荐 20） | 前端构建环境 |
| npm | 9+ | 随 Node 安装 |
| curl | 任意 | 首次安装时用于引导 pip |

> Linux 精简镜像若缺少 `python3-venv`（`python3 -m venv` 报错）且没有 root 权限，
> 安装脚本会自动改用 `venv --without-pip` + `get-pip.py` 引导，无需手动处理。

---

## 快速开始（干净环境三步）

所有命令在仓库根目录执行，脚本可重复执行。

```bash
# 1. 安装依赖（自动生成 .env 配置、创建后端 .venv、安装前端依赖）
scripts/setup.sh

# 2. 一键启动前后端联调（启动前自动检查依赖与端口占用）
scripts/dev.sh

# 3. 另开终端，验证「生成日志 -> 异常检测 -> 告警输出」整条链路
scripts/smoke-test.sh
```

启动成功后：

- 前端页面：http://127.0.0.1:3000 —— 点「🔍 生成日志」再点「⚠ 检测异常」，右侧「🚨 告警列表」应出现 `关键词命中` 告警。
- 后端接口：http://127.0.0.1:8000 ，健康检查 http://127.0.0.1:8000/health
- `Ctrl+C` 会同时停止前后端。

打包构建（类型检查 + 产物输出到 `frontend/dist`）：

```bash
scripts/build.sh
```

---

## 环境配置（地址 / 端口 / 代理唯一来源）

接口地址、端口与代理目标**不再写死在代码里**，统一由环境配置提供。
`setup.sh` 首次运行时会自动从示例文件拷贝出本地配置（本地配置已被 `.gitignore` 忽略）：

| 配置文件 | 示例 | 作用 |
| --- | --- | --- |
| `backend/.env` | `backend/.env.example` | 日志接口监听地址/端口、CORS 来源 |
| `frontend/.env.development` | `frontend/.env.development.example` | dev server 端口、日志接口代理目标、API baseURL |

### `backend/.env.example`

```ini
# 日志接口（FastAPI）监听配置
LOG_API_HOST=127.0.0.1
LOG_API_PORT=8000
# 允许跨域来源（逗号分隔），对应前端 dev server 地址
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
```

### `frontend/.env.development.example`

```ini
# dev server 监听端口
VITE_DEV_PORT=3000
# /api、/ws 的代理目标，必须与 backend/.env 的 HOST/PORT 保持一致
VITE_LOG_API_TARGET=http://127.0.0.1:8000
# 前端请求日志接口的 baseURL，走 Vite 代理时保持 /api；直连时改为 http://127.0.0.1:8000/api
VITE_LOG_API_BASE=/api
```

配置优先级：**shell / CI 注入的环境变量 > 本地 `.env` 文件 > 代码内默认值**。

### 修改端口的正确姿势

改端口需前后端两处同步，否则代理会指向不存在的地址（以 18000 / 13000 为例）：

1. `backend/.env`：`LOG_API_PORT=18000`
2. `frontend/.env.development`：`VITE_DEV_PORT=13000`、`VITE_LOG_API_TARGET=http://127.0.0.1:18000`
3. `backend/.env`：`CORS_ORIGINS` 追加 `http://localhost:13000,http://127.0.0.1:13000`

### 与其他环境保持一致的写法

后端在任何环境都通过同一组变量读取配置，生产启动例如：

```bash
cd backend
LOG_API_HOST=0.0.0.0 LOG_API_PORT=8000 .venv/bin/uvicorn app.main:app
```

前端生产构建可用 `--mode` 指定环境文件（如 `.env.production`），变量命名沿用同一套 `VITE_LOG_API_*`。

---

## 告警口径 × 日志生成联调说明

联调链路固定为：

```
前端「生成日志」 POST /api/generate  -> 后端按模板生成 1000 条日志 + 窗口聚合
前端「检测异常」 POST /api/detect    -> 3-sigma/IQR 打分 + 按启用规则产出告警
前端告警列表 / smoke-test.sh         <- alerts[]
```

默认启用的告警规则（见 `frontend/src/store/log.ts`）：

| 规则 | 类型 | 口径 |
| --- | --- | --- |
| 高频ERROR | level | 窗口内 ERROR 条数 > 5（默认关闭） |
| 异常流量 | count | 窗口日志量 > 200（默认关闭） |
| 关键词命中 | keyword | 窗口内关键词（默认 `timeout`，不区分大小写）命中次数 > 0 |

NGINX 日志模板自带 `connection timeout upstream` 等消息，因此干净环境下关键词规则可稳定触发，
保证链路一跑就通；联调其他口径时，在前端规则对象中调整 `type` / `threshold` / `keyword` 即可，后端逐窗口判定。

也可以直接调接口验证：

```bash
curl -s http://127.0.0.1:8000/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"type":"nginx","count":1000}' | head -c 200
```

---

## 常见问题

- **提示「未找到命令 'python3'/'node'/'npm'」**：先安装对应运行时（见「环境要求」）。
- **提示「后端/前端依赖不完整」**：执行 `scripts/setup.sh`；脚本会明确指出是哪一侧缺失。
- **提示「端口已被占用」**：脚本会用 `lsof`/`ss` 打印占用进程；停止该进程，或按上文「修改端口的正确姿势」换端口。
- **页面提示「无法连接日志接口」**：确认后端已启动、`/health` 可访问，并核对 `VITE_LOG_API_TARGET` 与 `backend/.env` 一致。
- **脚本可重复执行**：已存在的虚拟环境 / `node_modules` 自检通过则跳过安装；配置文件已存在则保留本地修改不覆盖。

## 目录结构

```
.
├── backend/
│   ├── .env.example           # 日志接口地址/端口/CORS 示例配置
│   ├── app/
│   │   ├── config.py          # 统一环境配置（.env + 环境变量 + 默认值）
│   │   └── main.py            # FastAPI：日志生成 / 异常检测 / 告警口径
│   ├── requirements.txt
│   └── run.py                 # 本地启动入口（HOST/PORT 取自配置）
├── frontend/
│   ├── .env.development.example  # 端口/代理目标/baseURL 示例配置
│   ├── src/
│   └── vite.config.ts         # 代理目标取自环境配置，不再写死
└── scripts/
    ├── _common.sh             # 配置解析 / 依赖检查 / 端口检查 / 就绪探针
    ├── setup.sh               # 一键安装依赖
    ├── dev.sh                 # 一键启动前后端联调
    ├── build.sh               # 类型检查 + 打包
    └── smoke-test.sh          # 告警链路冒烟自检
```
