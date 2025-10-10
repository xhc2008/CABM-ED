import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

export default defineConfig(({ mode }) => {
  // 从项目根目录加载环境变量（上一级目录）
  const env = loadEnv(mode, path.resolve(__dirname, '..'), '')
  
  const backendPort = env.BACKEND_PORT || '8000'
  
  console.log('Vite 加载的环境变量:')
  console.log('  BACKEND_PORT:', backendPort)
  console.log('  VITE_FRONTEND_HOST:', env.VITE_FRONTEND_HOST)
  console.log('  VITE_FRONTEND_PORT:', env.VITE_FRONTEND_PORT)
  
  return {
    plugins: [vue()],
    server: {
      host: env.VITE_FRONTEND_HOST || '0.0.0.0',
      port: parseInt(env.VITE_FRONTEND_PORT || '3000'),
      proxy: {
        '/api': {
          target: `http://localhost:${backendPort}`,
          changeOrigin: true
        }
      }
    },
    // 传递后端端口给前端，让前端动态构建URL
    define: {
      'import.meta.env.VITE_BACKEND_PORT': JSON.stringify(backendPort)
    }
  }
})
