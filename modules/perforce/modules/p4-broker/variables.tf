########################################
# General
########################################
variable "name" {
  type        = string
  description = "The name attached to P4 Broker module resources."
  default     = "p4-broker"

  validation {
    condition     = length(var.name) > 1 && length(var.name) <= 50
    error_message = "The defined 'name' has too many characters (${length(var.name)}). This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appended to the beginning of most resource names."
  default     = "cgd"
}

variable "debug" {
  type        = bool
  description = "Set this flag to enable execute command on service containers and force redeploys."
  default     = false
}


########################################
# Compute
########################################
variable "cluster_name" {
  type        = string
  description = "The name of the ECS cluster to deploy the P4 Broker into. Cluster is not created if this variable is provided."
  default     = null
}

variable "container_name" {
  type        = string
  description = "The name of the P4 Broker container."
  default     = "p4-broker-container"
  nullable    = false
}

variable "container_port" {
  type        = number
  description = "The container port that P4 Broker listens on."
  default     = 1666
  nullable    = false
}

variable "container_cpu" {
  type        = number
  description = "The CPU allotment for the P4 Broker container."
  default     = 1024
  nullable    = false
}

variable "container_memory" {
  type        = number
  description = "The memory allotment for the P4 Broker container."
  default     = 2048
  nullable    = false
}

variable "container_image" {
  type        = string
  description = "The Docker image URI for the P4 Broker container."
}

variable "desired_count" {
  type        = number
  description = "The desired number of P4 Broker ECS tasks."
  default     = 1
}


########################################
# Broker Configuration
########################################
variable "p4_target" {
  type        = string
  description = "The upstream Perforce server target (e.g., ssl:p4server:1666)."
}

variable "broker_command_rules" {
  type = list(object({
    command = string
    action  = string
    message = optional(string, null)
  }))
  description = "Command filtering rules for the P4 Broker configuration."
  default = [{
    command = "*"
    action  = "pass"
    message = null
  }]
}

variable "extra_env" {
  type        = map(string)
  description = "Extra environment variables to set on the P4 Broker container."
  default     = null
}


########################################
# Storage & Logging
########################################
variable "cloudwatch_log_retention_in_days" {
  type        = number
  description = "The log retention in days of the CloudWatch log group for P4 Broker."
  default     = 365
}


########################################
# Networking & Security
########################################
variable "vpc_id" {
  type        = string
  description = "The ID of the existing VPC you would like to deploy P4 Broker into."
}

variable "subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the P4 Broker ECS Service into. Private subnets are recommended."
}

variable "create_default_role" {
  type        = bool
  description = "Optional creation of P4 Broker default IAM Role. Default is set to true."
  default     = true
}

variable "custom_role" {
  type        = string
  description = "ARN of the custom IAM Role you wish to use with P4 Broker."
  default     = null
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "terraform-aws-perforce"
    "ModuleName"     = "p4-broker"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce"
  }
}
