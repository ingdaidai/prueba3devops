import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // Proxy para desarrollo local — espeja la configuración de nginx en producción (ECS)
    // El frontend llama a /api/ventas/ y /api/despachos/ como rutas relativas;
    // en dev Vite las proxea a los backends locales.
    proxy: {
      '/api/ventas': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/ventas/, '')
      },
      '/api/despachos': {
        target: 'http://localhost:8081',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/despachos/, '')
      }
    }
  }
})
