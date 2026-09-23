#!/usr/bin/env bash
# =====================================================================
# smoke-test.sh —— 告警口径 × 日志生成 联调链路冒烟（可重复执行）
#
# 前提：scripts/dev.sh 已启动（或后端自行运行在配置的端口上）。
# 校验：
#   1. 后端 /health 就绪
#   2. /api/generate 能生成 1000 条日志
#   3. /api/detect 携带默认告警规则后必须产生「关键词命中」告警
#   4. 经 Vite 代理的同一接口同样可用（验证代理配置，而非只验直连）
#
# 可通过环境变量覆盖目标地址，与其他环境（CI/容器）保持同一套写法：
#   BACKEND_URL=http://127.0.0.1:8000 FRONTEND_URL=http://127.0.0.1:3000 scripts/smoke-test.sh
# =====================================================================
set -euo pipefail
source "$(dirname "$0")/_common.sh"

BACKEND_URL="http://127.0.0.1:${BACKEND_PORT}"
FRONTEND_URL="http://127.0.0.1:${FRONTEND_PORT}"

log "${C_BOLD}联调链路冒烟检查${C_RESET}"
log "后端直连：$BACKEND_URL ｜ 前端代理：$FRONTEND_URL"

PAYLOAD_GENERATE='{"type":"nginx","count":1000}'
# 与前端默认规则保持一致：keyword=timeout 启用，其余默认关闭
RULES='[{"id":3,"name":"关键词命中","type":"keyword","keyword":"timeout","threshold":0,"enabled":true}]'

run_smoke() {
  _base=$1; _tag=$2
  python3 - "$_base" "$_tag" "$PAYLOAD_GENERATE" "$RULES" <<'PY'
import json, sys, urllib.request

base, tag, gen_body, rules_json = sys.argv[1:5]

def call(path, payload):
    req = urllib.request.Request(
        base + path,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read().decode())

if tag == "直连":
    # /health 不属于 Vite 代理范围（仅代理 /api、/ws），因此只对后端直连校验
    with urllib.request.urlopen(base + "/health", timeout=5) as r:
        health = json.loads(r.read().decode())
    assert health.get("status") == "ok", f"health 异常: {health}"
    print(f"  [{tag}] /health OK (service={health.get('service')}, port={health.get('port')})")

# 2) 生成日志
gen = json.loads(gen_body)
res = call("/api/generate", gen)
assert res.get("totalLogs") == 1000, f"totalLogs != 1000: {res.get('totalLogs')}"
assert len(res.get("logs", [])) > 0, "logs 为空"
print(f"  [{tag}] /api/generate OK，totalLogs={res['totalLogs']}")

# 3) 告警检测：必须出现关键词命中告警
rules = json.loads(rules_json)
det = call("/api/detect", {"logs": res["logs"], "rules": rules, "query": ""})
alerts = det.get("alerts", [])
keyword_alerts = [a for a in alerts if a.get("ruleName") == "关键词命中"]
assert alerts, "未产生任何告警，告警链路异常"
assert keyword_alerts, f"未产生关键词命中告警，实际告警: {[a.get('ruleName') for a in alerts]}"
sample = keyword_alerts[0]
print(f"  [{tag}] /api/detect OK，告警 {len(alerts)} 条（关键词命中 {len(keyword_alerts)} 条）")
print(f"  [{tag}] 示例告警: {sample['severity'].upper()} | {sample['message']}")
print(f"  [{tag}] PASS")
PY
}

run_smoke "$BACKEND_URL" "直连" || die "直连后端冒烟失败，请确认后端已启动（scripts/dev.sh）"

if wait_for_http "$FRONTEND_URL" 3; then
  run_smoke "$FRONTEND_URL" "代理" || die "经 Vite 代理冒烟失败，请检查 frontend/.env.development 的 VITE_LOG_API_TARGET"
else
  warn "前端 dev server 未运行（$FRONTEND_URL），跳过代理校验；只启动后端时此项可忽略"
fi

ok "联调链路冒烟全部通过：日志生成 -> 异常检测 -> 告警输出"
