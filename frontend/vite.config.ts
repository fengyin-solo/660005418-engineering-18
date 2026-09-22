import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig(({ mode }) => {
  // 端口与日志接口地址统一来自环境配置（frontend/.env 或同名环境变量），示例见 frontend/.env.example
  const envDir = fileURLToPath(new URL('.', import.meta.url))
  const env = loadEnv(mode, envDir, 'VITE_')
  const devPort = Number(env.VITE_DEV_PORT || 3000)
  const backendUrl = (env.VITE_BACKEND_URL || 'http://127.0.0.1:8000').replace(/\/+$/, '')
  return {
    plugins: [vue()],
    resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
    server: {
      port: devPort,
      strictPort: true, // 端口被占用时直接报错退出，而不是静默切换端口
      proxy: {
        '/api': { target: backendUrl, changeOrigin: true },
        '/ws': { target: backendUrl.replace(/^http/, 'ws'), ws: true }
      }
    }
  }
})
