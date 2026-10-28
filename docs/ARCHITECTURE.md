# How CloudCart works

## The three parts running on your computer

```text
Your browser
    | loads the page from localhost:3000
    v
Frontend: React page served by Nginx
    | your browser sends API requests to localhost:8000
    v
Backend: FastAPI application
    | reads and writes data using the Compose name postgres
    v
Database: PostgreSQL 16
```

The frontend is what the user sees. The backend handles product and order
requests. The database stores products, stock, and orders.

Docker Compose starts these as three separate services: `frontend`, `backend`,
and `postgres`. The frontend uses host port 3000. The backend uses host port
8000. The database does not publish a port to the host computer.

A port is an address number used to reach a running service. `localhost` means
this computer. The browser uses `localhost:8000`, while the backend uses the
internal service name `postgres`. Those names serve different purposes.

## Where the data lives

The named volume `postgres_data` keeps database files outside the database
container. Its actual Docker name includes the Compose project name, normally
`docker_postgres_data`. Ordinary `down` keeps it; `down -v` deletes it.
Keep the same Compose project name and file location to reuse the volume.

The backend waits for PostgreSQL's startup check before it starts. `/health`
checks that the API responds. `/ready` also tries a database query. Neither
endpoint is an alerting system or a guarantee that the shop never fails.

## What happens when code changes

A pull request runs backend tests, a frontend build, both image builds, and
separate vulnerability scans. An image is a packaged copy of the application.
The `main` rules require the five checks to pass before merging.
[CI](CI.md) explains each check and its limits.

## What is only planned

There is no CloudCart AWS deployment from these phases. Terraform is a tool
for describing infrastructure in code; empty folders are not infrastructure.
ECR image storage, ECS or EKS hosting, RDS databases, cloud secrets, HTTPS,
backups, alerts, Helm, and Argo CD are not running controls here.

[Cloud design](CLOUD-DESIGN.md) compares possible future setups. It is a design,
not a claim that those services exist. The [readiness page](READINESS.md) lists
actual evidence and missing work.
