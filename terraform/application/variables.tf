variable "aws_region" {
  description = "Approved AWS region. No deployment region is assumed."
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "Supply an AWS commercial region such as ap-south-1."
  }
}
variable "aws_account_id" {
  description = "The approved 12-digit target account; provider operations are restricted to it."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Supply the approved 12-digit AWS account ID."
  }
}
variable "environment" {
  description = "Separate state and resources for dev, staging, or prod."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Use dev, staging, or prod."
  }
}
variable "owner" {
  description = "Person or team responsible for costs and teardown; not a credential."
  type        = string
  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "Name an owner."
  }
}
variable "deployment_approved" {
  description = "Set true only after explicit approval of account, region, budget, and plan."
  type        = bool
  default     = false
}
resource "terraform_data" "approval" {
  lifecycle {
    precondition {
      condition     = var.deployment_approved
      error_message = "Resource creation is not approved. Review account, region, costs, and plan first."
    }
  }
}
