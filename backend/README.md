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

The local backend uses HTTPS by default on `https://localhost:8443` with the development self-signed keystore at `config/dev-ssl.p12`. Browsers may show a certificate warning because this certificate is for local development only.

If `config/dev-ssl.p12` is missing, generate a local development keystore:

```bash
keytool -genkeypair -alias buddies-local -keyalg RSA -keysize 2048 -storetype PKCS12 -keystore config/dev-ssl.p12 -storepass buddies-local-ssl -keypass buddies-local-ssl -validity 3650 -dname "CN=localhost, OU=Development, O=Buddies, L=Daejeon, ST=Daejeon, C=KR" -ext "SAN=dns:localhost,ip:127.0.0.1"
```

Do not use this development keystore in production.

## Current Scope

The controllers expose the SDD endpoint surface with placeholder responses. The next implementation step is to add domain services, entities, repositories, JWT issuing/validation, and service-layer authorization.

## Important Security Note

The current `SecurityConfig` permits requests so that the skeleton can be bootstrapped quickly. Before implementing real flows, add JWT authentication and RBAC guards for member, host, and admin operations.

