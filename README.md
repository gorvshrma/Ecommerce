# CloudCart: a DevOps learning project

CloudCart is a small shopping app. It helps you learn how an app runs, how to
test changes, and how to prepare a safe deployment. It is a portfolio project,
not a production shop.

## Start here

1. Read this page to run the app on your computer.
2. Read [Architecture](docs/ARCHITECTURE.md) to understand the three parts.
3. Use [Runbook](docs/RUNBOOK.md) when something goes wrong.
4. Read [CI](docs/CI.md) to understand GitHub's automatic checks.
5. Check [Readiness](docs/READINESS.md) for what has actually been tested.
6. Read [Cloud design](docs/CLOUD-DESIGN.md) for the proposed next stage.

New to a word? Look it up in the [small glossary](docs/GLOSSARY.md).

## What the app does

You can view products, keep a shopping cart, and create orders. Creating an
order reduces product stock. PostgreSQL stores the data. The app also has
health, database readiness, version information, and metrics endpoints.

## Run it on your computer

You need Git and Docker Desktop with Docker Compose v2. Start Docker Desktop
first. Open a terminal in the repository folder. Every command below runs from
that folder, not from the `docker` subfolder.

On Windows, use PowerShell:

```powershell
if (!(Test-Path .env)) { Copy-Item .env.example .env }
notepad .env
```

On macOS or Linux:

```bash
test -f .env || cp .env.example .env
${EDITOR:-vi} .env
```

In `.env`, fill in `POSTGRES_PASSWORD` with your own private password. The
example leaves it blank on purpose. `DATABASE_URL` tells the backend how to
reach the database. Its sample value uses `${POSTGRES_PASSWORD}` automatically.
For a simple first setup, generate a long random password using letters and
numbers. If you choose URL-reserved characters, put the percent-encoded
password in the password part of `DATABASE_URL`. Single-quote literal `.env`
values that contain `$` or `#`.

Keep `.env` private. Git ignores it. Variables already set in your terminal
can override `.env`; remove conflicting values before continuing. Do not
replace an existing database password unless you also update the database.

Validate the settings, then build and start the app:

```bash
docker compose --env-file .env -f docker/docker-compose.yml config --quiet
docker compose --env-file .env -f docker/docker-compose.yml up --build -d --wait --wait-timeout 120
```

The first command should finish without errors. The second downloads images,
builds the app, and waits for the containers to become healthy. The first run
can take a few minutes. On an empty database, normal startup adds sample products.

| Open this address | What you should see |
| --- | --- |
| http://localhost:3000 | The shop |
| http://localhost:8000/docs | A page for trying API requests |
| http://localhost:8000/health | `healthy` |
| http://localhost:8000/ready | `ready` and database `connected` |
| http://localhost:8000/info | App version and runtime details |
| http://localhost:8000/metrics | Text counters for monitoring tools |

Stop the app without deleting its data:

```bash
docker compose --env-file .env -f docker/docker-compose.yml down
```

Start again with the same `up` command. Avoid `down -v`: it deletes the database
volume. [The runbook](docs/RUNBOOK.md) explains resets, tests, and rollback.

## Project status

Local setup and the original five GitHub CI jobs have passed. Terraform now adds
a separate validation job; its PR records the latest results. `main` rules require
checks before a PR can merge. [PR #1](https://github.com/gorvshrma/Ecommerce/pull/1)
contains the reviewed changes; check its live status for merge progress.
Terraform infrastructure is now written and checked without AWS access. Read the
[beginner Terraform guide](terraform/README.md) before using it. AWS resources,
Kubernetes deployment, tested cloud backups, and production alerts are not deployed.
No AWS resources have been created for these phases.

See the [roadmap](docs/ROADMAP.md), [repository rules](docs/REPOSITORY-RULES.md),
and [decision records](docs/adr/README.md) for the next steps and reasons.
