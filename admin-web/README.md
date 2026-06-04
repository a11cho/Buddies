# Buddies Admin Web

React + TypeScript + Vite foundation for the Admin panel.

## Run

```bash
npm install
npm run dev
```

The Vite dev server proxies `/api` and `/ws` to the HTTPS backend at `https://localhost:8443`.

To expose the admin web from the Linux server, set these constants in `vite.config.ts`:

```ts
const EXTERNAL_HTTPS_ACCESS = true;
const EXTERNAL_SERVER_HOST = '110.76.94.211';
```

Then run the backend from the repository root:

```bash
bash backend/scripts/generate-dev-ssl.sh
docker compose up --build
```

And run the admin web from this directory:

```bash
npm run dev
```

Open `https://110.76.94.211:5173` from the external device. The admin web serves HTTPS directly and proxies API traffic to the backend on the same computer.

If the browser reports `ERR_SSL_VERSION_OR_CIPHER_MISMATCH`, stop the old admin web process and restart `npm run dev`. That error means port `5173` is not serving the HTTPS configuration from `vite.config.ts`.

## Trusted HTTPS

The `npm run dev` HTTPS server uses a development self-signed certificate. Browsers can connect, but they will still mark it as not fully secure because the certificate is not issued by a public certificate authority.

For a trusted browser lock, point a real domain to the server IP and run the Caddy deployment:

```bash
BUDDIES_ADMIN_DOMAIN=admin.example.com sudo -E docker compose -f docker-compose.yml -f docker-compose.admin.yml up --build
```

Open `https://admin.example.com`. Caddy serves the built admin web on port `443`, obtains a public TLS certificate, and proxies `/api` and `/ws` to the backend container.

## Next Targets

- Add Admin login and JWT storage.
- Implement reports list/detail pages.
- Implement chat archive viewer with reported-message highlighting.
- Implement user moderation actions and audit log review.
