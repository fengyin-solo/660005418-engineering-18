import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

// 地址、端口、代理目标统一由 frontend/.env.development 提供（见 .env.development.example），
// 与 backend/.env 的 LOG_API_HOST / LOG_API_PORT 对应，不再在此写死。
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const devPort = Number(env.VITE_DEV_PORT || 3000)
  const apiTarget = env.VITE_LOG_API_TARGET || 'http://127.0.0.1:8000'

  return {
    plugins: [vue()],
    server: {
      port: devPort,
      proxy: {
        '/api': apiTarget,
        '/ws': { target: apiTarget.replace(/^http/, 'ws'), ws: true },
      },
    },
  }
})
