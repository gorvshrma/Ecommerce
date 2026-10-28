# Phase 3A: a cloud design you can understand

Status: design with an offline-validated [Terraform implementation](../terraform/README.md),
dated 2026-10-29. No AWS resources, AWS accounts, Terraform
state buckets, or deployment credentials were created by this work. This page
explains a possible next build. It does not authorize a paid deployment.

## 1. What are we trying to learn?

Run the same small app in AWS, keep its database private, ship changes through
review, and practise recovery. Keep the shopping features unchanged. Avoid adding
Kubernetes just to make a diagram look complex.

| Option | What you manage | Good learning use | Main tradeoff |
| --- | --- | --- | --- |
| Local Compose | Your computer and three containers | Learn the app and Docker first | Not an AWS deployment |
| One EC2 server with Compose | A virtual server, patches, app, and database backups | A short, low-cost server exercise | One server failure stops everything |
| ECS/Fargate plus RDS | Container settings and a managed database | First managed container deployment | More network and database cost |
| EKS plus RDS | Kubernetes workloads and cluster choices | A separate Kubernetes learning lab | Higher fixed cost and more operations |

Recommendation: design ECS/Fargate plus RDS as the first managed demo. Keep
local Compose for daily development. Use local Kubernetes first if your main
goal is learning Kubernetes; make EKS a separate, time-limited exercise.
This recommendation is proposed, not a deployed decision. See [ADR 0004](adr/0004-cloud-design.md).

## 2. The proposed route for a request

```text
Approved demo viewer
       | HTTPS, access limited to approved viewers
       v
Application Load Balancer (the entry point)
       | sends traffic only to application tasks
       v
Frontend task and backend task in private application subnets
       | backend alone can connect on database port 5432
       v
RDS PostgreSQL in private database subnets
```

A VPC is the private network. Subnets divide it into sections. Security groups
allow only the connections listed above. The load balancer lives in public
subnets; application tasks and the database do not get public addresses.

Private tasks still need a way to pull images and send logs. Compare a NAT
gateway with the needed VPC endpoints in the regional estimate. Neither choice
is free. A single NAT gateway may be acceptable for a disposable learning demo,
but it is a failure point and can add cross-zone charges. Two gateways cost more.
Do not call a single-task, single-database-instance demo highly available.

Cloud frontend builds need the real HTTPS API address in `VITE_API_URL` and the
matching frontend address in backend CORS settings. `localhost` would point to
the visitor's computer and is not a cloud API address.

The implementation chooses private AWS endpoints instead of a NAT gateway.
It defaults to two frontend tasks, one backend task, Multi-AZ RDS, WAF, and
365-day CloudWatch log retention. The example below remains a smaller historical
comparison; it is not a quote for these implementation defaults. Price the actual
configuration before approval.

## 3. Budget before build

No AWS region or spending limit was selected by the user. Use `us-east-1` only
for the example arithmetic below. Mumbai (`ap-south-1`) may suit an India-based
demo, but get a separate regional estimate before choosing. No free-tier credits,
taxes, currency conversion, discounts, or savings commitments are assumed.

AWS lists Linux/x86 Fargate example rates in US East as $0.000011244 per vCPU
second and $0.000001235 per GB-second. For two small tasks, each requesting
0.25 vCPU and 0.5 GB RAM, running for 730 hours:

```text
CPU:    2 x 0.25 x 730 x 3600 x 0.000011244 = about $14.77
Memory: 2 x 0.5  x 730 x 3600 x 0.000001235 = about $3.25
Compute only: about $18.02 per month
```

These sizes are starting assumptions, not a measured capacity recommendation.
That $18.02 is not the total bill. Here is a rough planning allowance, not an
AWS quote, for a small always-on managed demo:

| Item | Monthly allowance in USD | Why it exists |
| --- | --- | --- |
| Two Fargate tasks | About 18 | App compute under the example assumptions |
| Load balancer | 25-45 | HTTPS entry point and usage |
| Small single-instance RDS and storage | 25-60 | Database capacity and disk |
| NAT/network access | 35-70 | Private tasks reaching required services |
| Logs, images, secrets, backups, and transfer | 10-30 | Supporting services and retained data |
| Planning envelope | About 120-230 | Rounded allowance, not a guaranteed maximum |

The non-compute rows are author estimates to reserve budget, not fetched AWS
unit prices. Use the [AWS calculator](https://calculator.aws/) to replace them
with region, instance, storage, traffic, IPv4, and uptime-specific prices before
approval. Include DNS/domain fees if needed. Capture the calculator estimate in
the implementation PR. A short demo can lower compute hours, but load balancers,
NAT, storage, snapshots, and some database costs can continue after tasks stop.

ECS has no separate orchestration fee for ordinary EC2/Fargate hosting. Standard
EKS control-plane pricing alone is $0.10/hour, about $73 for 730 hours, before
workers, database, networking, and logs. That is why EKS is not the first
cost-conscious managed demo in this proposal.

Before creating paid resources, agree an actual spending limit. Propose alerts
at 50%, 80%, and 100% of that limit and a review date after each lab session.
Budget alerts can arrive after usage; they do not automatically cap all charges.
Do not create an alert subscription or send email without the user's instructions.

## 4. Permissions and secrets

IAM means permissions. Give each component only the access it needs:

- A read-only planning role can inspect the target environment.
- A separate deployment role can change only the approved demo resources.
- A task execution role can pull images and send logs.
- The application task role gets only the secret or service access the app needs.

For future GitHub deployment, use OIDC: GitHub requests short-lived AWS access
instead of storing a permanent AWS key. Limit its trust to this repository and
a protected deployment environment. Add `id-token: write` only to that future
deployment job, not the current test workflow. Restrict who can deploy.

Keep database credentials in AWS Secrets Manager, not Git or Terraform variables
in committed files. The app currently expects a complete `DATABASE_URL`. Design
the full connection secret and password-rotation steps together: a rotated
database password must match the app's connection string, followed by a controlled
service restart. Never print either value. Test TLS certificate validation for
the database connection; do not silently turn it off to fix a connection error.

Use HTTPS at the public entry point. The current API has no login or permission
checks for writes. Keep the demo entry point restricted to approved viewers,
using a reviewed IP allowlist or an identity-aware access layer. Decide and test
that boundary before exposing any cloud endpoint. No real customer data is allowed.

## 5. Terraform state and change review

Terraform state is a record of the resources it manages. It can contain private
values, so treat it like a secret. The repository now contains a remote backend configuration and a separate
bootstrap root. No backend bucket has been created or migrated.

For a future build, use a separate bootstrap change to create an encrypted,
private S3 state bucket with versioning and limited IAM access. Choose a current
Terraform version that supports S3 state locking and set `use_lockfile = true`.
Give the runner the required lock-object access. Keep development state separate
from any later production state. Do not commit backend credentials, state files,
or saved plan files. Review how to recover an older state version.

In the infrastructure PR, add `terraform fmt -check`, `terraform validate`, and
an IaC security scan such as Checkov. A plan may access AWS and contain secrets;
restrict its access and retention. Review the saved plan and budget before a
separately approved apply. No Terraform apply or state bootstrap is part of this phase.

## 6. Backups and a real restore test

For the proposed demo, start with seven days of automated RDS backups and a
manual snapshot before risky changes. Confirm encryption and retention costs.
The database and its backups must have separate lifecycle decisions from app tasks.

Proposed learning targets: lose no more than 24 hours of data (RPO) and restore
service within two hours (RTO). These are goals, not measured guarantees.

A restore drill should:

1. Write a small fake test order and record the product/order counts.
2. Record the backup or point-in-time restore target.
3. Restore to a new private database, keeping the original database intact.
4. Point a test-only backend at the restored database using a new private secret.
5. Check readiness, counts, and the fake order. Measure elapsed time and data loss.
6. Record the result, then remove the test resources after approval.

A successful backup job alone is not a successful restore test. Never overwrite
the only database to test recovery. Reverting application code does not revert data.

## 7. Releases and rollback

Before a cloud release, record the image digest of the last working release.
If a new release fails health checks, redeploy that previous digest and verify
readiness and the catalog. Do not rebuild an old tag and assume it is identical.

The current backend creates tables and seeds data during startup; there is no
reviewed migration system. Start with one backend task for this demo design.
Before concurrent startup, schema changes, or scaling, design migrations and
check that the old application can still use the new schema. This is required
work before claiming safe production rollbacks.

## 8. Teardown: stop costs without losing needed data

No cloud teardown commands can be exact yet because no Terraform stack exists.
Do not copy a generic `terraform destroy` command into an unknown account.
For the future implementation, document the actual account, region, state key,
workspace, and approved destroy-plan filename before running it.

The order for that future runbook is:

1. Confirm account and region, stop new writes, and save any required backup.
2. List resources by the CloudCart project/environment tags.
3. Review a destroy plan for disposable app resources. Exclude retained data
   and the state backend using the deliberately separate stack boundaries.
4. After approval, remove tasks, load balancer, unused NAT/endpoints, and other
   disposable resources. Remove the database only if data deletion is approved.
5. List remaining images, disks, snapshots, logs, secrets, IPs, and network
   resources. Each can keep a cost even after the app stops.
6. Keep the state bucket until resource reconciliation is complete. Recheck
   the bill after usage data arrives and record any retained costs.

This phase created no AWS resources, so there is nothing in AWS to tear down.
The local Compose `down` command still preserves the local database volume.

## 9. What must be decided before implementation?

Confirm the demo purpose, approved AWS account, region, maximum budget, runtime
option, access-control boundary, retention rules, and who will run teardown.
The infrastructure PR now implements the configuration only. No AWS resource creation is authorized by
this design document or by the earlier local/CI work.

## Official sources checked on 2026-10-29

- [Fargate example rates](https://aws.amazon.com/fargate/pricing/)
- [ECS pricing](https://aws.amazon.com/ecs/pricing/)
- [EKS pricing](https://aws.amazon.com/eks/pricing/)
- [EC2 pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [RDS pricing](https://aws.amazon.com/rds/pricing/)
- [AWS budget behavior](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
- [GitHub OIDC in AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
- [Terraform S3 state and locking](https://developer.hashicorp.com/terraform/language/backend/s3)
- [RDS backup and restore](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithAutomatedBackups.html)
