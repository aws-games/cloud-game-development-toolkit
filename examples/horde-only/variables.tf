variable "root_domain_name" {
  type        = string
  description = "The root domain name for the Hosted Zone where the Horde record should be created."
}

variable "github_credentials_secret_arn" {
  type        = string
  description = "The ARN of the Github credentials secret that should be used for pulling the Unreal Horde container from the Epic Games Github organization."
}
