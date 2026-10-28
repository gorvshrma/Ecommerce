# CloudCart architecture

## Implemented locally

CloudCart is a three-tier application: a React/Vite frontend served by Nginx,
a FastAPI backend, and PostgreSQL 16. Docker Compose creates the `frontend`,
`backend`, and `postgres` services on a private bridge network. The frontend is
published at `localhost:3000`, the API at `localhost:8000`; PostgreSQL has no
host-published port. PostgreSQL data is stored in the named `postgres_data`
volume. The backend waits for PostgreSQL's `pg_isready` health check before it
starts. The frontend calls the API at `http://localhost:8000`.

The backend exposes health, readiness, info, metrics, catalog, and order
endpoints. `/ready` checks a database query. Product seed data is inserted
when the product table is empty. These are application behaviors, not proof of
production availability or security.

## Implemented delivery controls

The repository includes GitHub Actions checks for backend tests, frontend
build, Docker image builds, and Trivy image scans. These workflows run on
configured GitHub events; this document does not assert their current remote
status. Local Compose startup requires an explicit root `.env` file and checks
required database configuration. `.env` is ignored by Git.

## Planned infrastructure

No AWS resources are created by this project phase. ECR, VPC, IAM, EKS, RDS,
cloud load balancing, managed secrets, Terraform state storage, and a deployed
Kubernetes environment are roadmap items, not implemented controls. Kubernetes,
Helm, Argo CD, Prometheus/Grafana deployment, and production alerting also need
to be verified against the repository and a live environment before being
described as operational controls.

See [Readiness](READINESS.md) and [Roadmap](ROADMAP.md) for status boundaries.

## Phase 2 delivery definition

CI now pins top-level actions, keeps read-only permissions, and independently
scans both images. Sonar is opt-in on pushes. See [CI](CI.md) for exact gates,
local commands, limitations, and remote verification still required.
