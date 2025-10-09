import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

export default defineConfig(({ mode }) => {
  // 从项目根目录加载环境变量（上一级目录）
  const env = loadEnv(mode, path.resolve(__dirname, '..'), '')
  
  console.log('Vite 加载的环境变量:')
  console.log('  VITE_API_URL:', env.VITE_API_URL)
  console.log('  VITE_FRONTEND_HOST:', env.VITE_FRONTEND_HOST)
  console.log('  VITE_FRONTEND_PORT:', env.VITE_FRONTEND_PORT)
  
  return {
    plugins: [vue()],
    server: {
      host: env.VITE_FRONTEND_HOST || '0.0.0.0',
      port: parseInt(env.VITE_FRONTEND_PORT || '3000'),
      proxy: {
        '/api': {
          target: env.VITE_API_URL || 'http://localhost:8000',
          changeOrigin: true
        }
      }
    },
    // 确保环境变量能被前端代码访问
    define: {
      'import.meta.env.VITE_API_URL': JSON.stringify(env.VITE_API_URL || 'http://localhost:8000')
    }
  }
})
