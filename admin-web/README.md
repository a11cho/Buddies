# Buddies Admin Web

React + TypeScript + Vite foundation for the Admin panel.

## Run

```bash
npm install
npm run dev
```

The Vite dev server proxies `/api` and `/ws` to the HTTPS backend at `https://localhost:8443`.

To test the admin web from another device on the same network, run the backend with:

```bash
BUDDIES_EXTERNAL_ACCESS=true BUDDIES_PUBLIC_BASE_URL=https://<your-computer-ip>:8443 docker compose up --build
```

PowerShell:

```powershell
$env:BUDDIES_EXTERNAL_ACCESS = 'true'
$env:BUDDIES_PUBLIC_BASE_URL = 'https://<your-computer-ip>:8443'
docker compose up --build
```

Then open `http://<your-computer-ip>:5173` from the other device. Password reset emails use `BUDDIES_PUBLIC_BASE_URL` when building links. Set `BUDDIES_EXTERNAL_ACCESS=false` or omit it to keep the default localhost-only CORS policy.

## Next Targets

- Add Admin login and JWT storage.
- Implement reports list/detail pages.
- Implement chat archive viewer with reported-message highlighting.
- Implement user moderation actions and audit log review.
