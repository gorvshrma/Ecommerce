# Runbook: start, check, stop, and recover

A runbook is a set of steps you can follow when operating the app. Run all
commands from the repository root. The commands here do not create AWS resources.

## 1. First start

Start Docker Desktop. In PowerShell:

```powershell
if (!(Test-Path .env)) { Copy-Item .env.example .env }
notepad .env
```

Fill in a private `POSTGRES_PASSWORD`. The sample `DATABASE_URL` uses that
password. If the password has URL-reserved characters, use its percent-encoded
form in the URL. Single-quote literal `.env` values with `$` or `#`.
Terminal environment variables override the file; clear conflicting values.
Keep `.env` out of Git. The copy command preserves an existing `.env`.

On macOS/Linux, use `test -f .env || cp .env.example .env`, then edit `.env`.

```bash
docker compose --env-file .env -f docker/docker-compose.yml config --quiet
docker compose --env-file .env -f docker/docker-compose.yml up --build -d --wait --wait-timeout 120
```

The first command checks settings without printing secrets. The second starts
and checks the containers. The first build may take a few minutes.

## 2. Quick check

```powershell
docker compose --env-file .env -f docker/docker-compose.yml ps
Invoke-RestMethod http://localhost:8000/health
Invoke-RestMethod http://localhost:8000/ready
Invoke-RestMethod http://localhost:8000/api/products
(Invoke-WebRequest -UseBasicParsing http://localhost:3000).StatusCode
```

Expect healthy containers, `healthy`, database `connected`, a product list, and
frontend HTTP 200. These requests do not create orders. Normal startup adds
sample products if the product table is empty.

## 3. If something fails

| Problem | First thing to check |
| --- | --- |
| Cannot connect to Docker | Start Docker Desktop and run `docker info` |
| Required variable error | `.env` exists and the required values are not blank |
| API cannot log into database | Use the password that initialized the existing volume |
| Port already in use | Stop the other program using port 3000 or 8000 |
| Backend starts then exits | Read backend logs; check database settings |
| CI fails | Open the failed job and read the first failing step |

Changing `POSTGRES_PASSWORD` in `.env` does not change the password inside an
existing database. Restore matching credentials rather than deleting data.

```bash
docker compose --env-file .env -f docker/docker-compose.yml logs --tail=100 postgres backend
```

Review logs locally. Do not share credentials or unredacted environment files.
Full `docker compose config` output can include secrets; use `config --quiet`.

## 4. Stop while keeping data

```bash
docker compose --env-file .env -f docker/docker-compose.yml down
```

This keeps the database volume. Start again with the same `up` command. Keep
the same Compose project name and file location so Docker reuses the volume.

## 5. Delete local database data only when you intend to

```bash
docker compose --env-file .env -f docker/docker-compose.yml down -v
```

This permanently deletes the Compose database volume. It is not a normal stop
or rollback. The next start creates an empty database and adds sample products.

## 6. Undo a merged code change safely

Start from a clean working tree. First run `git status`; save any unrelated work.
For a squash merge, use its single commit ID in the following commands:

```bash
git switch main
git pull --ff-only origin main
git switch -c codex/revert-bad-change
git revert COMMIT_ID
git push -u origin codex/revert-bad-change
```

Replace `COMMIT_ID` with the actual bad commit ID. Open a PR, wait for all required
checks, and merge the revert. For a merge commit use `git revert -m 1 COMMIT_ID`
instead. Do not use `git reset --hard` or force-push `main` to undo shared work.

After the revert is merged, update local `main` and rebuild:

```bash
git switch main
git pull --ff-only origin main
docker compose --env-file .env -f docker/docker-compose.yml up --build -d --wait --wait-timeout 120
```

Repeat the quick checks. Reverting code does not restore deleted database data.
Cloud restore steps are only a proposal in [Cloud design](CLOUD-DESIGN.md).

## 7. Run developer checks

[CI](CI.md) has copyable local test commands and explains each GitHub check.
[Repository rules](REPOSITORY-RULES.md) explains why a PR might be blocked.
