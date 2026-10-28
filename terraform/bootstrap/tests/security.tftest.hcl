# Provider is mocked: these tests NEVER contact AWS or create resources.
mock_provider "aws" {}
variables {
  aws_region          = "us-east-1"
  aws_account_id      = "123456789012"
  owner               = "offline-test"
  deployment_approved = true
}

run "state_protection" {
  command = plan
  variables { state_bucket_name = "cloudcart-offline-test-state" }
  assert {
    condition     = aws_s3_bucket.state.force_destroy == false
    error_message = "State storage must not be force-destroyed."
  }
  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "State version recovery must be enabled."
  }
  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "State requires KMS encryption."
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.state.block_public_policy && aws_s3_bucket_public_access_block.state.block_public_acls && aws_s3_bucket_public_access_block.state.ignore_public_acls && aws_s3_bucket_public_access_block.state.restrict_public_buckets
    error_message = "State public access must be fully blocked."
  }
  assert {
    condition     = aws_kms_key.state.enable_key_rotation
    error_message = "State encryption key rotation must remain enabled."
  }
}
run "deny_unapproved_deployment" {
  command = plan
  variables {
    deployment_approved = false
    state_bucket_name   = "cloudcart-offline-test-state"
  }
  expect_failures = [terraform_data.approval]
}
