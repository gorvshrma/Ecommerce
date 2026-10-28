variable "availability_zones" {
  description = "Two distinct AZs in the approved region, for example ap-south-1a and ap-south-1b."
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2 && alltrue([for az in var.availability_zones : startswith(az, var.aws_region)])
    error_message = "Supply exactly two different AZs in aws_region."
  }
}
variable "vpc_cidr" {
  type        = string
  description = "Private address range, checked for overlap before deployment."
  default     = "10.40.0.0/16"
  validation {
    condition     = can(cidrsubnet(var.vpc_cidr, 8, 21))
    error_message = "Supply an IPv4 CIDR large enough for the subnet layout."
  }
}
locals { zones = { for i, az in var.availability_zones : az => i } }
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.name }
}
resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id }
resource "aws_subnet" "public" {
  for_each                = local.zones
  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-public-${each.key}" }
}
resource "aws_subnet" "application" {
  for_each                = local.zones
  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 10)
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-app-${each.key}" }
}
resource "aws_subnet" "database" {
  for_each                = local.zones
  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 20)
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-db-${each.key}" }
}
resource "aws_route_table" "public" { vpc_id = aws_vpc.main.id }
resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}
resource "aws_route_table" "application" { vpc_id = aws_vpc.main.id }
resource "aws_route_table" "database" { vpc_id = aws_vpc.main.id }
resource "aws_route_table_association" "public" {
  for_each       = local.zones
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "application" {
  for_each       = local.zones
  subnet_id      = aws_subnet.application[each.key].id
  route_table_id = aws_route_table.application.id
}
resource "aws_route_table_association" "database" {
  for_each       = local.zones
  subnet_id      = aws_subnet.database[each.key].id
  route_table_id = aws_route_table.database.id
}
resource "aws_security_group" "service" {
  #checkov:skip=CKV2_AWS_5:ALB/frontend/backend groups are attached by the separate application state; cross-state IDs cannot be traced by the scanner.
  for_each    = toset(["alb", "frontend", "backend"])
  name_prefix = "${local.name}-${each.key}-"
  description = "CloudCart ${each.key}; only explicit service rules are allowed"
  vpc_id      = aws_vpc.main.id
  lifecycle { create_before_destroy = true }
}
resource "aws_vpc_security_group_ingress_rule" "database" {
  security_group_id            = aws_security_group.internal["database"].id
  referenced_security_group_id = aws_security_group.service["backend"].id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from backend only"
}
resource "aws_vpc_security_group_egress_rule" "database" {
  security_group_id            = aws_security_group.service["backend"].id
  referenced_security_group_id = aws_security_group.internal["database"].id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "Backend to private PostgreSQL"
}
resource "aws_vpc_security_group_ingress_rule" "endpoint" {
  for_each                     = toset(["frontend", "backend"])
  security_group_id            = aws_security_group.internal["endpoints"].id
  referenced_security_group_id = aws_security_group.service[each.key].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "AWS private endpoint access from ${each.key}"
}
resource "aws_vpc_security_group_egress_rule" "endpoint" {
  for_each                     = toset(["frontend", "backend"])
  security_group_id            = aws_security_group.service[each.key].id
  referenced_security_group_id = aws_security_group.internal["endpoints"].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS to approved private endpoints"
}
locals {
  ecr_endpoint_policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Principal = "*", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Effect = "Allow", Principal = "*", Action = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"], Resource = [for repository in aws_ecr_repository.application : repository.arn] }
  ] })
  endpoint_policies = {
    "ecr.api"      = local.ecr_endpoint_policy
    "ecr.dkr"      = local.ecr_endpoint_policy
    logs           = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = "*", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/cloudcart/${var.environment}/*" }] })
    secretsmanager = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = "*", Action = ["secretsmanager:GetSecretValue"], Resource = aws_secretsmanager_secret.database_url.arn }] })
  }
}
resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(["ecr.api", "ecr.dkr", "logs", "secretsmanager"])
  vpc_id              = aws_vpc.main.id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  private_dns_enabled = true
  policy              = local.endpoint_policies[each.key]
  subnet_ids          = [for subnet in aws_subnet.application : subnet.id]
  security_group_ids  = [aws_security_group.internal["endpoints"].id]
}
resource "aws_vpc_endpoint" "s3" {
  policy            = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = "*", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::prod-${var.aws_region}-starport-layer-bucket/*" }] })
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.application.id]
}
resource "aws_vpc_security_group_egress_rule" "s3" {
  for_each          = toset(["frontend", "backend"])
  security_group_id = aws_security_group.service[each.key].id
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "ECR image layers from the regional S3 gateway endpoint"
}

resource "aws_security_group" "internal" {
  for_each    = toset(["database", "endpoints"])
  name_prefix = "${local.name}-${each.key}-"
  description = "Private ${each.key} connections only"
  vpc_id      = aws_vpc.main.id
  lifecycle { create_before_destroy = true }
}
resource "aws_default_security_group" "deny_all" {
  vpc_id = aws_vpc.main.id
  # No ingress or egress rules: nothing in this stack uses the default group.
}

variable "database_admin_security_group_id" {
  description = "Existing approved private admin path (for example SSM/VPN workstation SG). No public DB/SSH access is created."
  type        = string
  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.database_admin_security_group_id))
    error_message = "Supply the security group of an approved private database administration path."
  }
}
resource "aws_vpc_security_group_ingress_rule" "database_admin" {
  security_group_id            = aws_security_group.internal["database"].id
  referenced_security_group_id = var.database_admin_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "Database setup and recovery from the approved private admin path only"
}
