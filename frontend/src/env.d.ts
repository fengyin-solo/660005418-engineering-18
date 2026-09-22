/// <reference types="vite/client" />
declare module "*.vue" { import type { DefineComponent } from "vue"; const c: DefineComponent<{}, {}, any>; export default c }

// 环境配置类型（示例见 frontend/.env.example）
interface ImportMetaEnv {
  readonly VITE_DEV_PORT?: string
  readonly VITE_BACKEND_URL?: string
  readonly VITE_API_BASE_URL?: string
}
interface ImportMeta { readonly env: ImportMetaEnv }
