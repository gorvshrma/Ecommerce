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
| AWS infrastructure | Not created | Phase 3 is a written design only |
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
