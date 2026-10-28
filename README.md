
# Cloud-Native E-Commerce Platform

A production-style 3-tier DevOps portfolio project built around a deliberately small e-commerce use case.

## Architecture

```text
Browser
   |
   v
React Frontend
   |
   | REST/JSON
   v
FastAPI Backend
   |
   | SQL
   v
PostgreSQL
```

## Current Features

- Product catalog
- Shopping cart
- Order creation
- Inventory reduction
- PostgreSQL persistence
- `/health`, `/ready`, `/info`, `/metrics`
- Dockerized frontend/backend/database
- Docker Compose networking
- Prometheus metrics
- Backend tests
- Runtime deployment metadata

## Local setup

Requirements: Docker Desktop (or Docker Engine) with the Compose v2 plugin.

From the repository root, create your local environment file and set a private,
non-empty database password. `.env` is ignored by Git. Keep the password in
sync between `POSTGRES_PASSWORD` and `DATABASE_URL`. The sample URL expands
`${POSTGRES_PASSWORD}` automatically. For a password containing URL-reserved
characters, replace the URL password component with its percent-encoded value.
Use single quotes around literal `.env` values containing `$` or `#` to avoid
Compose interpolation or comment parsing. Exported shell variables override
`.env` values; clear conflicting variables before running these commands.

PowerShell:

```powershell
if (!(Test-Path .env)) { Copy-Item .env.example .env }
notepad .env
docker compose --env-file .env -f docker/docker-compose.yml config --quiet
docker compose --env-file .env -f docker/docker-compose.yml up --build -d
```

macOS/Linux:

```bash
test -f .env || cp .env.example .env
${EDITOR:-vi} .env
docker compose --env-file .env -f docker/docker-compose.yml config --quiet
docker compose --env-file .env -f docker/docker-compose.yml up --build -d
```

The sample deliberately leaves `POSTGRES_PASSWORD` blank. Compose rejects a
missing or blank required value. Set `DATABASE_URL` to use that same password,
with the database host `postgres` for Compose network access.

To check service status and recent logs:

```bash
docker compose --env-file .env -f docker/docker-compose.yml ps
docker compose --env-file .env -f docker/docker-compose.yml logs --tail=100
```

Open:

- Frontend: http://localhost:3000
- Swagger API: http://localhost:8000/docs
- Health: http://localhost:8000/health
- Readiness: http://localhost:8000/ready
- Metrics: http://localhost:8000/metrics

Stop containers while preserving the database volume:

```bash
docker compose --env-file .env -f docker/docker-compose.yml down
```

Reset the database:

```bash
docker compose --env-file .env -f docker/docker-compose.yml down -v
```

The reset command permanently deletes the Compose project's `postgres_data` volume.
Do not use it for an ordinary stop or rollback. Changing `POSTGRES_PASSWORD`
does not update credentials inside an existing database volume; keep the original
credentials when reusing that volume. See the runbook for troubleshooting.

See [Architecture](docs/ARCHITECTURE.md), [Runbook](docs/RUNBOOK.md),
[Readiness](docs/READINESS.md), [Roadmap](docs/ROADMAP.md), and the
[architecture decision log](docs/adr/README.md) for implementation status,
operational procedures, and planned infrastructure.
