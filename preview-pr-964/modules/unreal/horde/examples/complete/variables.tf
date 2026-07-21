variable "root_domain_name" {
  type        = string
  description = "The root domain name for the Hosted Zone where the Horde record should be created."
}

variable "github_credentials_secret_arn" {
  type        = string
  description = "The ARN of the Github credentials secret that should be used for pulling the Unreal Horde container from the Epic Games Github organization."
}

variable "p4_port" {
  type        = string
  description = "The Perforce server Horde should connect to (e.g. \"ssl:perforce.example.com:1666\"). Leave null to deploy Horde without Perforce integration."
  default     = null
}

variable "p4_credentials_secret_arn" {
  type        = string
  description = "The ARN of an AWS Secrets Manager secret containing {\"username\": \"...\", \"password\": \"...\"} for the Perforce user Horde connects as. Required when p4_port is set."
  default     = null
}
