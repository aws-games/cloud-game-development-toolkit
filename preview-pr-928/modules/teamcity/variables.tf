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

variable "debug" {
  type        = bool
  description = "Set this flag to enable ECS execute permissions on the TeamCity server container and force new service deployments on Terraform apply."
  default     = false
}

########################################
# TeamCity SERVICE CONFIGURATION (ECS)
########################################

variable "cluster_name" {
  type        = string
  description = "The name of the ECS cluster to deploy TeamCity to."
  default     = null

}

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

variable "desired_container_count" {
  type        = number
  description = "The desired number of containers running TeamCity server."
  default     = 1
  nullable    = false
}

########################################
# Networking
########################################

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

########################################
# EFS Configuration
########################################

variable "efs_id" {
  type        = string
  description = "The ID of the EFS file system to use for the TeamCity service."
  default     = null
}

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

variable "efs_access_point_id" {
  type        = string
  description = "The ID of the EFS access point to use for the TeamCity data volume."

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

########################################
# Load Balancing
########################################
variable "create_external_alb" {
  type        = bool
  description = "Set this flag to true to create an external load balancer for TeamCity."
  default     = true
}

variable "alb_subnets" {
  type        = list(string)
  description = "The subnets in which the ALB will be deployed"

  validation {
    condition     = var.create_external_alb == true && length(var.alb_subnets) > 0
    error_message = "The alb_subnets variable must be set if create_external_alb is true."
  }
  default = []
}

variable "alb_certificate_arn" {
  type        = string
  description = "The ARN of the SSL certificate to use for the ALB"

  validation {
    condition     = var.create_external_alb == true && var.alb_certificate_arn != null
    error_message = "The alb_certificate_arn variable must be set if create_external_alb is true."
  }
  default = null
}

variable "enable_teamcity_alb_access_logs" {
  type        = bool
  description = "Enables access logging for the TeamCity ALB. Defaults to true."
  default     = true
}

variable "teamcity_alb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for TeamCity ALB access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
}

variable "teamcity_alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for TeamCity ALB access logs. If null the project prefix and module name are used."
  default     = null
}

variable "enable_teamcity_alb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the TeamCity ALB. Defaults to true."
  default     = false
}

########################################
# Aurora Cluster
########################################

variable "database_connection_string" {
  type        = string
  description = "The database connection string for TeamCity"
  default     = null
}

variable "database_master_username" {
  type        = string
  description = "The master username for the database"

  validation {
    condition     = (var.database_connection_string == null && var.database_master_username == null) || (var.database_connection_string != null && var.database_master_username != null)
    error_message = "The database_master_username variable must be set."
  }
  default = null
}
variable "database_master_password" {
  type        = string
  description = "The master password for the database"
  validation {
    condition     = (var.database_connection_string == null && var.database_master_password == null) || (var.database_connection_string != null && var.database_master_password != null)
    error_message = "The database_master_password variable must be set."
  }
  default = null
}

variable "aurora_skip_final_snapshot" {
  type        = bool
  description = "Flag for whether a final snapshot should be created when the cluster is destroyed."
  default     = true
}

variable "aurora_instance_count" {
  type        = number
  description = "Number of instances to provision for the Aurora cluster"
  default     = 2
}

##########################################
### Build Farm Configuration Variables ###
##########################################

variable "build_farm_config" {
  type = map(object({
    image                 = string
    desired_count         = number
    cpu                   = number
    memory                = number
    environment           = optional(map(string), {})
    ephemeral_storage_gib = optional(number, 20)
  }))
  default     = {}
  description = <<-EOT
    Map of build agent configurations where each key is the agent name and the value defines:
    - image: Container image for the build agent
    - desired_count: Number of agent instances to run
    - cpu: CPU units to allocate (1024 = 1 vCPU)
    - memory: Memory in MiB to allocate
    - environment: Optional map of custom environment variables for non-sensitive configuration
    - ephemeral_storage_gib: Optional ephemeral storage size in GiB (defaults to 20 GiB)
  EOT
}

variable "agent_log_group_retention_in_days" {
  type    = number
  default = 7
}
