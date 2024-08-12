########################################
# GENERAL CONFIGURATION
########################################
variable "name" {
  type        = string
  description = "The name attached to Unreal Engine Horde module resources."
  default     = "unreal-horde"

  validation {
    condition     = length(var.name) > 1 && length(var.name) <= 50
    error_message = "The defined 'name' has too many characters (${length(var.name)}). This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appeneded to the beginning of most resource names."
  default     = "cgd"

}

variable "environment" {
  type        = string
  description = "The current environment (e.g. dev, prod, etc.)"
  default     = "dev"
}

variable "tags" {
  type = map(any)
  default = {
    "IAC_MANAGEMENT" = "CGD-Toolkit"
    "IAC_MODULE"     = "unreal-horde"
    "IAC_PROVIDER"   = "Terraform"
  }
  description = "Tags to apply to resources."
}

########################################
# NETWORKING
########################################

variable "vpc_id" {
  type        = string
  description = "The ID of the existing VPC you would like to deploy Unreal Horde into."
}

########################################
# ECS
########################################

variable "cluster_name" {
  type        = string
  description = "The name of the cluster to deploy the Unreal Horde into. Defaults to null and a cluster will be created."
  default     = null
}

# - Container Specs -

variable "container_name" {
  type        = string
  description = "The name of the Unreal Horde container."
  default     = "unreal-horde-container"
  nullable    = false
}

variable "container_port" {
  type        = number
  description = "The container port that Unreal Horde runs on."
  default     = 5000
  nullable    = false
}

variable "container_cpu" {
  type        = number
  description = "The CPU allotment for the Unreal Horde container."
  default     = 1024
  nullable    = false
}

variable "container_memory" {
  type        = number
  description = "The memory allotment for the Unreal Horde container."
  default     = 4096
  nullable    = false
}

variable "desired_container_count" {
  type        = number
  description = "The desired number of containers running Unreal Horde."
  default     = 1
  nullable    = false
}

# - Load Balancer -
variable "unreal_horde_alb_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the Unreal Horde load balancer into. Public subnets are recommended."
}

variable "enable_unreal_horde_alb_access_logs" {
  type        = bool
  description = "Enables access logging for the Unreal Horde ALB. Defaults to true."
  default     = true
}

variable "unreal_horde_alb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for Unreal Horde ALB access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
}

variable "unreal_horde_alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for Unreal Horde ALB access logs. If null the project prefix and module name are used."
  default     = null
}

variable "enable_unreal_horde_alb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the Unreal Horde ALB. Defaults to true."
  default     = true
}

variable "unreal_horde_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the Unreal Horde into. Private subnets are recommended."
}

variable "existing_security_groups" {
  type        = list(string)
  description = "A list of existing security group IDs to attach to the Unreal Horde load balancer."
  default     = []
}

variable "internal" {
  type        = bool
  description = "Set this flag to true if you do not want the Unreal Horde load balancer to have a public IP."
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "The TLS certificate ARN for the Unreal Horde load balancer."
}

# - Logging -
variable "unreal_horde_cloudwatch_log_retention_in_days" {
  type        = string
  description = "The log retention in days of the cloudwatch log group for Unreal Horde."
  default     = 365
}

# - Security and Permissions -
variable "custom_unreal_horde_role" {
  type        = string
  description = "ARN of the custom IAM Role you wish to use with Unreal Horde."
  default     = null
}

variable "create_unreal_horde_default_role" {
  type        = bool
  description = "Optional creation of Unreal Horde default IAM Role. Default is set to true."
  default     = true
}

variable "create_unreal_horde_default_policy" {
  type        = bool
  description = "Optional creation of Unreal Horde default IAM Policy. Default is set to true."
  default     = true
}

variable "github_credentials_secret_arn" {
  type        = string
  description = "A secret containing the Github username and password with permissions to the EpicGames organization."
}
