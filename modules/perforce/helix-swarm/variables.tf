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
  description = "The current environment (e.g. dev, prod, etc.) Defaults to dev."
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

########################################
# LOAD BALANCER CONFIGURATION
########################################
variable "swarm_alb_subnets" {
  type        = list(string)
  description = "The subnets where the ALB for Perforce Helix Swarm will be deployed."
}

variable "enable_swarm_alb_access_logs" {
  type        = bool
  description = "Enables access logging got the Helix Swarm ALB. Defaults to false."
  default     = false
}

variable "swarm_alb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for swarm ALB access log storage. If access logging is enabled and this is null the module creates a bucket."
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

########################################
# NETWORKING AND SECURITY
########################################
variable "vpc_id" {
  type        = string
  description = "The ID of the existing VPC you would like to deploy Helix Swarm into."
}

variable "instance_subnet_id" {
  type        = string
  description = "The subnet where the Helix Swarm instance will be deployed."
}

variable "existing_security_groups" {
  type        = list(string)
  description = "A list of existing security group IDs to attach to the Helix Swarm load balancer."
  default     = []
}

variable "internal" {
  type        = bool
  description = "Set this flag to true if you do not want the Helix Swarm load balancer to have a public IP."
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "Certificate ARN for Helix Swarm load balancer."
}

########################################
# INSTANCE CONFIGURATION
########################################
variable "instance_type" {
  type        = string
  description = "The instance type for Perforce Helix Swarm. Defaults to t3.small."
  default     = "t3.small"
}

########################################
# IAM CONFIGURATION
########################################
variable "custom_swarm_role" {
  type        = string
  description = "ARN of the custom IAM Role you wish to use with Helix Swarm."
  default     = null
}

variable "create_swarm_default_role" {
  type        = bool
  description = "Optional creation of Helix Swarm default IAM Role with SSM managed instance core policy attached. Default is set to true."
  default     = true
}


