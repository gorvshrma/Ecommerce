# Readiness and implementation status

This document describes repository evidence for the local portfolio project.
It is not a production certification or a claim that cloud infrastructure is
deployed.

## Implemented in the repository

- Three Compose services: frontend, backend, and PostgreSQL.
- PostgreSQL health check gates backend startup; database readiness is
  checked by the API `/ready` endpoint.
- A named PostgreSQL data volume persists local data across ordinary Compose
  shutdowns.
- `.env` is ignored; Compose configuration is intended to be loaded explicitly
  and required database settings are validated.
- GitHub Actions workflow definitions include backend tests, frontend build,
  Docker builds, and Trivy image scans.
- Backend endpoints include `/health`, `/ready`, and `/metrics`.

## Not established by these controls

- A health endpoint does not provide uptime monitoring, alerting, or recovery.
- A Compose health check is local container startup coordination, not a
  production orchestration strategy.
- A CI workflow definition does not establish that the workflow passed,
  secrets are configured, or an artifact was deployed.
- No AWS environment, production secrets manager, remote Terraform state,
  backup/restore process, high availability, or disaster recovery is
  established by Phase 1.
- Repository directories or manifests alone do not establish a running
  Kubernetes, Helm, Argo CD, or monitoring deployment.

Before production claims, implement and verify the corresponding roadmap
controls in a target environment and document evidence, ownership, and
operational procedures.

## Local verification ï¿½ 2026-10-29

- Docker 28.0.4 and Compose v2.34.0-desktop.1 are installed.
- Root `.env` passes `docker compose --env-file .env -f docker/docker-compose.yml config --quiet`.
- A generated temporary credential verifies sample URL interpolation without
  exposing credentials. Missing/blank required Compose values are rejected.
- Rendered configuration retains the three services, frontend port 3000,
  backend port 8000, no published database port, and `postgres_data` volume.
- Backend rejects missing `DATABASE_URL` with the intended configuration error.
- Follow-up verification: Docker Engine 29.9.2 is accessible outside the agent
  sandbox. `docker compose --env-file .env -f docker/docker-compose.yml up --build -d --wait --wait-timeout 120`
  successfully built and started all three services; each reports healthy.
- Frontend `/`, API `/health`, `/ready`, and `/api/products` return HTTP 200;
  readiness reports the database connected. No orders were created by these checks.
- Existing backend tests pass in a disposable Compose backend container:
  `docker compose --env-file .env -f docker/docker-compose.yml run --rm --no-deps -w /tmp -e PYTHONPATH=/app -v D:/Ecommerce/app/backend/tests:/tests:ro backend python -m pytest /tests -q -p no:cacheprovider`
  reports 4 passed, with one upstream TestClient deprecation warning. The tests
  use temporary SQLite storage, not the running PostgreSQL database.
- The stack remains running. Database persistence across recreation has not
  been smoke-tested; no volumes were deleted. Earlier sandbox-only failures
  were environment limitations and are superseded by the successful container run.
- No AWS resources were created; no changes were pushed.

## Phase 2 local verification - 2026-10-29

- actionlint 1.7.7 validates the changed workflow without findings.
- Existing backend tests: 4 passed; coverage 76.11%, exceeding the unchanged
  70% gate. One upstream Starlette/TestClient deprecation warning remains.
- Fresh frontend build-stage run: `npm ci` and `npm run build` pass;
  npm audit reports 0 vulnerabilities at verification time.
- Both Compose runtime images build with context exclusions. No application
  source, dependency versions, Compose services, ports, or volumes changed.
- Trivy 0.70.0 scans of both exported runtime images exit 0 under the existing
  fixable HIGH/CRITICAL OS/library policy. No suppressions were added.
- Frontend scan reports Alpine 3.24 lifecycle metadata missing from this
  scanner's EOL list. Vulnerability detection completes; no lifecycle support
  conclusion is inferred. The policy excludes unfixed and lower-severity issues.
- No GitHub-hosted run, branch-protection enforcement, or remote Sonar result
  is claimed. See [CI](CI.md) for gates, reproduction, and remaining remote work.
- All pre-existing local changes remain. No push or AWS provisioning occurred.
