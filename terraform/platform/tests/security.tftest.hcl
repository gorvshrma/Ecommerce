mock_provider "aws" {
  mock_resource "aws_db_instance" {
    defaults = {
      master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:mock-admin", kms_key_id = "mock", secret_status = "active" }]
    }
  }
}
variables {
  aws_region                       = "us-east-1"
  aws_account_id                   = "123456789012"
  owner                            = "offline-test"
  deployment_approved              = true
  availability_zones               = ["us-east-1a", "us-east-1b"]
  database_engine_version          = "16.4"
  database_instance_class          = "db.t4g.small"
  database_admin_security_group_id = "sg-00000000000000004"
}
run "private_retained_platform" {
  command = plan
  assert {
    condition     = !aws_db_instance.main.publicly_accessible && aws_db_instance.main.storage_encrypted && aws_db_instance.main.manage_master_user_password
    error_message = "The database must remain private, encrypted, and use an AWS-managed admin password."
  }
  assert {
    condition     = aws_db_instance.main.deletion_protection && !aws_db_instance.main.skip_final_snapshot && aws_db_instance.main.backup_retention_period >= 7 && aws_db_instance.main.multi_az
    error_message = "Retain database recovery protections and the production-like Multi-AZ default."
  }
  assert {
    condition     = alltrue([for subnet in aws_subnet.application : !subnet.map_public_ip_on_launch]) && alltrue([for subnet in aws_subnet.database : !subnet.map_public_ip_on_launch])
    error_message = "App and database subnets must not assign public IPs."
  }
  assert {
    condition     = length(aws_vpc_endpoint.interface) == 4 && aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "Keep private AWS access without an implicit NAT gateway."
  }
  assert {
    condition     = alltrue([for repo in aws_ecr_repository.application : repo.image_tag_mutability == "IMMUTABLE" && repo.image_scanning_configuration[0].scan_on_push])
    error_message = "Images must be immutable and scanned on push."
  }
}
run "reject_single_az_layout" {
  command = plan
  variables { availability_zones = ["us-east-1a", "us-east-1a"] }
  expect_failures = [var.availability_zones]
}
