variable "route53_public_hosted_zone_name" {
  description = "The name of your existing Route53 Public Hosted Zone. This is required to create the ACM certificate and Route53 records."
  type        = string
  default     = "novekm.people.aws.dev"
}

variable "ghcr_credentials_secret_manager_arn" {
  description = "ARN of the GitHub Container Registry credentials secret in AWS Secrets Manager"
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:644937705968:secret:ecr-pullthroughcache/-XBalRp" # TODO - remove
}
