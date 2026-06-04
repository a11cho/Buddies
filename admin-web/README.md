# Buddies Admin Web

React + TypeScript + Vite foundation for the Admin panel.

## Run

```bash
npm install
npm run dev
```

The Vite dev server proxies `/api` and `/ws` to the HTTPS backend at `https://localhost:8443`.

To test the admin web from another device on the same network, set `buddies.external-access` in `../backend/src/main/resources/application.yml` to `true` and make sure `PublicUrlBuilder.EXTERNAL_PUBLIC_BASE_URL` matches the server address. Then run the backend with:

```bash
docker compose up --build
```

PowerShell:

```powershell
docker compose up --build
```

Then open `http://<your-computer-ip>:5173` from the other device. Password reset emails use the external URL hard-coded in `PublicUrlBuilder` when `buddies.external-access=true`; otherwise they use `https://localhost:8443`.

## Next Targets

- Add Admin login and JWT storage.
- Implement reports list/detail pages.
- Implement chat archive viewer with reported-message highlighting.
- Implement user moderation actions and audit log review.
