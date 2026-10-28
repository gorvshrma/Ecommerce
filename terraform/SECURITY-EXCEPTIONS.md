# Scanner exceptions and production limits

Checkov 3.4.0 scans the entire Terraform tree. CI has no global skip list and no
soft-fail setting. Exceptions are comments on individual resources, with reasons.
They do not make an unimplemented control exist. Review them with each change.

| Check | Resource and reason | What remains true or still needs work |
| --- | --- | --- |
| CKV_AWS_145 | ALB/state-audit log destination buckets use SSE-S3 for AWS log delivery | Actual state uses a dedicated KMS key; all buckets block public access and require TLS |
| CKV_AWS_18 | Log destination buckets do not recursively log to themselves | The actual state bucket has access logging enabled |
| CKV_AWS_144 | State and log buckets have no cross-region replication | No second region/budget is approved; cross-region disaster recovery is not claimed |
| CKV2_AWS_5 | ALB/frontend/backend groups are attached from the separate application state | Mock tests verify private service placement; database/endpoint groups are checked normally |
| CKV_AWS_260 | Private frontend ingress references only the ALB security group, not a CIDR | Scanner cannot resolve the supplied cross-stack ID; public access is limited at ALB/WAF |
| CKV_AWS_378 | Existing application images serve HTTP behind the HTTPS ALB | Private target traffic is restricted by group rules; end-to-end TLS is not implemented |
| CKV2_AWS_57 | Terraform creates app-secret metadata only, with no credential value or rotation Lambda | A tested password/DSN rotation and task restart process is required before deployment |

The root Nginx master is also an existing image limitation. Its task uses a
read-only root filesystem, two explicit writable runtime volumes, and reduced
capabilities. Fargate cannot add arbitrary Linux capabilities, so the frontend
keeps only needed default capabilities by dropping others. The backend remains
non-root and drops all capabilities. Local frontend hardening passed a smoke check;
Fargate runtime behavior has not been tested in AWS.

One backend replica, startup-created tables, no app login, no deployed alarms,
and no real backup restore drill are still production-release blockers. The
runtime requires explicit input verification, narrow viewer access, and an
approved plan. These files are production-minded infrastructure, not proof that
the current small application is safe for real customer traffic.
