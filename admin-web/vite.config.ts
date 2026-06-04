import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

const EXTERNAL_HTTPS_ACCESS = true;
const EXTERNAL_SERVER_HOST = '110.76.94.211';
const ADMIN_WEB_PORT = 5173;
const BACKEND_BASE_URL = 'https://localhost:8443';

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: ADMIN_WEB_PORT,
    strictPort: true,
    https: EXTERNAL_HTTPS_ACCESS,
    origin: EXTERNAL_HTTPS_ACCESS ? `https://${EXTERNAL_SERVER_HOST}:${ADMIN_WEB_PORT}` : undefined,
    proxy: {
      '/api': {
        target: BACKEND_BASE_URL,
        secure: false,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
      '/ws': {
        target: BACKEND_BASE_URL.replace(/^http/, 'ws'),
        secure: false,
        ws: true,
      },
    },
  },
});

