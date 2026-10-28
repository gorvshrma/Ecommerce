resource "aws_s3_bucket" "access_logs" {
  #checkov:skip=CKV_AWS_18:This is a log destination; recursive access logging is deliberately not enabled.
  #checkov:skip=CKV_AWS_144:Cross-region log replication needs a separately approved destination, region, and retention budget.
  #checkov:skip=CKV_AWS_145:ALB log delivery requires SSE-S3 for this destination; public access and plaintext transport are blocked.
  bucket_prefix = "${local.name}-alb-logs-"
  force_destroy = false
}
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket     = aws_s3_bucket.access_logs.id
  depends_on = [aws_s3_bucket_versioning.access_logs]
  rule {
    id     = "retain-90-days"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 30 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}
resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }, Action = "s3:PutObject", Resource = "${aws_s3_bucket.access_logs.arn}/alb/AWSLogs/${var.aws_account_id}/*" },
    { Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.access_logs.arn, "${aws_s3_bucket.access_logs.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }
  ] })
}
resource "aws_vpc_security_group_ingress_rule" "viewer" {
  for_each          = var.viewer_ipv4_cidrs
  security_group_id = var.platform.alb_security_group_id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS from an explicitly approved demo viewer network"
}
locals {
  service_ports  = { frontend = 80, backend = 8000 }
  service_groups = { frontend = var.platform.frontend_security_group_id, backend = var.platform.backend_security_group_id }
}
resource "aws_vpc_security_group_ingress_rule" "task" {
  #checkov:skip=CKV_AWS_260:Only referenced ALB security-group ingress is allowed; no CIDR is used on this private target rule.
  for_each                     = local.service_ports
  security_group_id            = local.service_groups[each.key]
  referenced_security_group_id = var.platform.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  description                  = "Application traffic from ALB only"
}
resource "aws_vpc_security_group_egress_rule" "alb" {
  for_each                     = local.service_ports
  security_group_id            = var.platform.alb_security_group_id
  referenced_security_group_id = local.service_groups[each.key]
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  description                  = "ALB to ${each.key} target only"
}
resource "aws_lb" "main" {
  name                       = local.name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.platform.alb_security_group_id]
  subnets                    = var.platform.public_subnet_ids
  enable_deletion_protection = var.load_balancer_deletion_protection
  drop_invalid_header_fields = true
  enable_http2               = true
  access_logs {
    bucket  = aws_s3_bucket.access_logs.id
    prefix  = "alb"
    enabled = true
  }
  depends_on = [aws_s3_bucket_policy.access_logs, aws_s3_bucket_public_access_block.access_logs]
}
resource "aws_lb_target_group" "service" {
  #checkov:skip=CKV_AWS_378:TLS terminates at the restricted HTTPS ALB; unchanged app images serve HTTP inside private subnets. End-to-end TLS is not claimed.
  for_each             = local.service_ports
  name_prefix          = "cc-${substr(each.key, 0, 2)}-"
  port                 = each.value
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.platform.vpc_id
  deregistration_delay = 30
  health_check {
    enabled             = true
    path                = each.key == "backend" ? "/ready" : "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  lifecycle { create_before_destroy = true }
}
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service["frontend"].arn
  }
}
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service["backend"].arn
  }
  condition {
    path_pattern { values = ["/api/*", "/health", "/ready", "/info"] }
  }
}
resource "aws_lb_listener_rule" "api_docs" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service["backend"].arn
  }
  condition {
    path_pattern { values = ["/docs*", "/openapi.json", "/metrics"] }
  }
}
output "load_balancer_dns_name" { value = aws_lb.main.dns_name }
output "application_url" { value = "https://${var.domain_name}" }

resource "aws_s3_bucket_notification" "access_logs" {
  bucket      = aws_s3_bucket.access_logs.id
  eventbridge = true
}
resource "aws_wafv2_ip_set" "viewers" {
  name               = "${local.name}-viewers"
  description        = "Approved demo viewer networks"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.viewer_ipv4_cidrs
}
resource "aws_wafv2_web_acl" "main" {
  name        = local.name
  description = "Managed web rules, rate limiting, and explicit demo viewer allowlist"
  scope       = "REGIONAL"
  default_action {
    block {}
  }
  rule {
    name     = "common-threats"
    priority = 0
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = false
      metric_name                = "${local.name}-common"
    }
  }
  rule {
    name     = "known-bad-inputs"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = false
      metric_name                = "${local.name}-bad-inputs"
    }
  }
  rule {
    name     = "anonymous-ip-threats"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = false
      metric_name                = "${local.name}-anonymous-ip"
    }
  }
  rule {
    name     = "limit-request-rate"
    priority = 10
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 200
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = false
      metric_name                = "${local.name}-rate"
    }
  }
  rule {
    name     = "approved-viewers"
    priority = 20
    action {
      allow {}
    }
    statement {
      ip_set_reference_statement { arn = aws_wafv2_ip_set.viewers.arn }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = false
      metric_name                = "${local.name}-viewers"
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = false
    metric_name                = local.name
  }
}
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${local.name}"
  retention_in_days = 365
  kms_key_id        = var.platform.kms_key_arn
}
resource "aws_cloudwatch_log_resource_policy" "waf" {
  policy_name     = "${local.name}-waf-delivery"
  policy_document = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "delivery.logs.amazonaws.com" }, Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.waf.arn}:*", Condition = { StringEquals = { "aws:SourceAccount" = var.aws_account_id }, ArnLike = { "aws:SourceArn" = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:*" } } }] })
}
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  redacted_fields {
    single_header { name = "authorization" }
  }
  redacted_fields {
    single_header { name = "cookie" }
  }
  redacted_fields {
    query_string {}
  }
  depends_on = [aws_cloudwatch_log_resource_policy.waf]
}
