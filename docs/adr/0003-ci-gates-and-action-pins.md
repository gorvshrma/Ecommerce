# ADR 0003: keep CI checks independent and pin actions

- Status: Accepted
- Date: 2026-10-29

## Why this decision was needed

Floating action tags can change upstream. Sonar needs an account token. A
backend scan failure previously prevented the frontend scan from running.
Host dependency folders could also enter the frontend Docker build.

## Decision

Pin top-level actions to verified commit IDs. Keep the workflow token read-only
and disable persisted checkout credentials. Keep the 70% test coverage rule.
Scan both images separately for fixable HIGH/CRITICAL issues with Trivy 0.70.0.
Make Sonar an opt-in push check. Exclude local files using `.dockerignore`.

## Alternatives and tradeoffs

Sharing built images could save duplicate builds but would add artifact storage
or registry setup. Separate builds keep this small workflow easy to follow.
Pins need deliberate updates. Base tags and all indirect dependencies are not
fully pinned. Sonar is not a verified mandatory quality gate in this setup.
