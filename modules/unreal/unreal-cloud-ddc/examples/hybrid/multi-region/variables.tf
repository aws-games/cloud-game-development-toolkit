variable "route53_public_hosted_zone_name" {
  description = "The name of your existing Route53 Public Hosted Zone. This is required to create the ACM certificate and Route53 records."
  type        = string
  # No default - user must provide their own domain
  default     = "novekm.people.aws.dev"
}

variable "ghcr_credentials_secret_arn" {
  type        = string
  sensitive   = true
  description = "ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub"
  # No default - user must provide their own secret ARN
  default     = "arn:aws:secretsmanager:us-east-1:644937705968:secret:unreal-cloud-ddc-ghcr-token-TOLwVX"
}







