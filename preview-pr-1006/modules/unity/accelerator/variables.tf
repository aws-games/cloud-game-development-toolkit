####################################################
# General Configuration
####################################################

variable "name" {
  type        = string
  description = "The name applied to resources in the Unity Accelerator module."
  default     = "unity-accelerator"
}
variable "tags" {
  type = map(any)
  default = {
    "iac-management" = "CGD-Toolkit"
    "iac-module"     = "UnityAccelerator"
    "iac-provider"   = "Terraform"
  }
  description = "Tags to apply to resources."
}
variable "environment" {
  type        = string
  description = "The current environment (e.g. dev, prod, etc.)"
  default     = "dev"
}

variable "debug" {
  type        = bool
  description = "Set this flag to enable ECS execute permissions on the Unity Accelerator container and force new service deployments on Terraform apply."
  default     = true
}

####################################################
# EFS Configuration
####################################################

variable "efs_id" {
  type        = string
  description = "The ID of the EFS file system to use for the Unity Accelerator service."
  default     = null
}

variable "efs_performance_mode" {
  type        = string
  description = "The performance mode of the EFS file system used by the Unity Accelerator service. Defaults to general purpose."
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  type        = string
  description = "The throughput mode of the EFS file system used by the Unity Accelerator service. Defaults to bursting."
  default     = "bursting"
}

variable "efs_access_point_id" {
  type        = string
  description = "The ID of the EFS access point to use for the Unity Accelerator data volume."

  validation {
    condition     = (var.efs_id == null && var.efs_access_point_id == null) || (var.efs_id != null && var.efs_access_point_id != null)
    error_message = "The efs_access_point_id variable must be set if efs_id is set."
  }
  default = null
}

variable "efs_encryption_enabled" {
  type        = bool
  description = "Set this flag to true to enable EFS encryption."
  default     = true
}

####################################################
# Unity Accelerator Configuration
####################################################

variable "unity_accelerator_docker_image" {
  type        = string
  description = "Docker image to use for Unity Accelerator."
  default     = "unitytechnologies/accelerator:latest"
}

variable "unity_accelerator_log_stdout" {
  type        = string
  description = "When true, outputs logs to stdout only. When false, writes logs to the persist directory."
  default     = "true"
}

variable "unity_accelerator_debug_mode" {
  type        = string
  description = "Enables debug output for the Unity Accelerator service."
  default     = "false"
}

variable "unity_accelerator_dashboard_username_arn" {
  description = "ARN of the AWS Secrets Manager secret containing the Unity Accelerator web dashboard username. Username must be the only value and stored as text, not as key/value JSON. If not passed, one will be created and defaulted to 'uauser'."
  type        = string
  default     = null
}

variable "unity_accelerator_dashboard_password_arn" {
  description = "ARN of the AWS Secrets Manager secret containing the Unity Accelerator web dashboard password. Password must be the only value and stored as text, not as key/value JSON. If not passed, one will be created randomly."
  type        = string
  default     = null
}

####################################################
# Unity Accelerator ECS Cluster Configuration
####################################################

variable "cluster_name" {
  type        = string
  description = "The name of the ECS cluster to deploy Unity Accelerator to."
  default     = null
}

variable "container_cpu" {
  type        = number
  description = "The number of CPU units to allocate to the Unity Accelerator container."
  default     = 1024
}
variable "container_memory" {
  type        = number
  description = "The number of MB of memory to allocate to the Unity Accelerator container."
  default     = 4096
}

variable "container_name" {
  type        = string
  description = "The name of the Unity Accelerator container."
  default     = "unity-accelerator"
}

########################################
# Networking
########################################

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC in which the service will be deployed."
}

variable "service_subnets" {
  type        = list(string)
  description = "The subnets in which the Unity Accelerator service will be deployed."
}

# Logging
variable "cloudwatch_log_retention_in_days" {
  type        = string
  description = "The log retention in days of the cloudwatch log group for Unity Accelerator."
  default     = 365
}

########################################
# Load Balancing
########################################

##########
# General
##########
variable "lb_subnets" {
  type        = list(string)
  description = "The subnets in which the Application Load Balancer and Network Load Balancer will be deployed."

  validation {
    condition     = (var.create_alb == true || var.create_nlb == true) && length(var.lb_subnets) > 0
    error_message = "The lb_subnets variable must be set if create_alb or create_nlb is true."
  }
  default = []
}

variable "enable_unity_accelerator_lb_access_logs" {
  type        = bool
  description = "Enables access logging for the Application Load Balancer and Network Load Balancer used by Unity Accelerator. Defaults to true."
  default     = true
}

variable "unity_accelerator_lb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for Unity Accelerator Application Load Balancer and Network Load Balancer access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
}

variable "enable_unity_accelerator_lb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the Unity Accelerator Application Load Balancer and Network Load Balancer. Defaults to true."
  default     = true
}

######
# ALB
######
variable "create_alb" {
  type        = bool
  description = "Set this flag to true to create an Application Load Balancer for the Unity Accelerator dashboard."
  default     = true
}

variable "alb_is_internal" {
  type        = bool
  description = "Set this flag to determine whether the Application Load Balancer to create is internal (true) or external (false). Value is ignored if no ALB is created."
  default     = false
}

variable "alb_certificate_arn" {
  type        = string
  description = "The ARN of the SSL certificate to use for the Application Load Balancer."

  validation {
    condition     = var.create_alb == true && var.alb_certificate_arn != null
    error_message = "The alb_certificate_arn variable must be set if create_external_alb is true."
  }
  default = null
}

variable "unity_accelerator_alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for Unity Accelerator Application Load Balancer access logs. If null the project prefix and module name are used."
  default     = null
}

######
# NLB
######
variable "create_nlb" {
  type        = bool
  description = "Set this flag to true to create an external Network Load Balancer for the Unity Accelerator protobuf traffic."
  default     = true
}

variable "nlb_is_internal" {
  type        = bool
  description = "Set this flag to determine whether the Network Load Balancer to create is internal (true) or external (false). Value is ignored if no NLB is created."
  default     = false
}

variable "unity_accelerator_nlb_access_logs_prefix" {
  type        = string
  description = "Log prefix for Unity Accelerator Network Load Balancer access logs. If null the project prefix and module name are used."
  default     = null
}
