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
    "IAC_MANAGEMENT" = "CGD-Toolkit"
    "IAC_MODULE"     = "swarm"
    "IAC_PROVIDER"   = "Terraform"
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

variable "container_name" {
  type        = string
  description = "The name of the swarm container."
  default     = "helix-swarm-container"
  nullable    = false
}

variable "container_port" {
  type        = number
  description = "The container port that swarm runs on."
  default     = 80
  nullable    = false
}

variable "container_cpu" {
  type        = number
  description = "The CPU allotment for the swarm container."
  default     = 1024
  nullable    = false
}

variable "container_memory" {
  type        = number
  description = "The memory allotment for the Helix Swarm container."
  default     = 4096
  nullable    = false
}

variable "desired_container_count" {
  type        = number
  description = "The desired number of containers running the Helix Swarm service."
  default     = 1
  nullable    = false
}

# - Existing Cluster -
variable "cluster_name" {
  type        = string
  description = "The name of the cluster to deploy the Helix Swarm service into. Defaults to null and a cluster will be created."
  default     = null
}

# - Load Balancer -
variable "swarm_alb_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the Helix Swarm load balancer into. Public subnets are recommended."
}

variable "enable_swarm_alb_access_logs" {
  type        = bool
  description = "Enables access logging for the Helix Swarm ALB. Defaults to false."
  default     = false
}

variable "swarm_alb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for Helix Swarm ALB access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
}

variable "swarm_alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for Helix Swarm ALB access logs. If null the project prefix and module name are used."
  default     = null
}

variable "enable_swarm_alb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the Helix Swarm ALB. Defaults to false."
  default     = false
}

variable "swarm_service_subnets" {
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
}

# - Filesystem -
variable "swarm_efs_performance_mode" {
  type        = string
  description = "The performance mode of the EFS file system used by the Helix Swarm service. Defaults to general purpose."
  default     = "generalPurpose"
}

variable "swarm_efs_throughput_mode" {
  type        = string
  description = "The throughput mode of the EFS file system used by the Helix Swarm service. Defaults to bursting."
  default     = "bursting"
}

# - Logging -
variable "swarm_cloudwatch_log_retention_in_days" {
  type        = string
  description = "The log retention in days of the cloudwatch log group for Helix Swarm."
  default     = 365
}

# - Security and Permissions -
variable "custom_swarm_role" {
  type        = string
  description = "ARN of the custom IAM Role you wish to use with Helix Swarm."
  default     = null
}

variable "create_swarm_default_role" {
  type        = bool
  description = "Optional creation of Helix Swarm Default IAM Role. Default is set to true."
  default     = true
}

variable "create_swarm_default_policy" {
  type        = bool
  description = "Optional creation of Helix Swarm default IAM Policy. Default is set to true."
  default     = true
}

variable "p4d_port" {
  type        = string
  description = "The P4D_PORT environment variable where Swarm should look for Helix Core. Defaults to 'ssl:perforce:1666'"
  default     = "ssl:perforce:1666"
}

variable "enable_elasticache_serverless" {
  type        = bool
  description = "Flag to enable/disable Redis elasticache. Defaults to false."
  default     = false
}

variable "enable_elastic_filesystem" {
  type        = bool
  description = "Flag to enable/disable elastic filesystem for persistent storage. Defaults to false."
  default     = false
}
