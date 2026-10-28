# ADR 0001: Keep Phase 1 local and preserve the Compose topology

- Status: Accepted
- Date: 2026-10-29

## Context

CloudCart is a small portfolio application with an existing frontend, API, and
PostgreSQL Compose stack. Phase 1 focuses on trustworthy local setup and
documentation. Changing service topology or creating cloud resources would
expand scope and make review and rollback less focused.

## Decision

Keep the existing three Compose services, ports, network, and named database
volume. Do not create AWS resources in Phase 1. Describe cloud and production
controls as planned until they are implemented and verified.

## Consequences

Local development remains familiar and the existing database volume remains
the persistence boundary. Cloud deployment and production readiness require
later decisions, implementation, and evidence.
