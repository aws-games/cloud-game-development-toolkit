########################################
# GENERAL CONFIGURATION
########################################

variable "name" {
  type        = string
  description = "The name attached to Jenkins module resources."
  default     = "jenkins"

  validation {
    condition     = length(var.name) > 1 && length(var.name) <= 50
    error_message = "The defined 'name' has too many characters (${length(var.name)}). This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}

# - General -
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
    "iac-module"     = "Jenkins"
    "iac-provider"   = "Terraform"
  }
  description = "Tags to apply to resources."
}

# - Debug -
variable "debug" {
  type        = bool
  description = "This value disables certain protections to accelerate testing (note that by enabling this variable, data will not be saved between destroys)"
  default     = false
}

# - Networking -
variable "vpc_id" {
  type        = string
  description = "The ID of the existing VPC you would like to deploy the Jenkins service and build farms into."
}

########################################
# JENKINS SERVICE CONFIGURATION
########################################

# - container -
variable "container_name" {
  type        = string
  description = "The name of the Jenkins service container."
  default     = "jenkins-container"
}

variable "container_port" {
  type        = number
  description = "The container port used by the Jenkins service container."
  default     = 8080
}

variable "container_cpu" {
  type        = number
  description = "The CPU allotment for the Jenkins container."
  default     = 1024
}

variable "container_memory" {
  type        = number
  description = "The memory allotment for the Jenkins container."
  default     = 4096
}

variable "jenkins_service_desired_container_count" {
  type        = number
  description = "The desired number of containers running the Jenkins service."
  default     = 1
}

# - Existing Cluster -
variable "cluster_name" {
  type        = string
  description = "The ARN of the cluster to deploy the Jenkins service into. Defaults to null and a cluster will be created."
  default     = null
}

variable "create_application_load_balancer" {
  type        = bool
  description = "Controls creation of an application load balancer within the module. Defaults to true."
  default     = true
}

# - Load Balancer -
variable "jenkins_alb_subnets" {
  type        = list(string)
  description = "A list of subnet ids to deploy the Jenkins load balancer into. Public subnets are recommended."
}

variable "enable_jenkins_alb_access_logs" {
  type        = bool
  description = "Enables access logging for the Jenkins ALB. Defaults to true."
  default     = true
}

variable "jenkins_alb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for Jenkins ALB access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
}

variable "jenkins_alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for Jenkins ALB access logs. If null the project prefix and module name are used."
  default     = null
}

variable "enable_jenkins_alb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the Jenkins ALB. Defaults to true."
  default     = true
}

variable "jenkins_service_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the Jenkins service into. Private subnets are recommended."
}

variable "existing_security_groups" {
  type        = list(string)
  description = "A list of existing security group IDs to attach to the Jenkins service load balancer."
  default     = null
}

variable "internal" {
  type        = bool
  description = "Set this flag to true if you do not want the Jenkins service load balancer to have a public IP."
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "The TLS certificate ARN for the Jenkins service load balancer."
  default     = null
  # If create_application_load_balancer is false this can be null. Otherwise it must be set.
  validation {
    condition     = var.create_application_load_balancer ? var.certificate_arn != null : true
    error_message = "Certificate ARN must be set if an application load balancer is created."
  }
}

# - Filesystem -
variable "jenkins_efs_performance_mode" {
  type        = string
  description = "The performance mode of the EFS file system used by the Jenkins service. Defaults to general purpose."
  default     = "generalPurpose"
}

variable "jenkins_efs_throughput_mode" {
  type        = string
  description = "The throughput mode of the EFS file system used by the Jenkins service. Defaults to bursting."
  default     = "bursting"
}

variable "enable_default_efs_backup_plan" {
  type        = bool
  description = "This flag controls EFS backups for the Jenkins module. Default is set to true."
  default     = true
}

# - Logging -
variable "jenkins_cloudwatch_log_retention_in_days" {
  type        = string
  description = "The log retention in days of the cloudwatch log group for Jenkins."
  default     = 365
}

# - Security and Permissions -
variable "jenkins_agent_secret_arns" {
  type        = list(string)
  description = "A list of secretmanager ARNs (wildcards allowed) that contain any secrets which need to be accessed by the Jenkins service."
  default     = null
}

variable "custom_jenkins_role" {
  type        = string
  description = "ARN of the custom IAM Role you wish to use with Jenkins."
  default     = null
}

variable "create_jenkins_default_role" {
  type        = bool
  description = "Optional creation of Jenkins Default IAM Role. Default is set to true."
  default     = true
}

variable "create_jenkins_default_policy" {
  type        = bool
  description = "Optional creation of Jenkins Default IAM Policy. Default is set to true."
  default     = true
}

variable "create_ec2_fleet_plugin_policy" {
  type        = bool
  description = "Optional creation of IAM Policy required for Jenkins EC2 Fleet plugin. Default is set to false."
  default     = false
}

########################################
# BUILD FARM CONFIGURATION
########################################
variable "build_farm_subnets" {
  type        = list(string)
  description = "The subnets to deploy the build farms into."
}

variable "build_farm_compute" {
  type = map(object(
    {
      ami = string
      #TODO: Support mixed instances / spot with custom policies
      instance_type     = string
      ebs_optimized     = optional(bool, true)
      enable_monitoring = optional(bool, true)
    }
  ))
  description = "Each object in this map corresponds to an ASG used by Jenkins as build agents."
  default     = {}
}

#TODO: Expand to support warm EBS pool, FSxN, EFS
variable "build_farm_fsx_openzfs_storage" {
  type = map(object(
    {
      storage_capacity    = number
      throughput_capacity = number
      storage_type        = optional(string, "SSD") # "SSD", "HDD"
      deployment_type     = optional(string, "SINGLE_AZ_1")
      route_table_ids     = optional(list(string), null)
      tags                = optional(map(string), null)
    }
  ))
  description = "Each object in this map corresponds to an FSx OpenZFS file system used by the Jenkins build agents."
  validation {
    condition = alltrue([
      for filesystem in var.build_farm_fsx_openzfs_storage : contains(["SSD", "HDD"], filesystem.storage_type)
    ])
    error_message = "Invalid storage_type. Valid options are 'SSD' and 'HDD' only."
  }
  validation {
    condition = alltrue([
      for filesystem in var.build_farm_fsx_openzfs_storage : contains(["MULTI_AZ_1", "SINGLE_AZ_1"], filesystem.deployment_type)
    ])
    error_message = "Invalid deployment_type. Valid options are 'MULTI_AZ_1' and 'SINGLE_AZ_1' only."
  }
  default = {}
}

variable "existing_artifact_buckets" {
  type        = list(string)
  description = "List of ARNs of the S3 buckets used to store artifacts created by the build farm."
  default     = []
}

variable "artifact_buckets" {
  type = map(
    object({
      name                 = string
      enable_force_destroy = optional(bool, true)
      enable_versioning    = optional(bool, true)
      tags                 = optional(map(string), {})
    })
  )
  description = "List of Amazon S3 buckets you wish to create to store build farm artifacts."
  default     = null
}
