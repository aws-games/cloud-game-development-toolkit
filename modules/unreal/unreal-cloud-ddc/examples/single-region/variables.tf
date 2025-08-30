variable "route53_public_hosted_zone_name" {
  description = "The name of your existing Route53 Public Hosted Zone. This is required to create the ACM certificate and Route53 records."
  type        = string
}

variable "ghcr_credentials_secret_manager_arn" {
  description = "ARN of the GitHub Container Registry credentials secret in AWS Secrets Manager"
  type        = string
}