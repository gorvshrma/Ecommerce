# Terraform: prepare now, create resources only after approval

Terraform describes cloud resources in text files. This code is written and
checked, but **nothing has been created in AWS**. No real AWS plan or apply has
run. The tests use a fake AWS provider and cannot deploy anything.

## 1. The three folders

| Folder | What a later approved apply would create | Data protection |
| --- | --- | --- |
| `bootstrap` | Private state bucket, KMS key, audit bucket, state-access policy | State, audit bucket, and key cannot be destroyed by a normal plan |
| `platform` | Two-zone VPC, private endpoints, RDS, ECR, connection-secret metadata, logs | Database, keys, secret, and image repositories are retained |
| `application` | HTTPS load balancer, WAF, ECS tasks, runtime roles and logs | Database and state are in other stacks; load balancer deletion protection starts enabled |

These are separate Terraform roots, each with its own state key. Do not combine
them into one state or destroy the state backend with the app. The application
receives non-secret platform IDs; it does not need permission to read platform state.

The network has no NAT gateway or unrestricted task internet route. Four
interface endpoints per zone support ECR API, ECR Docker, logs, and Secrets
Manager; an S3 gateway endpoint supports image layers. **Interface endpoints
cost money even when tasks stop.** Database subnets have no internet route. Endpoint policies limit downloads and
API requests to the needed images, log groups, and app secret; IAM permissions
are still required. The regional ECR image-layer S3 bucket is read-only.

The app remains a restricted demo: its API has no login for writes. HTTPS is
allowed only from the supplied viewer networks. WAF adds common-threat,
known-bad-input, anonymous-IP, and rate-limit rules. WAF can block VPN users or
legitimate requests; test it before approving a release. No public-shop readiness
is claimed. TLS ends at the ALB; private ALB-to-task connections remain HTTP.

## 2. State and secrets never belong in Git

State is Terraform's record of real resources. It can contain private values.
Saved plans can contain the same information. `sensitive = true` alone does not
remove values from state or make a plan safe to publish.

All committed roots declare S3 backends. Backend examples require encryption,
a dedicated KMS key, account checking, and `use_lockfile = true`. The bucket has
versioning, a TLS-only policy, access logging, blocked public access, and no
automatic expiry of state versions. A scoped IAM policy permits deleting lock
objects, not state objects. It is not attached to a role automatically.

`.gitignore` excludes state, state backups, `.terraform/`, saved plans, private
variable files, backend files, and local secret files. CI also checks Git's
tracked list, so forcing one of these files into Git still fails. The guard
recognizes renamed Terraform JSON state and binary/JSON plans too. It is a
backup control, not permission to store secrets carelessly.

**Commit `.terraform.lock.hcl`.** It records provider versions and checksums,
not your infrastructure state. All three locks select AWS provider 6.71.0 and
include Windows/Linux checksums. Use Terraform 1.17.1. Do not run `init -upgrade`
without reviewing a deliberate provider update.

RDS manages the administrator password. Terraform never reads that password.
The application secret is an empty Secrets Manager container in code: there is
no `secret_version` resource or plaintext connection password. Its value must
be populated privately outside Terraform. No passwords or tokens are inputs.

If a state/plan or credential was ever pushed, adding it to `.gitignore` does
not remove it from history. Restrict access, rotate exposed credentials, and
follow a reviewed incident/history-cleanup process. Never hide the exposure.

## 3. Safe checks you can run now

Install [Terraform](https://developer.hashicorp.com/terraform/install), Python,
and Docker. Run from the repository root. No AWS login is needed for these checks:

```powershell
python scripts/test_terraform_hygiene.py
python scripts/check_terraform_hygiene.py
terraform fmt -check -recursive terraform
foreach ($stack in @('bootstrap','platform','application')) {
    terraform "-chdir=terraform/$stack" init -backend=false -input=false -lockfile=readonly
    if ($LASTEXITCODE -ne 0) { throw "Init failed: $stack" }
    terraform "-chdir=terraform/$stack" validate
    if ($LASTEXITCODE -ne 0) { throw "Validation failed: $stack" }
    terraform "-chdir=terraform/$stack" test
    if ($LASTEXITCODE -ne 0) { throw "Mock tests failed: $stack" }
}
docker run --rm -v "${PWD}/terraform:/tf:ro" bridgecrew/checkov:3.4.0 --directory /tf --framework terraform --compact --quiet --skip-download
```

`init -backend=false` only downloads provider packages. It does not set up the
remote state bucket. `validate` checks configuration. `test` runs only the
committed mocked tests; do not change them to a real provider casually.

The `Terraform Validation` CI job uses these checks with a pinned Terraform
setup action and pinned Checkov image digest. It receives no AWS credentials,
has no OIDC token permission, uploads no state or plans, and cannot apply.
[Security exceptions](SECURITY-EXCEPTIONS.md) explains each scanner suppression.

## 4. Required choices before any AWS work

Do not set `deployment_approved = true` until the user separately approves the
actual AWS account, region, cost estimate, and plan. The account and region have
no defaults. Supply two actual AZs and a supported PostgreSQL 16 minor version.
Choose the database class after pricing it. Multi-AZ is enabled by default.
An existing private DB administration path and its approved security-group ID
are required for initial setup and recovery. This stack creates no public SSH
host or admin tunnel; approve any needed admin-access resources separately.

The app has two frontend tasks and one backend task. The existing backend has
no reviewed migration system, so this is not a fully highly available production
application. A rolling release may briefly overlap old/new backend tasks; review
schema compatibility before release. Do not increase replicas before fixing
startup/migration coordination. Task capacity is only a starting assumption.

These defaults add costs beyond the earlier two-task/single-database example:
three tasks, Multi-AZ RDS, eight interface-endpoint ENIs, WAF, and retained logs.
Recalculate in the approved region. No free-tier credit or hard spend cap is assumed.
Budgets, alarm notification recipients, and deployment roles are not created here.
A shared IAM/OIDC deployment setup must be approved separately; this is offline CI only.

## 5. Copy private settings, never commit them

```powershell
foreach ($stack in @('bootstrap','platform','application')) {
    if (!(Test-Path "terraform/$stack/terraform.tfvars")) {
        Copy-Item "terraform/$stack/terraform.tfvars.example" "terraform/$stack/terraform.tfvars"
    }
    if (!(Test-Path "terraform/$stack/backend.hcl")) {
        Copy-Item "terraform/$stack/backend.hcl.example" "terraform/$stack/backend.hcl"
    }
}
```

Edit the copied files. `REPLACE` values deliberately do not work. Keep
`deployment_approved = false` now. Example test account IDs, hostnames, and
PostgreSQL versions are fake/offline inputs, not a selected deployment.
Use a different state key for each environment and root, for example
`cloudcart/dev/platform/terraform.tfstate`. Use the matching
`workspace_key_prefix` and bucket policy. Keep the default Terraform workspace;
use explicit state keys rather than changing workspaces for this project.

## 6. Bootstrap the first state bucket - future approved operation only

A backend cannot create its own bucket before that bucket exists. There are two
safe choices: use an existing approved organization state backend, or perform a
one-time bootstrap outside the Git checkout on an encrypted private disk.

For a first bucket, the future operator must:

1. Copy `terraform/bootstrap` into a new private folder outside every Git repo.
   Do not copy `.terraform/`. Keep the provider lock file. Use an encrypted disk.
2. Only in that private copy, replace `backend "s3" {}` with `backend "local" {}`.
   Point the local backend `path` at that private folder. Never edit a committed
   root to use local state.
3. Set the approved bootstrap inputs, log in using an approved short-lived AWS
   session, confirm account/region, and review a saved bootstrap plan there.
4. Only after approval, apply that plan. At that moment, paid state/audit storage
   and a KMS key may exist. This phase has NOT executed these steps.
5. In the same private copy, restore the original S3 backend declaration. Fill
   `backend.hcl` with the new bucket, its KMS ARN, region, approved account,
   bootstrap state key, encryption, lock setting, and workspace prefix.
6. Run `terraform init -migrate-state -backend-config=backend.hcl`. Review the
   migration prompt; do not use `-force-copy` to skip it. Confirm the state object
   is in S3, versioning/encryption are active, and a second session respects locking.
7. Initialize the committed bootstrap root against the same S3 key, then confirm
   it sees the existing resources with no unexpected changes. Retain the private
   recovery copy until migration is verified. Dispose of it under the approved
   encrypted-disk retention policy, not by committing or uploading it.

Do not delete the local copy before migration is verified. The actual commands
for account login and bucket names depend on the approved account; no AWS login,
state migration, plan, apply, or locking integration test has run in this change.

## 7. Future platform and application deployment

Once the backend exists, initialize each root using its private configuration:

```powershell
terraform -chdir=terraform/platform init -backend-config=backend.hcl -input=false -lockfile=readonly
terraform -chdir=terraform/platform plan -out=platform.tfplan
```

This is an AWS-connected plan, not the offline test. Run it only after the input
and budget approval. Review the account, region, resource count, and cost estimate.
Do not commit the plan. Do not add `-auto-approve`. Apply only the reviewed saved
plan, after separate resource-creation approval:

```powershell
terraform -chdir=terraform/platform apply platform.tfplan
```

After a future platform apply, copy `application_inputs` output into the private
application variable file. It contains IDs, not passwords. Before the runtime:

- Build and scan images; push to the new ECR repositories, then use exact digests.
- Build the frontend for the real `https://domain_name`, not localhost.
- Prepare a backend image with the AWS RDS CA bundle at a known path.
- Have a database administrator initialize the schema, create a separate
  restricted application user, and grant only needed table/sequence permissions.
  The app should not use its administrator password for normal requests.
- Store the complete app DSN in the existing app secret using a private file
  outside Git and a protected AWS session. Use `sslmode=verify-full` and the
  CA path in that DSN. Do not paste a password into shell history or Terraform.
- Verify credential rotation updates both the database password and app secret,
  then redeploys the service. Rotation is not automated by these files.
- Supply an existing issued ACM certificate, configure DNS, and review viewer
  IPv4 networks. Use a narrow `/32` where possible; `/0` is rejected.
- Verify these prerequisites before setting `deployment_inputs_verified = true`.

The current image does not supply the RDS bundle automatically. These are real
release blockers, not completed production controls. Then review an application
plan and apply only after approval, using the same saved-plan workflow. Verify
health, readiness, catalog, WAF behavior, and a fake order in the approved demo.

## 8. Stop, recreate, and destroy are different

Stopping tasks does not remove endpoint, load-balancer, RDS, storage, or log costs.
There is no pause button for the full environment. Terraform can recreate removed
resources, but deleted data needs a retained backup and a tested restore.

For a future runtime teardown, first make a reviewed change setting
`load_balancer_deletion_protection = false`, plan and apply that change. Then,
from the correct initialized application root and only after approval:

```powershell
terraform -chdir=terraform/application plan -destroy -out=runtime-destroy.tfplan
# Review every deletion and the account/region. A separate approval comes next.
terraform -chdir=terraform/application apply runtime-destroy.tfplan
```

The log bucket has `force_destroy = false`. Its retained objects/versions can
block deletion. Export or retain required logs, then explicitly approve any
object/version deletion; do not force-delete them just to get a green destroy.
Do not use `-target` to skip retention controls or delete resources behind state.

Runtime teardown deliberately leaves platform and bootstrap resources and their
costs. A full lab teardown needs a separate data-retention decision. RDS deletion
protection, final snapshots, and Terraform `prevent_destroy` guard the platform.
Do not remove those guards without a reviewed teardown change and backup check.
Choose a unique final-snapshot name before each approved DB deletion. Snapshots,
ECR images, endpoints, KMS keys, logs, and state storage can continue to cost money.

After teardown, reconcile all resources in the correct account/region, inspect
retained artifacts, and recheck billing when usage data arrives. Keep the state
backend until every stack is reconciled. No destroy is needed now: nothing in
AWS was created by this phase.

## 9. Code rollback

Before commit, restore only edited existing files from the saved snapshot and
remove only the new files from this phase. After a shared commit, use a new
`codex/` branch and `git revert COMMIT_ID`, then a checked PR. This undoes code,
not AWS data or live repository rules. Exact commit IDs are in the completion
report. [Runbook](../docs/RUNBOOK.md) explains the Git sequence.

## Official references

- [S3 backend, encryption, IAM, and lock permissions](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Mocked Terraform tests](https://developer.hashicorp.com/terraform/language/tests/mocking)
- [ALB access-log bucket requirements](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html)
- [RDS-managed administrator secrets](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html)
