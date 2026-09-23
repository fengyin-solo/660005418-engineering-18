import { defineStore } from 'pinia'
import { ref } from 'vue'
import axios, { type AxiosError } from 'axios'
import { ElMessage } from 'element-plus'
import type { AnalysisResult, AlertRule } from '@/types'

// 日志接口 baseURL 统一由环境配置提供：
// 默认 /api（经 Vite 代理转发到 VITE_LOG_API_TARGET），可在 .env.development 改为直连地址。
const http = axios.create({
  baseURL: import.meta.env.VITE_LOG_API_BASE || '/api',
  timeout: 15000,
})

function errorMessage(err: unknown, action: string): string {
  const e = err as AxiosError
  if (e.code === 'ECONNABORTED') return `${action}超时，请检查日志接口是否已启动`
  if (e.response) return `${action}失败：接口返回 ${e.response.status}`
  if (e.message?.includes('Network Error')) {
    return `${action}失败：无法连接日志接口（代理未启动或端口/地址不匹配），请确认后端运行在 ${import.meta.env.VITE_LOG_API_TARGET || 'http://127.0.0.1:8000'}`
  }
  return `${action}失败：${e.message || '未知错误'}`
}

export const useLogStore = defineStore('log', () => {
  const result = ref<AnalysisResult | null>(null)
  const loading = ref(false)
  const searchQuery = ref('')
  const logType = ref('nginx')
  const rules = ref<AlertRule[]>([
    // keyword 默认命中 timeout：nginx 模板自带 connection timeout upstream，
    // 干净环境下即可稳定产生告警，便于验证“生成日志 → 检测 → 告警”联调链路。
    { id:1, name:'高频ERROR', type:'level', threshold:5, enabled:false },
    { id:2, name:'异常流量', type:'count', threshold:200, enabled:false },
    { id:3, name:'关键词命中', type:'keyword', keyword:'timeout', threshold:0, enabled:true }
  ])

  async function generate() {
    loading.value=true
    try {
      const {data} = await http.post('/generate',{type:logType.value,count:1000})
      result.value=data
    } catch (err) {
      ElMessage.error(errorMessage(err, '生成日志'))
    } finally { loading.value=false }
  }

  async function detect() {
    if (!result.value) return
    loading.value=true
    try {
      const {data} = await http.post('/detect',{logs:result.value.logs,rules:rules.value.filter(r=>r.enabled),query:searchQuery.value})
      result.value=data
      ElMessage.success(`检测完成，告警 ${data.alerts?.length || 0} 条`)
    } catch (err) {
      ElMessage.error(errorMessage(err, '异常检测'))
    } finally { loading.value=false }
  }

  return { result, loading, searchQuery, logType, rules, generate, detect }
})
