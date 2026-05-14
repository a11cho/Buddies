# Architecture Notes

## Recommended Runtime Shape

```text
Flutter Mobile App
  -> Spring Boot REST API
  -> Spring WebSocket/STOMP Gateway

React Admin Web
  -> Spring Boot Admin REST API

Spring Boot
  -> PostgreSQL/PostGIS
  -> Object Storage for media
  -> SMTP provider for OTP/password reset
  -> Push notification provider
```

## Backend Module Boundaries

- `auth`: signup, OTP, login, logout, password reset, JWT issuing
- `user`: profile, order history, rating, help/support
- `lobby`: lobby search/create/join/leave/delete, host transfer, kick, status
- `cart`: cart item lifecycle, cart locking, total recomputation
- `payment`: payment records, paid confirmation, deeplink metadata
- `chat`: WebSocket messages, system messages, media metadata, archives
- `report`: user reports and report state
- `admin`: reports, archive review, user moderation, audit logs

## Key Design Rules

- Keep all write operations in service-layer transactions.
- Persist chat messages before WebSocket broadcast to preserve ordering and recovery.
- Treat PostgreSQL as the source of truth.
- Enforce Host/Participant/Admin permissions on both API and UI, but trust only API checks.
- Do not process real payments in-app; only track external settlement confirmation.

