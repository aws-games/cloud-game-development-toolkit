########################################
# General
########################################
variable "name" {
  type        = string
  description = "The name attached to P4Auth module resources."
  default     = "p4-auth"

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

variable "enable_web_based_administration" {
  type        = bool
  description = "Flag for enabling web based administration of P4Auth."
  default     = false
}

variable "fully_qualified_domain_name" {
  type        = string
  description = "The fully qualified domain name where P4Auth will be available."
  default     = null
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
  description = "The name of the ECS cluster to deploy the P4Auth into. Cluster is not created if this variable is null."
  default     = null
}

variable "container_name" {
  type        = string
  description = "The name of the P4Auth container."
  default     = "p4-auth-container"
  nullable    = false
}

variable "container_port" {
  type        = number
  description = "The container port that P4Auth runs on."
  default     = 3000
  nullable    = false
}

variable "container_cpu" {
  type        = number
  description = "The CPU allotment for the P4Auth container."
  default     = 1024
  nullable    = false
}

variable "container_memory" {
  type        = number
  description = "The memory allotment for the P4Auth container."
  default     = 4096
  nullable    = false
}


########################################
# Storage & Logging
########################################
variable "enable_alb_access_logs" {
  type        = bool
  description = "Enables access logging for the P4Auth ALB. Defaults to false."
  default     = false
}

variable "alb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for P4Auth ALB access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
}

variable "alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for P4Auth ALB access logs. If null the project prefix and module name are used."
  default     = null
}

variable "s3_enable_force_destroy" {
  type        = bool
  description = "Enables force destroy for the S3 bucket for P4Auth access log storage. Defaults to true."
  default     = true
}
variable "cloudwatch_log_retention_in_days" {
  type        = string
  description = "The log retention in days of the cloudwatch log group for P4Auth."
  default     = 365
}


########################################
# Networking & Security
########################################
variable "vpc_id" {
  type        = string
  description = "The ID of the existing VPC you would like to deploy P4Auth into."
}

variable "alb_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the load balancer into. Public subnets are recommended."
  default     = []
  validation {
    condition     = (length(var.alb_subnets) > 0) == var.create_application_load_balancer
    error_message = "ALB subnets are only necessary if the create_application_load_balancer variable is set."
  }
}

variable "subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the P4Auth ECS Service into. Private subnets are recommended."
}

variable "create_application_load_balancer" {
  type        = bool
  default     = true
  description = "This flag controls the creation of an application load balancer as part of the module."
}

variable "application_load_balancer_name" {
  type        = string
  description = "The name of the P4Auth ALB. Defaults to the project prefix and module name."
  default     = null
}

variable "enable_alb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the P4Auth ALB. Defaults to true."
  default     = false
}

variable "deregistration_delay" {
  type        = number
  default     = 30
  description = "The amount of time to wait for in-flight requests to complete while deregistering a target. The range is 0-3600 seconds."
  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600
    error_message = "The deregistration delay must be in the range 0-3600."
  }
}

variable "existing_security_groups" {
  type        = list(string)
  description = "A list of existing security group IDs to attach to the P4Auth load balancer."
  default     = []
}

variable "internal" {
  type        = bool
  description = "Set this flag to true if you do not want the P4Auth load balancer to have a public IP."
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "The TLS certificate ARN for the P4Auth load balancer."
  default     = null
  validation {
    condition     = var.create_application_load_balancer == (var.certificate_arn != null)
    error_message = "The certificate_arn variable must be set if and only if the create_application_load_balancer variable is set."
  }
}

variable "create_default_role" {
  type        = bool
  description = "Optional creation of P4Auth default IAM Role. Default is set to true."
  default     = true
}

variable "custom_role" {
  type        = string
  description = "ARN of the custom IAM Role you wish to use with P4Auth."
  default     = null
}

variable "admin_username_secret_arn" {
  type        = string
  description = "Optionally provide the ARN of an AWS Secret for the P4Auth Administrator username."
  default     = null
}

variable "admin_password_secret_arn" {
  type        = string
  description = "Optionally provide the ARN of an AWS Secret for the P4Auth Administrator password."
  default     = null
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "terraform-aws-perforce"
    "ModuleName"     = "p4-auth"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce/terraform-aws-perforce"
  }
}

variable "p4d_port" {
  type        = string
  description = "The P4D_PORT environment variable where Helix Authentication Service should look for Helix Core. Required if you want to use SCIM to provision users and groups. Defaults to 'ssl:perforce:1666'"
  default     = "ssl:perforce:1666"
}

variable "p4d_super_user_arn" {
  type        = string
  description = "If you would like to use SCIM to provision users and groups, you need to set this variable to the ARN of an AWS Secrets Manager secret containing the super user username for p4d."
  default     = null
}

variable "p4d_super_user_password_arn" {
  type        = string
  description = "If you would like to use SCIM to provision users and groups, you need to set this variable to the ARN of an AWS Secrets Manager secret containing the super user password for p4d."
  default     = null
}

variable "scim_bearer_token_arn" {
  type        = string
  description = "If you would like to use SCIM to provision users and groups, you need to set this variable to the ARN of an AWS Secrets Manager secret containing the bearer token."
  default     = null

  validation {
    condition     = var.scim_bearer_token_arn == null || (var.p4d_super_user_arn != null && var.p4d_super_user_password_arn != null)
    error_message = "scim_bearer_token_arn is only useful if p4d_super_user_arn and p4d_super_user_password_arn are also set, did you mean to set all three?"
  }
}
