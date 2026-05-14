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
curl http://localhost:8080/actuator/health
```

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

