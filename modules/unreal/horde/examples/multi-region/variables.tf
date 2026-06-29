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

variable "enable_secondary_region" {
  type        = bool
  description = "Enable secondary region resources (Phase 2+)."
  default     = false
}

variable "enable_mrap" {
  type        = bool
  description = "Enable S3 Multi-Region Access Point (Phase 3+)."
  default     = false
}

variable "enable_agents" {
  type        = bool
  description = "Enable Horde build agents in primary region."
  default     = false
}
