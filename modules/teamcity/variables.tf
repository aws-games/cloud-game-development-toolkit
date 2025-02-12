########################################
# GENERAL CONFIGURATION
########################################

variable "name" {
  type        = string
  default     = "teamcity"
  description = "The name applied to resources in the TeamCity module"
}
variable "tags" {
  type = map(any)
  default = {
    "iac-management" = "CGD-Toolkit"
    "iac-module"     = "TeamCity"
    "iac-provider"   = "Terraform"
  }
  description = "Tags to apply to resources."
}
variable "environment" {
  type        = string
  description = "The current environment (e.g. dev, prod, etc.)"
  default     = "dev"
}

########################################
# TeamCity SERVICE CONFIGURATION
########################################

variable "container_cpu" {
  type        = number
  default     = 1024
  description = "The number of CPU units to allocate to the TeamCity server container"
}
variable "container_memory" {
  type        = number
  default     = 4096
  description = "The number of MB of memory to allocate to the TeamCity server container"
}

variable "container_name" {
  type        = string
  default     = "teamcity"
  description = "The name of the TeamCity server container"
}

variable "container_port" {
  type        = number
  default     = 8111
  description = "The port on which the TeamCity server container listens"
}

variable "service_subnets" {
  type        = list(string)
  description = "The subnets in which the TeamCity server service will be deployed"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC in which the service will be deployed"
}
# Logging
variable "teamcity_cloudwatch_log_retention_in_days" {
  type        = string
  description = "The log retention in days of the cloudwatch log group for TeamCity."
  default     = 365
}

# Filesystem
variable "teamcity_efs_performance_mode" {
  type        = string
  description = "The performance mode of the EFS file system used by the TeamCity service. Defaults to general purpose."
  default     = "generalPurpose"
}

variable "teamcity_efs_throughput_mode" {
  type        = string
  description = "The throughput mode of the EFS file system used by the TeamCity service. Defaults to bursting."
  default     = "bursting"
}

variable "alb_subnets" {
  type        = list(string)
  description = "The subnets in which the ALB will be deployed"
}

variable "alb_certificate_arn" {
  type        = string
  description = "The ARN of the SSL certificate to use for the ALB"
}

