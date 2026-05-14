# Buddies Backend

Spring Boot foundation for the Coupang Buddies API.

## Run With Docker Compose

From `development/`:

```bash
docker compose up --build
```

## Run Locally

This repository does not include a Maven wrapper yet. If Maven is installed:

```bash
mvn spring-boot:run
```

## Current Scope

The controllers expose the SDD endpoint surface with placeholder responses. The next implementation step is to add domain services, entities, repositories, JWT issuing/validation, and service-layer authorization.

## Important Security Note

The current `SecurityConfig` permits requests so that the skeleton can be bootstrapped quickly. Before implementing real flows, add JWT authentication and RBAC guards for member, host, and admin operations.

