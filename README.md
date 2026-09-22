# 分布式日志聚合与智能异常检测平台

基于Vue 3 + FastAPI的企业级日志分析平台，正则/Grok解析、滑动窗口聚合、3-sigma+IQR双算法异常检测、全文检索。

## 目标用户
SRE工程师、DevOps团队、系统运维人员

## 技术栈
- 前端: Vue 3 + TypeScript + Vite + Pinia + Element Plus + ECharts
- 后端: Python FastAPI + NumPy + SQLite + WebSocket

## 核心功能
1. 多源日志流接入：支持Apache/NGINX/应用JSON/自定义格式四种日志类型模拟
2. 正则/Grok日志解析引擎：自动提取timestamp/level/source/message字段
3. 滑动时间窗口聚合统计：1分钟/5分钟/15分钟三级聚合粒度
4. 3-sigma + IQR双算法异常检测：分别基于正态分布和四分位距的异常分数计算
5. 倒排索引全文搜索：TF-IDF词频+布尔AND/OR查询
6. 告警规则管理：支持阈值告警+异常分数告警+关键词命中告警三级
7. ECharts日志量趋势+异常分布热力图+告警时间线

## 本地开发

日志接口地址、端口与代理统一由环境配置提供（不再写死在代码里），依赖安装、启动、打包均有可重复执行的脚本；缺依赖或端口被占用时会明确报错并给出处理提示。

### 1. 准备配置

```bash
cp backend/.env.example backend/.env     # 后端监听地址/端口
cp frontend/.env.example frontend/.env   # 前端端口、日志接口地址、API 前缀
```

| 配置项 | 位置 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `BACKEND_HOST` | `backend/.env` | `127.0.0.1` | 后端监听地址 |
| `BACKEND_PORT` | `backend/.env` | `8000` | 后端端口，日志接口地址为 `http://BACKEND_HOST:BACKEND_PORT` |
| `BACKEND_RELOAD` | `backend/.env` | `1` | 代码变更自动重载：1 开 / 0 关 |
| `VITE_DEV_PORT` | `frontend/.env` | `3000` | 前端开发服务器端口 |
| `VITE_BACKEND_URL` | `frontend/.env` | `http://127.0.0.1:8000` | Vite 代理目标（`/api`、`/ws`），未设置时由 dev 脚本按后端配置自动推导 |
| `VITE_API_BASE_URL` | `frontend/.env` | `/api` | 前端请求日志接口的前缀；直连后端时改为 `http://<后端地址>:<端口>/api` |

同名 shell 环境变量优先级高于 `.env` 文件，与其他环境（CI/容器）注入环境变量的写法保持一致。

### 2. 安装依赖

```bash
scripts/setup.sh
```

- 检查 `python3`/`node`/`npm`，缺失时明确提示；
- 创建（或修复损坏的）`backend/.venv` 并安装 `requirements.txt`，系统缺少 `ensurepip` 时自动用 get-pip 引导；
- 前端执行 `npm install`。

### 3. 启动开发环境

```bash
scripts/dev.sh
```

- 启动前检查依赖是否就绪、端口是否被占用：端口被占用会列出占用进程并退出，不会静默换端口；
- 就绪后：前端 `http://localhost:3000`，日志接口 `http://127.0.0.1:8000/api`；
- `Ctrl+C` 同时停止前后端。

### 4. 打包构建

```bash
scripts/build.sh   # 后端语法校验 + 前端 vue-tsc 类型检查与 vite build → frontend/dist
```

### 5. 验证告警链路

服务启动后，在页面点击「生成日志」→「检测异常」，右侧 AlertPanel 出现告警即链路跑通；也可用命令行验证（经前端代理）：

```bash
# 生成 1001 条 nginx 日志（末尾窗口日志数偏少触发统计异常），alerts 应包含「统计异常检测」
curl -s -X POST http://localhost:3000/api/generate \
  -H 'Content-Type: application/json' -d '{"type":"nginx","count":1001}'

# 携带阈值告警规则检测，alerts 应包含「高频ERROR」
curl -s -X POST http://localhost:3000/api/detect \
  -H 'Content-Type: application/json' \
  -d '{"logs":[{"id":1,"timestamp":"t","level":"ERROR","source":"nginx","message":"x","raw":"x"}],"rules":[{"type":"level","threshold":0,"name":"高频ERROR"}],"query":""}'
```
