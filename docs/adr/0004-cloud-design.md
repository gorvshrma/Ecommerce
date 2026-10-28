# ADR 0004: propose a managed cloud demo before a Kubernetes lab

- Status: Proposed; no infrastructure approved or created
- Date: 2026-10-29

## Why this decision is needed

The app is small. Cloud cost and learning time matter. The current local setup
and CI checks work, but that does not choose a safe, affordable cloud platform.

## Proposal

Use ECS/Fargate with a private RDS PostgreSQL database for the first managed
cloud demo, subject to region, cost, access, backup, and teardown approval.
Continue using Compose locally. Keep EKS as a separate Kubernetes learning lab.

## Alternatives

One EC2 server with Compose is simpler and may cost less, but you manage patches,
backups, and a single point of failure. EKS teaches Kubernetes but adds a
control-plane charge and more operating choices. Local Kubernetes can teach
those concepts before a paid EKS lab.

## What this means

This is a written proposal only. The app has no public-write access controls,
reviewed migration process, or tested cloud restore. Resolve those deployment
boundaries and confirm budget before resource creation. Full details and sources
are in [Cloud design](../CLOUD-DESIGN.md).
