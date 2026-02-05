import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  server: {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    allowedHosts: ['authdb-1-1vsu.onrender.com', 'authdb-832j.onrender.com', 'localhost', '0.0.0.0'],
    open: true
  },
  plugins: [react()],
})
