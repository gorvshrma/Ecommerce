# Local operations runbook

Run commands from the repository root. Docker Compose commands explicitly load
`.env`; never commit that file or put real credentials in tracked files.

## First run

PowerShell:

```powershell
if (!(Test-Path .env)) { Copy-Item .env.example .env }
notepad .env
docker compose --env-file .env -f docker/docker-compose.yml config --quiet
docker compose --env-file .env -f docker/docker-compose.yml up --build -d
```

In `.env`, set a private `POSTGRES_PASSWORD` and make its `DATABASE_URL`
password component match. The sample URL interpolates `${POSTGRES_PASSWORD}`;
for URL-reserved characters, use a percent-encoded password in `DATABASE_URL`.
Single-quote literal `.env` values containing `$` or `#`. Shell environment
variables override the file, so clear conflicting exported values. Do not use the
example with its blank password to start services.

## Check and troubleshoot

```bash
docker compose --env-file .env -f docker/docker-compose.yml ps
docker compose --env-file .env -f docker/docker-compose.yml logs --tail=100
docker compose --env-file .env -f docker/docker-compose.yml logs --tail=100 postgres backend
```

Open `http://localhost:3000` for the frontend and
`http://localhost:8000/health`, `/ready`, `/docs`, or `/metrics` for API checks.
`/ready` should report database connectivity. If configuration validation
fails, check that `.env` exists, is explicitly loaded, and has nonblank
`POSTGRES_PASSWORD` and `DATABASE_URL` values with matching credentials.

## Stop and preserve data

```bash
docker compose --env-file .env -f docker/docker-compose.yml down
```

This removes the containers and network while retaining `postgres_data`.
To resume, run the `up --build -d` command above.

## Destructive local reset

Only when you intend to erase local database data:

```bash
docker compose --env-file .env -f docker/docker-compose.yml down -v
```

This removes the named database volume. Recreate services with the normal
`up --build -d` command afterward.

## Read-only smoke check

After startup, use PowerShell (repeat if the API is still starting):

```powershell
Invoke-RestMethod http://localhost:8000/health
Invoke-RestMethod http://localhost:8000/ready
Invoke-RestMethod http://localhost:8000/api/products
(Invoke-WebRequest -UseBasicParsing http://localhost:3000).StatusCode
```

Expect `healthy`, database `connected`, a product list, and frontend HTTP 200.
These checks do not create orders or alter stock. On an empty database the
application's normal startup creates tables and seeds products.

If PostgreSQL is healthy but the API reports authentication errors, check the
credentials originally used to initialize the existing volume. Changing `.env`
does not rotate the stored database user's password. Preserve the volume and
restore matching local credentials; do not reset data to fix configuration.
Do not share unredacted `docker compose config`, environment files, or logs
that contain credentials. Prefer `config --quiet` for validation.

## Rollback

Stop with the non-destructive `down` command above. Restore only the files
changed in the current phase from its pre-change snapshot, then validate with
`config --quiet` and run `up --build -d`. Keep the same Compose project name,
Compose file location, and credentials so the original named volume is reused.
Do not use `git reset --hard`, blanket `git restore`, or `down -v`: they can
discard pre-existing work or database data. Exact snapshot restore commands
for this execution are provided in the completion report.

## CI checks

See [CI](CI.md) for local commands, scan policy, optional Sonar configuration,
check names, and the distinction between local results and remote enforcement.
