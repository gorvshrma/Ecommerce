# CI: automatic checks before merging

CI means continuous integration. For CloudCart, it means GitHub runs tests and
builds so you can catch problems before changing `main`.

## When it runs

[The workflow](../.github/workflows/ci.yml) runs on PRs targeting `main`, pushes
to `main`, and a manual run from GitHub Actions. A push to a feature branch by
itself does not trigger this workflow; open a PR.

## What the five jobs do

| Job | Simple explanation | Passing result |
| --- | --- | --- |
| Backend Tests & Code Quality | Try API behavior and count executed code | Tests pass, coverage at least 70% |
| Frontend Build | Install locked dependencies and build the shop page | Build finishes without an error |
| Docker Build Validation | Package the backend and frontend | Both images build |
| Trivy Security Scan (backend) | Look for known issues in the backend image | No fixable HIGH/CRITICAL issues |
| Trivy Security Scan (frontend) | Check the frontend image separately | Same policy |

Both scan jobs run even if one fails. A passing vulnerability scan does not mean
there are no security issues: the policy ignores unfixed and lower-severity issues.
No exceptions or suppressions were added to make these scans pass.

The five checks are required by the active [main rules](REPOSITORY-RULES.md).
A successful [GitHub run](https://github.com/gorvshrma/Ecommerce/actions/runs/40774125898)
verified all five on commit `16753d3`. Later revisions need their own green run.

## Small security choices

The workflow token only reads repository contents. Checkout does not keep its
Git credentials in the checkout configuration. Top-level actions are pinned to
commit IDs, so changing an upstream version tag does not silently replace them.
These choices follow [GitHub guidance](https://docs.github.com/en/actions/reference/security/secure-use).

Trivy is fixed at 0.70.0. Base image tags, every nested action, and every indirect
dependency are not all fixed to immutable versions. Full reproducible builds,
image signing, and SBOM publication are future work. An SBOM is an inventory of
the software inside an image. CI does not deploy anything to AWS.

The `.dockerignore` files keep local settings, generated dependencies, and build
outputs out of build inputs. The two image jobs build separately because each
GitHub job has its own Docker engine. Sharing images would add extra storage or
a registry; this small project does not need that yet.

## Sonar is optional

Sonar is a separate code-analysis service. It is not a required remote quality
gate here. To enable it, set repository variable `ENABLE_SONAR` to `true` and add
the repository secret `SONAR_TOKEN`. An enabled scan with a missing token fails
with a clear message. Never put the token in a file or terminal command.

The Sonar steps run on push events only, not PRs or manual runs. A merged push
to `main` can run them if enabled. Remote Sonar results have not been verified.

## Repeat the checks locally in PowerShell

Run from the repository root, with Docker running:

```powershell
docker compose --env-file .env -f docker/docker-compose.yml config --quiet
docker compose --env-file .env -f docker/docker-compose.yml build
docker compose --env-file .env -f docker/docker-compose.yml run --rm --no-deps -w /tmp -e PYTHONPATH=/app -v "${PWD}/app/backend/tests:/tests:ro" backend python -m pytest /tests -v --cov=src --cov-report=term-missing --cov-fail-under=70 -p no:cacheprovider
docker build --no-cache --target build --tag cloudcart-frontend-ci:phase2 app/frontend
docker run --rm -v "${PWD}/.github/workflows/ci.yml:/ci.yml:ro" rhysd/actionlint:1.7.7 /ci.yml
```

The test container uses a temporary SQLite file. It does not change PostgreSQL
or your local test database. `actionlint` checks workflow syntax.

To scan images without sharing the Docker engine socket with the scanner:

```powershell
$reports = Join-Path $env:TEMP ('cloudcart-trivy-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $reports | Out-Null
docker save --output "$reports/backend.tar" docker-backend:latest
docker save --output "$reports/frontend.tar" docker-frontend:latest
foreach ($service in @('backend','frontend')) {
    docker run --rm --mount "type=bind,source=$reports,target=/reports" aquasec/trivy:0.70.0 image --cache-dir /reports/cache --input "/reports/$service.tar" --scanners vuln --ignore-unfixed --pkg-types os,library --severity CRITICAL,HIGH --exit-code 1 --format json --output "/reports/$service-trivy.json" --timeout 10m --no-progress
    Write-Output "Trivy $service exit: $LASTEXITCODE"
}
```

Exit 0 means the policy passed. Exit 1 may mean findings or a scanner error;
read the JSON report and error output. Both scans must pass. Keep image exports
and reports outside Git. Reports change as new vulnerabilities are published.

## Known warnings and maintenance

Local tests pass with a TestClient deprecation warning. The frontend scan warns
that Alpine 3.24 is missing from this scanner's end-of-life list. Neither is
proof of lifecycle support; review these warnings when updating dependencies.

To update an action pin, resolve the official tag with `git ls-remote`, review
the release and commit diff, change the SHA, and rerun checks. Do not weaken a
check to make a failing change pass. Local results and limits are in [Readiness](READINESS.md).
