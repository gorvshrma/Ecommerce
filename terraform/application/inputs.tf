variable "platform" {
  description = "Non-secret platform outputs; copy from application_inputs, not a remote-state data source."
  type = object({
    vpc_id                     = string
    public_subnet_ids          = list(string)
    application_subnet_ids     = list(string)
    alb_security_group_id      = string
    frontend_security_group_id = string
    backend_security_group_id  = string
    kms_key_arn                = string
    database_url_secret_arn    = string
    frontend_repository_arn    = string
    backend_repository_arn     = string
  })
  validation {
    condition     = length(var.platform.public_subnet_ids) == 2 && length(var.platform.application_subnet_ids) == 2 && startswith(var.platform.kms_key_arn, "arn:aws:kms:${var.aws_region}:${var.aws_account_id}:") && startswith(var.platform.database_url_secret_arn, "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:")
    error_message = "Use two-AZ platform outputs from the same approved account and region."
  }
}
variable "domain_name" {
  description = "Approved HTTPS hostname; DNS must point to the ALB and certificate must cover this hostname."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+[.][a-z]{2,}$", var.domain_name))
    error_message = "Supply a valid DNS hostname, without protocol or path."
  }
}
variable "certificate_arn" {
  description = "Existing issued ACM certificate in the ALB region. This stack does not request a certificate or register a domain."
  type        = string
  validation {
    condition     = startswith(var.certificate_arn, "arn:aws:acm:${var.aws_region}:${var.aws_account_id}:certificate/")
    error_message = "Use an ACM certificate from the approved account and region."
  }
}
variable "viewer_ipv4_cidrs" {
  description = "Approved viewer networks only; no public unrestricted ingress because the app has unauthenticated writes."
  type        = set(string)
  validation {
    condition     = length(var.viewer_ipv4_cidrs) > 0 && alltrue([for cidr in var.viewer_ipv4_cidrs : can(cidrnetmask(cidr)) && try(tonumber(split("/", cidr)[1]) >= 24, false)])
    error_message = "Use at least one IPv4 CIDR from /24 to /32, ideally your approved /32. Never 0.0.0.0/0."
  }
}
variable "images" {
  description = "Existing scanned images pinned by digest. Frontend must be built for domain_name, backend must contain the RDS CA bundle."
  type        = object({ frontend = string, backend = string })
  validation {
    condition     = alltrue([for image in [var.images.frontend, var.images.backend] : startswith(image, "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/") && can(regex("@sha256:[a-f0-9]{64}$", image))])
    error_message = "Supply same-account ECR image references with immutable sha256 digests, not mutable tags."
  }
}
variable "deployment_inputs_verified" {
  description = "True only after app secret contains a restricted-user TLS DSN, backend has the CA bundle, frontend has the correct API URL, and certificate/DNS have been checked."
  type        = bool
  default     = false
}
variable "load_balancer_deletion_protection" {
  description = "Keep true normally; a reviewed teardown change may set false before destroying the runtime stack."
  type        = bool
  default     = true
}
resource "terraform_data" "runtime_gate" {
  lifecycle {
    precondition {
      condition     = var.deployment_inputs_verified
      error_message = "Verify secret contents, restricted DB user, CA bundle, frontend API URL, and certificate/DNS outside Terraform before runtime deployment."
    }
  }
}

variable "git_commit" {
  description = "Full source commit used to build both images, for the app /info endpoint."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.git_commit))
    error_message = "Supply the 40-character source Git commit, not an image tag."
  }
}
