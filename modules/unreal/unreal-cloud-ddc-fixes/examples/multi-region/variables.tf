variable "route53_public_hosted_zone_name" {
  description = "The name of your existing Route53 Public Hosted Zone. This is required to create the ACM certificate and Route53 records."
  type        = string
  default     = "novekm.people.aws.dev"
}

variable "ghcr_credentials_secret_manager_arn" {
  type        = string
  sensitive   = true
  description = "ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub"
}

variable "primary_ddc_url" {
  description = "URL of the primary region's DDC service for replication"
  type        = string
  default     = null
}

variable "primary_scylla_seed_ip" {
  description = "IP address of the primary region's ScyllaDB seed node"
  type        = string
  default     = null
}





