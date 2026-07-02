variable "root_domain_name" {
  type        = string
  description = "The root domain name for the Hosted Zone."
  default     = "gabeaws.people.aws.dev"
}

variable "image" {
  type        = string
  description = "The Horde Server container image URI."
  default     = "968702293218.dkr.ecr.us-east-1.amazonaws.com/horde-server:poc-multi-region"
}

variable "primary_region" {
  type        = string
  description = "The primary AWS region for the Horde deployment."
  default     = "us-east-1"
}

variable "secondary_region" {
  type        = string
  description = "The secondary AWS region for cross-region agents and storage."
  default     = "eu-west-1"
}
