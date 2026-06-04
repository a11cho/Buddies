# Coupang Buddies Development Foundation

This folder contains the initial implementation foundation for the SRS-defined system.

## Stack

- Backend: Java 21, Spring Boot, Spring Security, Spring WebSocket, Spring Data JPA
- Database: PostgreSQL, Flyway migrations
- Admin Web: React, TypeScript, Vite
- Mobile: Flutter project foundation
- Deployment: Docker Compose

## Layout

```text
development/
  backend/      Spring Boot REST/WebSocket API
  admin-web/    React admin panel
  mobile/       Flutter mobile app foundation
  docs/         Development notes and API conventions
```

## Run Backend With Docker

```bash
docker compose up --build
```

Backend health check:

```bash
curl -k https://localhost:8443/actuator/health
```

To allow another device on the same network to use the local admin web while testing, set `buddies.external-access` in `backend/src/main/resources/application.yml` to `true` and make sure `PublicUrlBuilder.EXTERNAL_PUBLIC_BASE_URL` matches the server address.

```bash
bash backend/scripts/generate-dev-ssl.sh
docker compose up --build
```

PowerShell:

```powershell
docker compose up --build
```

Then start `admin-web` with `npm run dev` and open `https://110.76.94.211:5173` on the other device. The admin web HTTPS toggle, host, and development certificate path are hard-coded in `admin-web/vite.config.ts`; password reset emails use the external URL hard-coded in `PublicUrlBuilder` when `buddies.external-access=true`, otherwise they use `https://localhost:8443`.

The Docker backend image generates a local self-signed PKCS12 keystore at `/app/ssl/dev-ssl.p12` during image build.

If the backend fails with `Could not load store from '/app/config/dev-ssl.p12'` and `Is a directory`, an older container/configuration is still running. Rebuild and recreate the backend container with `docker compose up --build --force-recreate`.

PostgreSQL:

```text
host: localhost
port: 5432
database: buddies
user: buddies
password: buddies
```

## Local Development Notes

- The backend is the source of truth for lobby, cart, payment, chat, report, and admin state.
- The MVP can run with one backend instance and in-memory WebSocket rooms.
- Add Redis Pub/Sub only when scaling WebSocket across multiple backend instances.
- Store chat media and receipt images outside PostgreSQL. The MVP can use a local volume; production can use S3-compatible storage.

