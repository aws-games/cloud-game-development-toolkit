variable "github_credential_arn" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN"
  default     = "arn:aws:secretsmanager:us-east-1:644937705968:secret:ecr-pullthroughcache/-XBalRp"
}

variable "route53_public_hosted_zone_name" {
  type        = string
  description = "The root domain name for the Hosted Zone where the ScyllaDB monitoring record should be created."
  default     = "novekm.people.aws.dev"
}
