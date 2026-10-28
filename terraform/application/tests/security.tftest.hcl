mock_provider "aws" {}
variables {
  aws_region                 = "us-east-1"
  aws_account_id             = "123456789012"
  owner                      = "offline-test"
  deployment_approved        = true
  git_commit                 = "cccccccccccccccccccccccccccccccccccccccc"
  domain_name                = "demo.example.com"
  certificate_arn            = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  viewer_ipv4_cidrs          = ["198.51.100.10/32"]
  deployment_inputs_verified = true
  images = {
    frontend = "123456789012.dkr.ecr.us-east-1.amazonaws.com/cloudcart-dev/frontend@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    backend  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/cloudcart-dev/backend@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  }
  platform = {
    vpc_id                     = "vpc-00000000000000001"
    public_subnet_ids          = ["subnet-00000000000000001", "subnet-00000000000000002"]
    application_subnet_ids     = ["subnet-00000000000000003", "subnet-00000000000000004"]
    alb_security_group_id      = "sg-00000000000000001"
    frontend_security_group_id = "sg-00000000000000002"
    backend_security_group_id  = "sg-00000000000000003"
    kms_key_arn                = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    database_url_secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:mock-connection"
    frontend_repository_arn    = "arn:aws:ecr:us-east-1:123456789012:repository/cloudcart-dev/frontend"
    backend_repository_arn     = "arn:aws:ecr:us-east-1:123456789012:repository/cloudcart-dev/backend"
  }
}
run "restricted_runtime" {
  command = plan
  assert {
    condition     = alltrue([for service in aws_ecs_service.service : !service.network_configuration[0].assign_public_ip && service.deployment_circuit_breaker[0].rollback])
    error_message = "Tasks must be private and failed deployments must roll back."
  }
  assert {
    condition     = alltrue([for task in aws_ecs_task_definition.service : jsondecode(task.container_definitions)[0].readonlyRootFilesystem])
    error_message = "Container root filesystems must stay read-only."
  }
  assert {
    condition     = aws_lb_listener.https.protocol == "HTTPS" && aws_lb_listener.https.port == 443 && aws_lb.main.enable_deletion_protection
    error_message = "Retain HTTPS and load-balancer deletion protection."
  }
  assert {
    condition     = jsondecode(aws_ecs_task_definition.service["backend"].container_definitions)[0].secrets[0].name == "DATABASE_URL"
    error_message = "Pass the database URL as a runtime secret, not a plain task environment value."
  }
}
run "reject_public_demo" {
  command = plan
  variables { viewer_ipv4_cidrs = ["0.0.0.0/0"] }
  expect_failures = [var.viewer_ipv4_cidrs]
}
run "reject_unverified_release" {
  command = plan
  variables { deployment_inputs_verified = false }
  expect_failures = [terraform_data.runtime_gate]
}

run "reject_mutable_image" {
  command = plan
  variables {
    images = {
      frontend = "123456789012.dkr.ecr.us-east-1.amazonaws.com/cloudcart-dev/frontend@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      backend  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/cloudcart-dev/backend:latest"
    }
  }
  expect_failures = [var.images]
}
