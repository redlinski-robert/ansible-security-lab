import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],

  server: {
    host: '0.0.0.0',
    port: 5173,

    allowedHosts: [
      'mojeansible.pl',
      '__UZUPELNIJ_IP_EDGE__',
      '__UZUPELNIJ_IP_APP__'
    ],

    hmr: false,

    proxy: {
      '/api': {
        target: 'http://backend:5000',
        changeOrigin: true
      }
    }
  }
})