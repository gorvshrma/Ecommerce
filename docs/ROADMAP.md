# DevOps roadmap

Items below are planned unless explicitly identified as implemented in
[Architecture](ARCHITECTURE.md) and [Readiness](READINESS.md). No cloud
resources are part of Phase 1.

## Phase 1 - local configuration and project documentation

Implemented and locally smoke-tested: explicit Compose environment loading, required
configuration validation, exact local setup instructions, and architecture,
operations, readiness, roadmap, and decision records. Preserve the current
application features and local service topology.

## Phase 2 - CI and supply-chain controls

Implemented locally: pinned top-level actions, explicit read-only permissions,
independent image scans, context exclusions, and opt-in Sonar. Backend coverage,
fresh frontend build, both image builds, workflow validation, and both Trivy
policy scans pass locally. See [CI](CI.md) and [Readiness](READINESS.md).

Still pending: an authorized push, GitHub-hosted results, required-check rules,
and optional Sonar setup. Add Checkov or equivalent IaC scanning when IaC changes
are introduced. Local verification is not proof of remote CI enforcement.

## Phase 3 - cloud foundation

Design and review Terraform for networking, IAM, ECR, and a runtime/data
platform. Define secret handling, state locking and storage, cost limits,
backup, and teardown procedures before any apply. Provisioning requires a
separate explicit decision; it is outside this phase.

## Phase 4 - deployment and operations

Deploy workloads with deliberate health probes, resource limits, ingress,
network policies, and rollback procedures. Add Helm and GitOps only with a
defined cluster and release process. Establish metrics, dashboards, alerts,
backup/restore drills, and documented incident and rollback exercises.

## Completion evidence

For each phase, link reviewed code, reproducible commands, successful checks,
and (for deployed controls) environment evidence. Do not label planned items as
implemented based only on directory names or design documents.
