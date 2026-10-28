# ADR 0002: Load local configuration explicitly

- Status: Accepted
- Date: 2026-10-29

## Context

Compose may be invoked from different directories, while the project stores
its local environment file at the repository root. Implicit environment-file
discovery can therefore make startup depend on the caller's working directory.
Database credentials must not be committed or silently defaulted.

## Decision

Document and use `docker compose --env-file .env -f docker/docker-compose.yml`
from the repository root. Keep `.env.example` free of a populated password,
require nonblank database configuration, and provide a clear backend error if
`DATABASE_URL` is absent or blank.

## Consequences

Operators must create `.env` and provide a password before starting services.
Commands resolve the file from the documented repository root. Exported shell
variables still take precedence over `.env`; operators must clear conflicts. Credentials
remain local and must match between PostgreSQL and the backend connection URL.
