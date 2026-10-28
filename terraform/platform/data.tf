resource "aws_kms_key" "application" {
  description             = "CloudCart database, secrets, images, and logs"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "AccountIAM", Effect = "Allow", Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" }, Action = "kms:*", Resource = "*" },
      {
        Sid       = "CloudWatchLogs", Effect = "Allow"
        Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
        Condition = { ArnLike = { "kms:EncryptionContext:aws:logs:arn" = ["arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/cloudcart/${var.environment}/*", "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:aws-waf-logs-${local.name}", "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/rds/instance/${local.name}/*"] } }
      }
    ]
  })
  lifecycle { prevent_destroy = true }
}
resource "aws_kms_alias" "application" {
  name          = "alias/${local.name}-application"
  target_key_id = aws_kms_key.application.key_id
}
resource "aws_ecr_repository" "application" {
  for_each             = toset(["frontend", "backend"])
  name                 = "${local.name}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.application.arn
  }
  lifecycle { prevent_destroy = true }
}
resource "aws_ecr_lifecycle_policy" "application" {
  for_each   = aws_ecr_repository.application
  repository = each.value.name
  policy     = jsonencode({ rules = [{ rulePriority = 1, description = "Remove only untagged images after 14 days", selection = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 14 }, action = { type = "expire" } }] })
}
resource "aws_secretsmanager_secret" "database_url" {
  #checkov:skip=CKV2_AWS_57:Metadata only; no secret value or rotation Lambda is managed here. App-password rotation and restart must be verified before runtime approval.
  name                    = "/cloudcart/${var.environment}/database-url"
  description             = "Complete TLS-verified app DATABASE_URL; populate outside Terraform using a restricted DB user"
  kms_key_id              = aws_kms_key.application.arn
  recovery_window_in_days = 30
  lifecycle { prevent_destroy = true }
}
variable "database_instance_class" {
  description = "Capacity is a budget decision, not a measured workload recommendation."
  type        = string
}
variable "database_multi_az" {
  description = "Keep true for production-like availability; changing this is a deliberate cost/reliability decision."
  type        = bool
  default     = true
}
variable "database_engine_version" {
  description = "Approved PostgreSQL 16 minor version supported in the selected region. Required, never auto-select latest."
  type        = string
  validation {
    condition     = can(regex("^16[.][0-9]+$", var.database_engine_version))
    error_message = "Select a supported and reviewed PostgreSQL 16 minor version."
  }
}
resource "aws_db_subnet_group" "main" {
  name        = local.name
  description = "Private database subnets with no internet default route"
  subnet_ids  = [for subnet in aws_subnet.database : subnet.id]
}
resource "aws_db_parameter_group" "main" {
  name_prefix = "${local.name}-"
  family      = "postgres16"
  description = "Require encrypted PostgreSQL connections"
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
  lifecycle { create_before_destroy = true }
}
resource "aws_iam_role" "monitoring" {
  name               = "${local.name}-rds-monitoring"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "monitoring.rds.amazonaws.com" }, Action = "sts:AssumeRole", Condition = { StringEquals = { "aws:SourceAccount" = var.aws_account_id }, ArnLike = { "aws:SourceArn" = "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:db:${local.name}" } } }] })
}
resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
resource "aws_db_instance" "main" {
  identifier                            = local.name
  engine                                = "postgres"
  engine_version                        = var.database_engine_version
  instance_class                        = var.database_instance_class
  db_name                               = "cloudcart"
  username                              = "cloudcart_admin"
  manage_master_user_password           = true
  master_user_secret_kms_key_id         = aws_kms_key.application.arn
  allocated_storage                     = 20
  max_allocated_storage                 = 100
  storage_type                          = "gp3"
  storage_encrypted                     = true
  kms_key_id                            = aws_kms_key.application.arn
  db_subnet_group_name                  = aws_db_subnet_group.main.name
  parameter_group_name                  = aws_db_parameter_group.main.name
  vpc_security_group_ids                = [aws_security_group.internal["database"].id]
  publicly_accessible                   = false
  multi_az                              = var.database_multi_az
  backup_retention_period               = 7
  backup_window                         = "03:00-04:00"
  maintenance_window                    = "sun:04:30-sun:05:30"
  copy_tags_to_snapshot                 = true
  delete_automated_backups              = false
  deletion_protection                   = true
  skip_final_snapshot                   = false
  final_snapshot_identifier             = "${local.name}-final"
  auto_minor_version_upgrade            = true
  allow_major_version_upgrade           = false
  apply_immediately                     = false
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.monitoring.arn
  database_insights_mode                = "standard"
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.application.arn
  performance_insights_retention_period = 7
  iam_database_authentication_enabled   = true
  depends_on                            = [aws_iam_role_policy_attachment.monitoring, aws_cloudwatch_log_group.database]
  lifecycle { prevent_destroy = true }
}
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/cloudcart/${var.environment}/vpc-flow"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.application.arn
}
resource "aws_iam_role" "flow" {
  name               = "${local.name}-flow-logs"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "vpc-flow-logs.amazonaws.com" }, Action = "sts:AssumeRole", Condition = { StringEquals = { "aws:SourceAccount" = var.aws_account_id }, ArnLike = { "aws:SourceArn" = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc-flow-log/*" } } }] })
}
resource "aws_iam_role_policy" "flow" {
  role = aws_iam_role.flow.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "${aws_cloudwatch_log_group.flow.arn}:*" },
    { Effect = "Allow", Action = ["logs:DescribeLogGroups"], Resource = "*" }
  ] })
}

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow.arn
  iam_role_arn         = aws_iam_role.flow.arn
  depends_on           = [aws_iam_role_policy.flow]
}
output "application_inputs" {
  description = "Non-secret IDs to copy into ignored application terraform.tfvars; no remote-state reader permissions needed."
  value = {
    vpc_id                     = aws_vpc.main.id
    public_subnet_ids          = [for subnet in aws_subnet.public : subnet.id]
    application_subnet_ids     = [for subnet in aws_subnet.application : subnet.id]
    alb_security_group_id      = aws_security_group.service["alb"].id
    frontend_security_group_id = aws_security_group.service["frontend"].id
    backend_security_group_id  = aws_security_group.service["backend"].id
    kms_key_arn                = aws_kms_key.application.arn
    database_url_secret_arn    = aws_secretsmanager_secret.database_url.arn
    frontend_repository_arn    = aws_ecr_repository.application["frontend"].arn
    backend_repository_arn     = aws_ecr_repository.application["backend"].arn
  }
}
output "database_address" { value = aws_db_instance.main.address }
output "database_admin_secret_arn" {
  description = "Only a secret identifier. The password itself is managed by RDS, never read into Terraform."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}
output "repository_urls" { value = { for name, repository in aws_ecr_repository.application : name => repository.repository_url } }

resource "aws_cloudwatch_log_group" "database" {
  for_each          = toset(["postgresql", "upgrade"])
  name              = "/aws/rds/instance/${local.name}/${each.key}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.application.arn
}
