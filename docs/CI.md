# CI and supply-chain checks

## Implemented definitions

`.github/workflows/ci.yml` runs for pushes to `main`, pull requests targeting
`main`, and manual dispatch. Workflow permissions remain `contents: read`;
checkout does not persist credentials. Top-level actions are pinned to upstream
commit IDs resolved from their existing version tags on 2026-10-29.

The intended required checks are:

| Check | Gate |
| --- | --- |
| Backend Tests & Code Quality | pytest, minimum 70% coverage |
| Frontend Build | locked `npm ci` and production build |
| Docker Build Validation | backend and frontend image builds |
| Trivy Security Scan (backend) | fixable HIGH/CRITICAL OS and library vulnerabilities |
| Trivy Security Scan (frontend) | same policy, independent matrix execution |

The Trivy matrix disables fail-fast so a failure in one image does not cancel
the other scan. Scanner version is explicitly `v0.70.0`, matching the existing
action's default. The policy retains `ignore-unfixed: true`; a passing scan
therefore does not mean there are no vulnerabilities. Secret scanning, SBOM
publication, image signing, and deployment are not implemented by this workflow.

Builds are repeated in the Docker validation and scan jobs deliberately: jobs
have independent daemons, and avoiding duplication would require image transfer
or a registry. No registry credentials or image pushes are needed here.
`.dockerignore` files exclude local environment files, dependencies, and generated
outputs; frontend `COPY . .` no longer imports host `node_modules` into Linux.
Base-image tags and transitive dependencies/actions are not all digest-pinned;
top-level action pinning is a specific control, not full build reproducibility.

## Optional Sonar

Sonar runs only on push events when repository variable `ENABLE_SONAR` is exactly
`true`. Configure the repository secret `SONAR_TOKEN` before enabling it. A
missing token then fails with a configuration error. Pull requests and manual
dispatch do not run Sonar or receive its token through these steps. Backend
tests and coverage run regardless. Sonar project configuration is retained;
no remote Sonar run or server-side quality gate has been verified.

## Local verification commands

Run from the repository root, with Docker running:

```powershell
docker compose --env-file .env -f docker/docker-compose.yml config --quiet
docker compose --env-file .env -f docker/docker-compose.yml build
docker compose --env-file .env -f docker/docker-compose.yml run --rm --no-deps -w /tmp -e PYTHONPATH=/app -v "${PWD}/app/backend/tests:/tests:ro" backend python -m pytest /tests -v --cov=src --cov-report=term-missing --cov-fail-under=70 -p no:cacheprovider
docker build --no-cache --target build --tag cloudcart-frontend-ci:phase2 app/frontend
docker run --rm -v "${PWD}/.github/workflows/ci.yml:/ci.yml:ro" rhysd/actionlint:1.7.7 /ci.yml
```

The disposable test container uses SQLite under `/tmp`. It does not modify the
running PostgreSQL volume or the local test database. For scans without exposing
the Docker socket, export images and mount only the export directory:

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

Exit 0 means the configured policy passed; exit 1 can mean vulnerabilities or a
scanner error. Inspect the JSON and error output to distinguish them. Both scans
must pass. Reports and image archives are local files and must not be committed.
Vulnerability data changes over time; retain scanner version, image IDs, database
metadata, and reports with the verification evidence.

## Remote controls still to verify

No workflow was pushed or dispatched during this phase. A local pass does not
prove a GitHub-hosted run or branch protection. After a separately authorized
push, confirm all five checks above on the actual revision, then configure
required checks in repository rules. The old single `Trivy Security Scan` check
is replaced by the two matrix check names; update any existing rule accordingly.
No repository settings or remote secrets were changed in this phase.

## Pin maintenance and references

Resolve an upstream tag and its peeled commit with `git ls-remote` before
updating a pin; review release notes and the commit diff, then rerun local checks.
Do not replace a SHA with a floating tag just to fix a failing check.

- [GitHub secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [Trivy action inputs at the pinned commit](https://github.com/aquasecurity/trivy-action/blob/ed142fd0673e97e23eac54620cfb913e5ce36c25/action.yaml)

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

### Scanned image IDs

- backend: image `sha256:3273a4d0b81cd3d4de636ad8030e49289aee5058848fe3d2b93a3a4f1fab51e8`, 0 fixable HIGH/CRITICAL findings.
- frontend: image `sha256:4275c4dddc5288b46d67e4347673de92ee5b81d0a852f6cb2ac2f2a91cf8c954`, 0 fixable HIGH/CRITICAL findings.
