import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

const ALLOW_HTTP_ACCESS = true;
const EXTERNAL_SERVER_HOST = '110.76.94.211';
const ADMIN_WEB_PORT = 5173;
const BACKEND_BASE_URL = ALLOW_HTTP_ACCESS ? 'http://localhost:8080' : 'https://localhost:8443';
const DEV_SSL_P12_PATH = resolve('../backend/config/dev-ssl.p12');
const DEV_SSL_P12_PASSWORD = 'buddies-local-ssl';

export default defineConfig({
  plugins: [react()],
  define: {
    __BUDDIES_ALLOW_HTTP_ACCESS__: JSON.stringify(ALLOW_HTTP_ACCESS),
  },
  server: {
    host: '0.0.0.0',
    port: ADMIN_WEB_PORT,
    strictPort: true,
    https: !ALLOW_HTTP_ACCESS
      ? {
          pfx: readFileSync(DEV_SSL_P12_PATH),
          passphrase: DEV_SSL_P12_PASSWORD,
        }
      : undefined,
    origin: `${ALLOW_HTTP_ACCESS ? 'http' : 'https'}://${EXTERNAL_SERVER_HOST}:${ADMIN_WEB_PORT}`,
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

