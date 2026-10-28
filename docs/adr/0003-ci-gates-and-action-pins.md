# ADR 0003: Pin CI actions and keep independent local-verifiable gates

- Status: Accepted
- Date: 2026-10-29

## Context

The existing workflow defines useful checks but uses mutable action tags, requires
Sonar credentials even for baseline CI, and stops before scanning the frontend
if the backend scan fails. Local frontend dependencies can enter Docker contexts.

## Decision

Pin existing top-level action versions to resolved upstream commits, retain
read-only permissions, and disable checkout credential persistence. Preserve the
70% backend coverage and fixable HIGH/CRITICAL Trivy gates. Use independent
backend/frontend scan matrix entries with fail-fast disabled and explicit Trivy
0.70.0. Make Sonar an opt-in push-only integration, with a clear missing-secret
error when enabled. Add context exclusions without changing application code.

## Alternatives and consequences

A registry or image artifacts could avoid repeated builds but add credentials,
storage, and coordination; independent local builds are sufficient here. Always
requiring Sonar would couple basic CI to a remote account; optional integration
keeps local-verifiable gates available without claiming a remote quality gate.
Pins require deliberate maintenance. Scan results age as vulnerability data changes.
Base tags and all transitive dependencies remain a later reproducibility task.
GitHub required-check rules must be configured separately after a real run.
