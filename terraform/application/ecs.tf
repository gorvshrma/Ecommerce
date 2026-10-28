resource "aws_ecs_cluster" "main" {
  name = local.name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_cloudwatch_log_group" "service" {
  for_each          = local.service_ports
  name              = "/cloudcart/${var.environment}/${each.key}"
  retention_in_days = 365
  kms_key_id        = var.platform.kms_key_arn
}
locals {
  task_trust = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole", Condition = { StringEquals = { "aws:SourceAccount" = var.aws_account_id }, ArnLike = { "aws:SourceArn" = "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:*" } } }] })
}
resource "aws_iam_role" "execution" {
  for_each           = local.service_ports
  name               = "${local.name}-${each.key}-execution"
  assume_role_policy = local.task_trust
}
resource "aws_iam_role" "task" {
  for_each           = local.service_ports
  name               = "${local.name}-${each.key}-task"
  description        = "Application identity; intentionally no AWS permissions"
  assume_role_policy = local.task_trust
}
resource "aws_iam_role_policy" "execution" {
  for_each = local.service_ports
  role     = aws_iam_role.execution[each.key].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "ECRLogin", Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Sid = "PullOwnImage", Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"], Resource = each.key == "frontend" ? var.platform.frontend_repository_arn : var.platform.backend_repository_arn },
    { Sid = "WriteOwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.service[each.key].arn}:*" }
  ] })
}
resource "aws_ecs_task_definition" "service" {
  for_each                 = local.service_ports
  family                   = "${local.name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution[each.key].arn
  task_role_arn            = aws_iam_role.task[each.key].arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  dynamic "volume" {
    for_each = each.key == "frontend" ? toset(["nginx-cache", "nginx-run"]) : toset([])
    content { name = volume.value }
  }
  container_definitions = jsonencode([merge({
    name                   = each.key
    image                  = each.key == "frontend" ? var.images.frontend : var.images.backend
    essential              = true
    readonlyRootFilesystem = true
    portMappings           = [{ containerPort = each.value, protocol = "tcp" }]
    logConfiguration       = { logDriver = "awslogs", options = { awslogs-group = aws_cloudwatch_log_group.service[each.key].name, awslogs-region = var.aws_region, awslogs-stream-prefix = each.key } }
    healthCheck            = { command = each.key == "backend" ? ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"] : ["CMD-SHELL", "wget -qO- http://127.0.0.1/ >/dev/null || exit 1"], interval = 30, timeout = 5, retries = 3, startPeriod = 30 }
    linuxParameters        = { capabilities = { drop = ["ALL"] }, initProcessEnabled = true }
  }, local.container_settings[each.key])])
}
resource "aws_ecs_service" "service" {
  for_each                           = local.service_ports
  name                               = each.key
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.service[each.key].arn
  desired_count                      = each.key == "backend" ? 1 : 2
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  enable_execute_command             = false
  health_check_grace_period_seconds  = 90
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  wait_for_steady_state              = true
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets          = var.platform.application_subnet_ids
    security_groups  = [local.service_groups[each.key]]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.service[each.key].arn
    container_name   = each.key
    container_port   = each.value
  }
  depends_on = [aws_lb_listener.https, aws_lb_listener_rule.api, aws_lb_listener_rule.api_docs, aws_wafv2_web_acl_association.main, aws_iam_role_policy.execution, aws_iam_role_policy.backend_secret, terraform_data.runtime_gate, terraform_data.approval]
}

locals {
  container_settings = {
    backend = {
      user        = "appuser"
      environment = [for key, value in { APP_NAME = "CloudCart API", APP_VERSION = "1.0.0", ENVIRONMENT = var.environment, CORS_ORIGINS = "https://${var.domain_name}", GIT_COMMIT = var.git_commit } : { name = key, value = value }]
      secrets     = [{ name = "DATABASE_URL", valueFrom = var.platform.database_url_secret_arn }]
    }
    frontend = {
      # Existing Nginx image needs a root master and writable runtime directories.
      # Task networking and filesystem are restricted; this is not claimed rootless.
      user            = "0"
      mountPoints     = [{ sourceVolume = "nginx-cache", containerPath = "/var/cache/nginx", readOnly = false }, { sourceVolume = "nginx-run", containerPath = "/var/run", readOnly = false }]
      linuxParameters = { capabilities = { drop = ["AUDIT_WRITE", "DAC_OVERRIDE", "FOWNER", "FSETID", "KILL", "MKNOD", "NET_RAW", "SETFCAP", "SETPCAP", "SYS_CHROOT"] }, initProcessEnabled = true }

    }
  }
}

resource "aws_iam_role_policy" "backend_secret" {
  role = aws_iam_role.execution["backend"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "ReadAppConnection", Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = var.platform.database_url_secret_arn },
    { Sid = "DecryptAppConnection", Effect = "Allow", Action = ["kms:Decrypt"], Resource = var.platform.kms_key_arn, Condition = { StringEquals = { "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com" }, StringLike = { "kms:EncryptionContext:SecretARN" = var.platform.database_url_secret_arn } } }
  ] })
}
