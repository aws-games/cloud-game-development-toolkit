variable "route53_public_hosted_zone_name" {
  description = "The name of your existing Route53 Public Hosted Zone. This is required to create the ACM certificate and Route53 records."
  type        = string
  # No default - users must provide their public hosted zone name
  default     = "novekm.people.aws.dev"
}

variable "ghcr_credentials_secret_arn" {
  type        = string
  sensitive   = true
  description = "ARN of the secret in AWS Secrets Manager containing GitHub credentials (username and accessToken fields) for Epic Games container registry access. You must create this secret in your AWS account."
  # No default - users must provide their own secret ARN
  default     = "arn:aws:secretsmanager:us-east-1:644937705968:secret:unreal-cloud-ddc-ghcr-token-TOLwVX"
}










