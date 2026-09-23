/// <reference types="vite/client" />

declare module "*.vue" { import type { DefineComponent } from "vue"; const c: DefineComponent<{}, {}, any>; export default c }

interface ImportMetaEnv {
  /** dev server 监听端口 */
  readonly VITE_DEV_PORT: string
  /** 日志接口代理目标，例如 http://127.0.0.1:8000 */
  readonly VITE_LOG_API_TARGET: string
  /** 日志接口 baseURL，走代理时为 /api */
  readonly VITE_LOG_API_BASE: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
