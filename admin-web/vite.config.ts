import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

const EXTERNAL_HTTPS_ACCESS = true;
const EXTERNAL_SERVER_HOST = '110.76.94.211';
const ADMIN_WEB_PORT = 5173;
const BACKEND_BASE_URL = 'https://localhost:8443';
const DEV_SSL_P12_PATH = resolve('../backend/config/dev-ssl.p12');
const DEV_SSL_P12_PASSWORD = 'buddies-local-ssl';

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: ADMIN_WEB_PORT,
    strictPort: true,
    https: EXTERNAL_HTTPS_ACCESS
      ? {
          pfx: readFileSync(DEV_SSL_P12_PATH),
          passphrase: DEV_SSL_P12_PASSWORD,
        }
      : undefined,
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

