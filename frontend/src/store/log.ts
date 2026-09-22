import { defineStore } from 'pinia'
import { ref } from 'vue'
import axios from 'axios'
import type { AnalysisResult, AlertRule } from '@/types'

// 日志接口前缀来自环境配置（frontend/.env 的 VITE_API_BASE_URL），默认走 Vite 代理
const API_BASE = (import.meta.env.VITE_API_BASE_URL || '/api').replace(/\/+$/, '')

export const useLogStore = defineStore('log', () => {
  const result = ref<AnalysisResult | null>(null)
  const loading = ref(false)
  const searchQuery = ref('')
  const logType = ref('nginx')
  const rules = ref<AlertRule[]>([
    { id:1, name:'高频ERROR', type:'level', threshold:5, enabled:true },
    { id:2, name:'异常流量', type:'count', threshold:200, enabled:false },
    { id:3, name:'关键词命中', type:'keyword', threshold:0, enabled:true }
  ])

  async function generate() {
    loading.value=true
    try { const {data} = await axios.post(`${API_BASE}/generate`,{type:logType.value,count:1000}) ; result.value=data }
    finally { loading.value=false }
  }

  async function detect() {
    if (!result.value) return
    loading.value=true
    try { const {data} = await axios.post(`${API_BASE}/detect`,{logs:result.value.logs,rules:rules.value.filter(r=>r.enabled),query:searchQuery.value}) ; result.value=data }
    finally { loading.value=false }
  }

  return { result, loading, searchQuery, logType, rules, generate, detect }
})
