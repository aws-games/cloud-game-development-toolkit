variable "primary_scylla_seed_ip" {
  description = "IP address of the primary region's ScyllaDB seed node"
  type        = string
  default     = null
}

variable "primary_ddc_url" {
  description = "URL of the primary region's DDC service for replication"
  type        = string
  default     = null
}

variable "route53_public_hosted_zone_name" {
  description = "The name of your existing Route53 Public Hosted Zone. This is required to create the ACM certificate and Route53 records."
  type        = string
}

variable "ghcr_credentials_secret_manager_arn" {
  description = "ARN of the GitHub Container Registry credentials secret in AWS Secrets Manager"
  type        = string
}

variable "primary_scylla_seed_ip" {
  description = "IP address of the primary region ScyllaDB seed node (for secondary regions)"
  type        = string
  default     = null
}

variable "primary_ddc_url" {
  description = "URL of the primary region DDC service (for secondary regions)"
  type        = string
  default     = null
}

