variable "state_bucket_name" {
  description = "Globally unique bucket name approved for Terraform state."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "Use a valid globally unique S3 bucket name."
  }
}

resource "aws_kms_key" "state" {
  description             = "Encrypt CloudCart Terraform state"
  policy                  = jsonencode({ Version = "2012-10-17", Statement = [{ Sid = "AccountIAM", Effect = "Allow", Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" }, Action = "kms:*", Resource = "*" }] })
  enable_key_rotation     = true
  deletion_window_in_days = 30
  lifecycle { prevent_destroy = true }
}
resource "aws_kms_alias" "state" {
  name          = "alias/${local.name}-terraform-state"
  target_key_id = aws_kms_key.state.key_id
}
resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_144:No second region/budget is approved. Versioning and deletion protection remain enabled; cross-region DR is not claimed.
  bucket        = var.state_bucket_name
  force_destroy = false
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RequireTLS", Effect = "Deny", Principal = "*", Action = "s3:*"
        Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "DenyOtherEncryption", Effect = "Deny", Principal = "*", Action = "s3:PutObject"
        Resource  = "${aws_s3_bucket.state.arn}/*"
        Condition = { StringNotEqualsIfExists = { "s3:x-amz-server-side-encryption" = "aws:kms" } }
      },
      {
        Sid       = "RequireStateKey", Effect = "Deny", Principal = "*", Action = "s3:PutObject"
        Resource  = "${aws_s3_bucket.state.arn}/*"
        Condition = { StringNotEqualsIfExists = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.state.arn } }
      }
    ]
  })
}
output "state_bucket" { value = aws_s3_bucket.state.id }
output "state_key_arn" { value = aws_kms_key.state.arn }
output "backend_configuration" {
  description = "Non-secret metadata; use a different state key for each stack."
  value = {
    bucket               = aws_s3_bucket.state.id
    region               = var.aws_region
    kms_key_id           = aws_kms_key.state.arn
    encrypt              = true
    use_lockfile         = true
    allowed_account_ids  = [var.aws_account_id]
    workspace_key_prefix = "cloudcart/${var.environment}/workspaces"
  }
}

resource "aws_iam_policy" "state_access" {
  name        = "${local.name}-terraform-state-access"
  description = "Attach only to approved Terraform roles; no state deletion permission"
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.state.arn, Condition = { StringLike = { "s3:prefix" = ["cloudcart/${var.environment}/*"] } } },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = "${aws_s3_bucket.state.arn}/cloudcart/${var.environment}/*" },
    { Effect = "Allow", Action = ["s3:DeleteObject"], Resource = "${aws_s3_bucket.state.arn}/cloudcart/${var.environment}/*.tflock" },
    { Effect = "Allow", Action = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"], Resource = aws_kms_key.state.arn }
  ] })
}
output "state_access_policy_arn" { value = aws_iam_policy.state_access.arn }

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "abort-incomplete-uploads-only"
    status = "Enabled"
    filter { prefix = "" }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
    # Never expire state versions automatically.
  }
}
resource "aws_s3_bucket_notification" "state" {
  bucket      = aws_s3_bucket.state.id
  eventbridge = true
}
resource "aws_s3_bucket" "audit" {
  #checkov:skip=CKV_AWS_18:Dedicated server-access-log destination; no recursive logging.
  #checkov:skip=CKV_AWS_145:S3 server access logs use SSE-S3 here; the actual state bucket uses a dedicated KMS key.
  #checkov:skip=CKV_AWS_144:Cross-region audit replication needs an approved second region and retention budget.
  bucket_prefix = "${local.name}-state-audit-"
  force_destroy = false
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Principal = { Service = "logging.s3.amazonaws.com" }, Action = "s3:PutObject", Resource = "${aws_s3_bucket.audit.arn}/state/*", Condition = { StringEquals = { "aws:SourceAccount" = var.aws_account_id }, ArnLike = { "aws:SourceArn" = aws_s3_bucket.state.arn } } },
    { Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.audit.arn, "${aws_s3_bucket.audit.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }
  ] })
}
resource "aws_s3_bucket_logging" "state" {
  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.audit.id
  target_prefix = "state/"
  depends_on    = [aws_s3_bucket_policy.audit]
}
resource "aws_s3_bucket_lifecycle_configuration" "audit" {
  bucket     = aws_s3_bucket.audit.id
  depends_on = [aws_s3_bucket_versioning.audit]
  rule {
    id     = "audit-retention"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = 365 }
    noncurrent_version_expiration { noncurrent_days = 365 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}
resource "aws_s3_bucket_notification" "audit" {
  bucket      = aws_s3_bucket.audit.id
  eventbridge = true
}
