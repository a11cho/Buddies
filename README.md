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

The backend uses a local self-signed PKCS12 keystore at `backend/config/dev-ssl.p12`. Generate it before running Docker Compose:

```powershell
.\backend\scripts\generate-dev-ssl.ps1
```

If the backend fails with `Could not load store from '/app/config/dev-ssl.p12'` and `Is a directory`, Docker was started before the keystore file existed. Delete the `backend/config/dev-ssl.p12` directory, regenerate the keystore, then recreate the containers.

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

