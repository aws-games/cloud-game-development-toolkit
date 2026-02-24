########################################
# General
########################################
variable "name" {
  type        = string
  description = "The name attached to P4 Code Review module resources."
  default     = "p4-code-review"

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

variable "fully_qualified_domain_name" {
  type        = string
  description = "The fully qualified domain name that P4 Code Review should use for internal URLs."
  default     = null
}

variable "debug" {
  type        = bool
  default     = false
  description = "Debug flag to enable execute command on service for container access."
}


########################################
# Compute
########################################
variable "cluster_name" {
  type        = string
  description = "The name of the cluster to deploy the P4 Code Review service into. Defaults to null and a cluster will be created."
  default     = null
}

variable "container_name" {
  type        = string
  description = "The name of the P4 Code Review container."
  default     = "p4-code-review-container"
  nullable    = false
}

variable "container_port" {
  type        = number
  description = "The container port that P4 Code Review runs on."
  default     = 80
  nullable    = false
}

variable "container_cpu" {
  type        = number
  description = "The CPU allotment for the P4 Code Review container."
  default     = 1024
  nullable    = false
}

variable "container_memory" {
  type        = number
  description = "The memory allotment for the P4 Code Review container."
  default     = 2048
}

variable "p4d_port" {
  type        = string
  description = "The P4D_PORT environment variable where P4 Code Review should look for P4 Code Review. Defaults to 'ssl:perforce:1666'"
  default     = "ssl:perforce:1666"
}

variable "p4charset" {
  type        = string
  description = "The P4CHARSET environment variable to set in the P4 Code Review container."
  default     = "none"
}

variable "existing_redis_connection" {
  type = object({
    host = string
    port = number
  })
  description = "The connection specifications to use for an existing Redis deployment."
  default     = null
}

########################################
# Storage & Logging
########################################
variable "enable_alb_access_logs" {
  type        = bool
  description = "Enables access logging for the P4 Code Review ALB. Defaults to false."
  default     = false
}

variable "alb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for P4 Code Review ALB access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
}

variable "alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for P4 Code Review ALB access logs. If null the project prefix and module name are used."
  default     = null
}

variable "s3_enable_force_destroy" {
  type        = bool
  description = "Enables force destroy for the S3 bucket for P4 Code Review access log storage. Defaults to true."
  default     = true
}
variable "cloudwatch_log_retention_in_days" {
  type        = string
  description = "The log retention in days of the cloudwatch log group for P4 Code Review."
  default     = 365
}


########################################
# Networking & Security
########################################

variable "vpc_id" {
  type        = string
  description = "The ID of the existing VPC you would like to deploy P4 Code Review into."
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
  description = "A list of subnets to deploy the P4 Code Review ECS Service into. Private subnets are recommended."
}

variable "create_application_load_balancer" {
  type        = bool
  default     = true
  description = "This flag controls the creation of an application load balancer as part of the module."
}

variable "application_load_balancer_name" {
  type        = string
  description = "The name of the P4 Code Review ALB. Defaults to the project prefix and module name."
  default     = null
}

variable "enable_alb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the P4 Code Review ALB. Defaults to true."
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
  description = "A list of existing security group IDs to attach to the P4 Code Review load balancer."
  default     = []
}

variable "internal" {
  type        = bool
  description = "Set this flag to true if you do not want the P4 Code Review service load balancer to have a public IP."
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "The TLS certificate ARN for the P4 Code Review service load balancer."
  default     = null
  validation {
    condition     = var.create_application_load_balancer == (var.certificate_arn != null)
    error_message = "The certificate_arn variable must be set if and only if the create_application_load_balancer variable is set."
  }
}

variable "create_default_role" {
  type        = bool
  description = "Optional creation of P4 Code Review Default IAM Role. Default is set to true."
  default     = true
}

variable "custom_role" {
  type        = string
  description = "ARN of the custom IAM Role you wish to use with P4 Code Review."
  default     = null
}

variable "super_user_username_secret_arn" {
  type        = string
  description = "Optionally provide the ARN of an AWS Secret for the p4d super user username."
}

variable "super_user_password_secret_arn" {
  type        = string
  description = "Optionally provide the ARN of an AWS Secret for the p4d super user password."
}

variable "p4_code_review_user_username_secret_arn" {
  type        = string
  description = "Optionally provide the ARN of an AWS Secret for the p4d P4 Code Review username."
}

variable "p4_code_review_user_password_secret_arn" {
  type        = string
  description = "Optionally provide the ARN of an AWS Secret for the p4d P4 Code Review password."
}

variable "config_php_source" {
  type        = string
  description = "Used as the ValueFrom for P4CR's config.php. Contents should be base64 encoded, and will be combined with the generated config.php via array_replace_recursive."
  default     = null
}

variable "enable_sso" {
  type        = bool
  default     = false
  description = "Set this to true if using SSO for P4 Code Review authentication."
}

######################
# Caching
######################

variable "elasticache_node_count" {
  type        = number
  description = "Number of cache nodes to provision in the Elasticache cluster."
  default     = 1
  validation {
    condition     = var.elasticache_node_count > 0
    error_message = "The defined 'elasticache_node_count' must be greater than 0."
  }
}

variable "elasticache_node_type" {
  type        = string
  description = "The type of nodes provisioned in the Elasticache cluster."
  default     = "cache.t4g.micro"
}


variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "terraform-aws-perforce"
    "ModuleName"     = "p4-code-review"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce"
  }
}
