# ADR 0005: protect state and separate infrastructure lifetimes

- Status: Accepted for implementation; not applied in AWS
- Date: 2026-10-29

## Why this decision is needed

Terraform state and saved plans can contain private values. A single destroy
command must not accidentally remove the application's database and state history.
We also need useful infrastructure checks before granting AWS access to CI.

## Decision

Use three independent roots with S3 backends: bootstrap, platform, and application.
Use encrypted, versioned, private state storage with native S3 locking. Keep state,
plans, private inputs, and backend files out of Git and block them in CI, including
renamed Terraform artifacts. Commit provider dependency locks. Create no secret
values in Terraform: RDS manages its admin password and app DSN values are supplied
outside state. Transfer only non-secret IDs between roots, not full remote state.

CI formats and validates configuration, runs mocked provider tests and Checkov,
and has no AWS credentials or apply job. Creation needs explicit input approval.
Use private endpoints instead of a NAT gateway because this app needs only the
listed AWS services and its database. Endpoint costs remain while tasks stop.

## Tradeoffs and limits

A first state bucket needs an approved existing backend or a one-time local
bootstrap on encrypted storage outside Git, then a verified migration. Separate
roots require deliberate output/input handoff and destroy order. Strong deletion
protection intentionally makes full teardown more than one command. Scanner
exceptions, app migration/credential/TLS prerequisites, and regional pricing are
visible in the guide. Code and mocked tests are not deployed production evidence.
