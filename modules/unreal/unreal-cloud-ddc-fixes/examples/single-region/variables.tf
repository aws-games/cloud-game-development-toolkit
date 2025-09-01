variable "route53_public_hosted_zone_name" {
  type        = string
  description = "The root domain name for the Hosted Zone where the DDC and monitoring records should be created."
  default     = "novekm.people.aws.dev"
}

variable "ghcr_credentials_secret_manager_arn" {
  type        = string
  sensitive   = true
  description = "ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub"
  default     = "arn:aws:secretsmanager:us-east-1:644937705968:secret:ecr-pullthroughcache/UnrealCloudDDC-XLISDD"
}

variable "regions" {
  type        = list(string)
  description = "List of AWS regions for DDC deployment. Determines single vs multi-region configuration."
  default     = ["us-east-1"]

  validation {
    condition     = length(var.regions) >= 1 && length(var.regions) <= 2
    error_message = "Currently only 1-2 regions supported. Provide 1 region for single-region deployment or 2 regions for multi-region deployment."
  }

  validation {
    condition     = length(var.regions) == length(distinct(var.regions))
    error_message = "All regions must be unique."
  }

  validation {
    condition     = length(var.regions) <= 1 || length(distinct([for r in var.regions : regex("^([^-]+-[^-]+)", r)[0]])) == length(var.regions)
    error_message = "Multi-region deployments must use different region families (e.g., us-east-1 + us-west-2, not us-east-1 + us-east-2) for meaningful latency benefits and to avoid ScyllaDB datacenter name collisions."
  }
}
