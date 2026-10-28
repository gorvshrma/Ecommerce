# What is ready, and what is still missing?

Updated: 2026-10-29. This page records what we checked. Passing these checks does
not make CloudCart a production-ready public shop.

| Area | Result | Evidence or limit |
| --- | --- | --- |
| Local configuration | Passed | Required database values cannot be missing or blank |
| Local stack | Passed | All three containers became healthy |
| Browser and API | Passed | Frontend, health, readiness, and catalog returned HTTP 200 |
| Database connection | Passed | `/ready` reported `connected` |
| Backend tests | Passed | 4 tests; local coverage 76.11%, above the 70% requirement |
| Frontend | Passed | Fresh `npm ci` and production build |
| Docker images | Passed | Backend and frontend builds |
| Workflow syntax | Passed | actionlint 1.7.7 |
| Local image scans | Passed policy | Trivy 0.70.0 found no fixable HIGH/CRITICAL issues |
| GitHub CI | Passed | All five jobs in the linked run below |
| Main branch rules | Active | Ruleset 26079102 read back from GitHub |
| Terraform code | Offline verified | Three roots, eight mocked Terraform tests, and Git hygiene tests |
| AWS infrastructure | Not created | Configuration is written; no real AWS plan or apply |
| Sonar analysis | Not verified | Skipped on PRs; opt-in on pushes |
| Cloud backups and restore | Not implemented | Design and test procedure only |

## Evidence you can open

- [PR #1](https://github.com/gorvshrma/Ecommerce/pull/1).
- [Successful GitHub CI run](https://github.com/gorvshrma/Ecommerce/actions/runs/40774125898)
  for commit `16753d34d3ffef658033c1f79c9ea96f7a81ee24`.
- [Active main ruleset](https://github.com/gorvshrma/Ecommerce/rules/26079102).
- [Exact check names and rules](REPOSITORY-RULES.md).

A later docs commit has its own CI run. Check the PR Checks tab for the latest
revision; a green result for an older commit is not evidence for a newer one.

## Important limits, in plain language

The security scans ignore issues that have no fix yet and issues below HIGH
severity. They do not prove that every security problem has been found. The
frontend scan also warned that Alpine 3.24 was missing from the scanner's
end-of-life list. We do not claim lifecycle support based on that scan.

The tests show a TestClient deprecation warning. That is a warning about a
future dependency change; the four tests still passed.

Local tests use a temporary SQLite database, separate from PostgreSQL. We have
not tested PostgreSQL persistence through container recreation or performed a
backup restore drill. There is no verified high availability or disaster recovery.

The API has no user login or permission checks for creating products and orders.
Do not expose it as a real public shop. A future cloud demo needs access controls.
Metrics are available, but dashboards and alerts are not deployed. Secrets are
kept out of the committed sample; this is not a cloud secret-management system.

## Terraform implementation - 2026-10-29

The code configures S3 state encryption, locking, version history, private access,
and deletion protection. These settings are not live until a separately approved
bootstrap. State, plans, private backend settings, and variable files must not
enter Git; CI checks filenames and renamed state/plan artifacts. Provider lock
files stay tracked because they contain dependency checksums, not resource state.

All three roots validate offline. Eight mocked Terraform tests and three Git
hygiene tests pass. The unchanged frontend also passes a local read-only/reduced-
capability smoke check. Checkov has explicit resource-level exceptions, described
in the Terraform guide. No real AWS policy, TLS, state migration/locking, WAF,
restore, cost, or Fargate deployment has been integration-tested. The app still
needs a proper migration process, restricted DB credentials, RDS CA bundle,
verified image settings, and an approved account/region/budget before deployment.

## Kubernetes and Helm implementation - 2026-10-29

Helm lint, positive/negative production rendering, rendered security checks, and
Kubernetes 1.35 schema checks pass (14 standard Kubernetes resources, none skipped).
A dedicated Kind lab runs the frontend, backend, and local PostgreSQL with healthy
pods. Frontend HTTP, database readiness, and catalog requests pass. The initial
interrupted Helm install was recovered using its existing revision; no data or
credentials were reset. Argo CD v3.5.6 is installed for GitOps verification; see
the PR's final evidence for sync results and the tested Git commit.

This host uses cgroup v1, so the lab uses the documented temporary kubelet
compatibility option. Production must use a supported cgroup-v2 host. The default
Kind CNI does not establish NetworkPolicy enforcement. Kubernetes Secret storage
is not claimed encrypted at rest. No cloud deployment, restore drill, production
ingress/access-control test, or high-availability claim is made by this lab.

### Verified GitOps result

Argo CD manually synced Git commit `d5aaa4628a256f4a6ece23d0a8b0fd655c75a688`
and reported `Synced`, `Healthy`, and operation `Succeeded`. The database PVC
remained Bound during the handoff. Direct localhost checks returned frontend
HTTP 200 and API readiness with database connected. The shop is forwarded at
http://localhost:23000 and the API at http://localhost:28000. These local forwards
last only while their kubectl processes run.

[CI run 40784503174](https://github.com/gorvshrma/Ecommerce/actions/runs/40784503174)
passed all seven jobs for that commit. The seventh Kubernetes/Helm check is now
required by the active main rules. No AWS resources were created. The exact
cluster setup and its limits are in [Kubernetes](KUBERNETES.md).
