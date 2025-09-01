########################################
# GENERAL CONFIGURATION
########################################

variable "name" {
  description = "Unreal Cloud DDC Workload Name"
  type        = string
  default     = "unreal-cloud-ddc"
  validation {
    condition     = length(var.name) > 1 && length(var.name) <= 50
    error_message = "The defined 'name' has too many characters. This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appended to the beginning of most resource names."
  default     = "cgd"
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "terraform-aws-unreal-cloud-ddc"
    "ModuleName"     = "ddc-monitoring"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc"
  }
}

variable "environment" {
  type        = string
  description = "The current environment (e.g. dev, prod, etc.)"
  default     = "dev"
}

variable "vpc_id" {
  description = "String for VPC ID"
  type        = string
}

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-west-2"
}

variable "existing_security_groups" {
  description = "List of existing security groups to add to ALL monitoring resources (global access)"
  type        = list(string)
  default     = []
}

variable "additional_alb_security_groups" {
  type        = list(string)
  description = "Additional security group IDs to attach specifically to the monitoring Application Load Balancer (for monitoring team access)"
  default     = []
}

########################################
# ScyllaDB Monitoring Configuration
########################################

variable "scylla_node_ips" {
  type        = list(string)
  default     = []
  description = "List of ScyllaDB node IPs to monitor (provided by ddc-core module)"
}

variable "scylla_subnets" {
  type        = list(string)
  default     = []
  description = "A list of subnet IDs where monitoring will be deployed. Private subnets are strongly recommended."
}



variable "scylla_monitoring_instance_type" {
  type        = string
  default     = "t3.xlarge"
  description = "The type and size of the Scylla monitoring instance."
  nullable    = false
}

variable "scylla_monitoring_instance_storage" {
  type        = number
  default     = 20
  description = "Size of gp3 ebs volumes in GB attached to Scylla monitoring instance"
  nullable    = false
}

########################################
# Load Balancing
########################################

variable "create_application_load_balancer" {
  type        = bool
  description = "Whether to create an application load balancer for the Scylla monitoring dashboard."
  default     = true
}

variable "internal_facing_application_load_balancer" {
  type        = bool
  description = "Whether the application load balancer should be internal-facing."
  default     = false
}

variable "monitoring_application_load_balancer_subnets" {
  type        = list(string)
  description = "The subnets in which the ALB will be deployed"
  
  validation {
    condition     = (var.create_application_load_balancer && var.monitoring_application_load_balancer_subnets != null) || (!var.create_application_load_balancer && var.monitoring_application_load_balancer_subnets == null)
    error_message = "The monitoring_application_load_balancer_subnets variable must be set if create_application_load_balancer is true."
  }
  default = null
}

variable "alb_certificate_arn" {
  type        = string
  description = "The ARN of the certificate to use on the ALB"
  default     = null
  
  validation {
    condition     = (var.create_application_load_balancer && var.alb_certificate_arn != null) || (!var.create_application_load_balancer && var.alb_certificate_arn == null)
    error_message = "The alb_certificate_arn variable must be set if create_application_load_balancer is true."
  }
}

variable "enable_scylla_monitoring_lb_deletion_protection" {
  type        = bool
  description = "Whether to enable deletion protection for the Scylla monitoring load balancer."
  default     = false
}

variable "enable_scylla_monitoring_lb_access_logs" {
  type        = bool
  description = "Whether to enable access logs for the Scylla monitoring load balancer."
  default     = false
}

variable "scylla_monitoring_lb_access_logs_bucket" {
  type        = string
  description = "Name of the S3 bucket to store the access logs for the Scylla monitoring load balancer."
  default     = null
}

variable "scylla_monitoring_lb_access_logs_prefix" {
  type        = string
  description = "Prefix to use for the access logs for the Scylla monitoring load balancer."
  default     = null
}