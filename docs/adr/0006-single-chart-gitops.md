# ADR 0006: one Helm chart for Kubernetes and GitOps

- Status: Accepted for code and local lab only
- Date: 2026-10-29

## Decision

Use one CloudCart Helm chart. Generate the plain Kubernetes files from it and
have Argo CD render that chart too. CI detects stale generated files. Keep
credentials outside Git and Helm values. The production profile rejects missing
release prerequisites, mutable image tags, unrestricted database egress, and
backend scaling before migrations exist.

Argo's project is limited to this repository and one namespace, without cluster
resources or secret-management permission. Start with manual sync, no pruning,
and no deletion finalizer. Pin actual deployments to a reviewed Git commit.

## Tradeoffs

Local PostgreSQL is a single-instance learning database with a retained PVC.
Production uses an external managed database and an approved ingress/access
boundary. Kind's default CNI does not prove NetworkPolicy enforcement. The local
host needed a documented temporary cgroup-v1 override; production must use a
supported cgroup-v2 platform. Kubernetes is an alternative to the ECS design,
not an instruction to create a second paid environment.

A Helm-to-Argo handoff means Git owns future changes. Do not use two deployment
managers concurrently. A code rollback does not restore database contents.
