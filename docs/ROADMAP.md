# Roadmap: what we will do next

## Phase 1: run locally - complete

Use a private `.env`, reject missing database settings, keep existing services
and database storage, and provide exact setup commands. Local smoke checks pass.
A smoke check is a quick check that the main parts start and respond.

## Phase 2: check code automatically - implemented and tested

GitHub runs tests, builds, and two image scans. Actions are pinned to known
commits. The five jobs passed on GitHub. `main` now has active PR and check rules.
PR #1 is the review and merge point. See its live status and [Readiness](READINESS.md).
Sonar is optional and has not been verified remotely.

## Phase 3A: design the cloud setup - written, not provisioned

Read [Cloud design](CLOUD-DESIGN.md). It compares costs and explains the proposed
network, permissions, secrets, Terraform state, backup, restore, and teardown.
The recommended first managed demo is ECS/Fargate with RDS, subject to a real
regional estimate and your budget. EKS is a later Kubernetes learning option.

## Phase 3B: implement infrastructure - not started

Choose the region and budget, approve the design, then write Terraform in a
new PR. Add format, validation, and infrastructure security checks such as
Checkov. Review the plan before any apply. Do not put credentials into code.
Creating resources requires separate approval; this phase has not done that.

## Phase 4: deploy and practise recovery - not started

Add a deliberate access-control boundary, HTTPS, image release tags, and health
checks. Test a deployment, a failed release rollback, and a database restore.
Add useful logs and alerts. Introduce Helm or GitOps only if using Kubernetes.
Keep the app's shopping features simple while learning operations.

## How to call a phase complete

Link the reviewed change, commands someone else can repeat, and actual results.
For a deployed feature, name the environment and show the check that proved it
works. A folder, diagram, or green build alone does not prove a cloud service is running.
