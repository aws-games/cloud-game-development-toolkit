########################################
# GENERAL CONFIGURATION
########################################
variable "name" {
  type        = string
  description = "The name attached to swarm module resources."
  default     = "swarm"

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
    "iac-management" = "CGD-Toolkit"
    "iac-module"     = "swarm"
    "iac-provider"   = "Terraform"
  }
  description = "Tags to apply to resources."
}

variable "vpc_id" {
  type        = string
  description = "The ID of the existing VPC you would like to deploy swarm into."
}

########################################
# ECS CONFIGURATION
########################################

variable "helix_swarm_container_name" {
  type        = string
  description = "The name of the swarm container."
  default     = "helix-swarm-container"
  nullable    = false
}

variable "helix_swarm_container_port" {
  type        = number
  description = "The container port that swarm runs on."
  default     = 80
  nullable    = false
}

variable "helix_swarm_container_cpu" {
  type        = number
  description = "The CPU allotment for the swarm container."
  default     = 1024
  nullable    = false
}

variable "helix_swarm_container_memory" {
  type        = number
  description = "The memory allotment for the swarm container."
  default     = 2048
}

variable "p4d_port" {
  type        = string
  description = "The P4D_PORT environment variable where Swarm should look for Helix Core. Defaults to 'ssl:perforce:1666'"
  default     = "ssl:perforce:1666"
}

variable "fully_qualified_domain_name" {
  type        = string
  description = "The fully qualified domain name that Swarm should use for internal URLs."
  default     = null
}

variable "existing_redis_connection" {
  type = object({
    host = string
    port = number
  })
  description = "The connection specifications to use for an existing Redis deployment."
  default     = null
}

variable "helix_swarm_desired_container_count" {
  type        = number
  description = "The desired number of containers running the Helix Swarm service."
  default     = 1
}

# - Existing Cluster -
variable "cluster_name" {
  type        = string
  description = "The name of the cluster to deploy the Helix Swarm service into. Defaults to null and a cluster will be created."
  default     = null
}

# - Load Balancer -
variable "create_application_load_balancer" {
  type        = bool
  default     = true
  description = "This flag controls the creation of an application load balancer as part of the module."
}

variable "helix_swarm_alb_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the Helix Swarm load balancer into. Public subnets are recommended."
  default     = []
  validation {
    condition     = length(var.helix_swarm_alb_subnets) > 0 == var.create_application_load_balancer
    error_message = "Subnets are only necessary if the create_application_load_balancer variable is set."
  }
}

variable "enable_helix_swarm_alb_access_logs" {
  type        = bool
  description = "Enables access logging for the Helix Swarm ALB. Defaults to true."
  default     = true
}

variable "helix_swarm_alb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for Helix Swarm ALB access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
}

variable "helix_swarm_alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for Helix Swarm ALB access logs. If null the project prefix and module name are used."
  default     = null
}

variable "enable_helix_swarm_alb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the Helix Swarm ALB. Defaults to true."
  default     = true
}

variable "helix_swarm_service_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the Helix Swarm service into. Private subnets are recommended."
}

variable "existing_security_groups" {
  type        = list(string)
  description = "A list of existing security group IDs to attach to the Helix Swarm service load balancer."
  default     = []
}

variable "internal" {
  type        = bool
  description = "Set this flag to true if you do not want the Helix Swarm service load balancer to have a public IP."
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "The TLS certificate ARN for the Helix Swarm service load balancer."
  default     = null
  validation {
    condition     = var.create_application_load_balancer == (var.certificate_arn != null)
    error_message = "The certificate_arn variable must be set if and only if the create_application_load_balancer variable is set."
  }
}

# - Logging -
variable "helix_swarm_cloudwatch_log_retention_in_days" {
  type        = string
  description = "The log retention in days of the cloudwatch log group for Helix Swarm."
  default     = 365
}

# - Security and Permissions -
variable "custom_helix_swarm_role" {
  type        = string
  description = "ARN of the custom IAM Role you wish to use with Helix Swarm."
  default     = null
}

variable "create_helix_swarm_default_role" {
  type        = bool
  description = "Optional creation of Helix Swarm Default IAM Role. Default is set to true."
  default     = true
}

variable "create_helix_swarm_default_policy" {
  type        = bool
  description = "Optional creation of Helix Swarm default IAM Policy. Default is set to true."
  default     = true
}

variable "p4d_super_user_arn" {
  type        = string
  description = "The ARN of the parameter or secret where the p4d super user username is stored."
}

variable "p4d_super_user_password_arn" {
  type        = string
  description = "The ARN of the parameter or secret where the p4d super user password is stored."
}

variable "p4d_swarm_user_arn" {
  type        = string
  description = "The ARN of the parameter or secret where the swarm user username is stored."
}

variable "p4d_swarm_password_arn" {
  type        = string
  description = "The ARN of the parameter or secret where the swarm user password is stored."
}

variable "debug" {
  type        = bool
  default     = false
  description = "Debug flag to enable execute command on service for container access."
}

variable "enable_sso" {
  type        = bool
  default     = false
  description = "Set this to true if using SSO for Helix Swarm authentication."
}

######################
# ELASTICACHE CONFIG
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
