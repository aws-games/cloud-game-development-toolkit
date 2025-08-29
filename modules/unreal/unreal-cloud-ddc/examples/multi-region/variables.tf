variable "github_credential_arn_region_1" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN for primary region"
}

variable "github_credential_arn_region_2" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN for secondary region"
}

variable "route53_public_hosted_zone_name" {
  type        = string
  description = "The root domain name for the Hosted Zone where the ScyllaDB monitoring record should be created."
}

