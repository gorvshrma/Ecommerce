# ADR 0001: keep the first phase local

- Status: Accepted
- Date: 2026-10-29

## Why this decision was needed

The app already had three parts running in Docker Compose. We needed a safe,
repeatable local setup before spending money on cloud infrastructure.

## Decision

Keep the three services, their ports, network, and database volume. Add clear
configuration checks and documentation. Do not create AWS resources in this phase.

## What this means

Existing local behavior stays familiar. The database volume remains the local
storage boundary. Cloud hosting and production reliability need separate work
and real evidence; a design document does not provide either.
