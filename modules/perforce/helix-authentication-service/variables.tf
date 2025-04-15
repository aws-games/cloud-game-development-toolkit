########################################
# GENERAL CONFIGURATION
########################################
variable "name" {
  type        = string
  description = "The name attached to Helix Authentication Service module resources."
  default     = "helix-auth-svc"

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
    "iac-module"     = "helix-authentication-service"
    "iac-provider"   = "Terraform"
  }
  description = "Tags to apply to resources."
}

########################################
# NETWORKING
########################################

variable "vpc_id" {
  type        = string
  description = "The ID of the existing VPC you would like to deploy Helix Authentication Service into."
}

########################################
# ECS
########################################

variable "cluster_name" {
  type        = string
  description = "The name of the cluster to deploy the Helix Authentication Service into. Defaults to null and a cluster will be created."
  default     = null
}

# - Container Specs -

variable "container_name" {
  type        = string
  description = "The name of the Helix Authentication Service container."
  default     = "helix-auth-container"
  nullable    = false
}

variable "container_port" {
  type        = number
  description = "The container port that Helix Authentication Service runs on."
  default     = 3000
  nullable    = false
}

variable "container_cpu" {
  type        = number
  description = "The CPU allotment for the Helix Authentication Service container."
  default     = 1024
  nullable    = false
}

variable "container_memory" {
  type        = number
  description = "The memory allotment for the Helix Authentication Service container."
  default     = 4096
  nullable    = false
}

variable "desired_container_count" {
  type        = number
  description = "The desired number of containers running the Helix Authentication Service."
  default     = 1
  nullable    = false
}

# - Environment Variables -

variable "fully_qualified_domain_name" {
  type        = string
  description = "The fully qualified domain name where Helix Authentication Service will be available."
  default     = "localhost"
}

variable "enable_web_based_administration" {
  type        = bool
  description = "Flag for enabling web based administration of Helix Authentication Service."
  default     = false
}

# - Load Balancer -
variable "create_application_load_balancer" {
  type        = bool
  default     = true
  description = "This flag controls the creation of an application load balancer as part of the module."
}

variable "helix_authentication_service_alb_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the Helix Authentication Service load balancer into. Public subnets are recommended."
  default     = []
  validation {
    condition     = (length(var.helix_authentication_service_alb_subnets) > 0) == var.create_application_load_balancer
    error_message = "Subnets are only necessary if the create_application_load_balancer variable is set."
  }

}

variable "enable_helix_authentication_service_alb_access_logs" {
  type        = bool
  description = "Enables access logging for the Helix Authentication Service ALB. Defaults to true."
  default     = true
}

variable "helix_authentication_service_alb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for Helix Authentication Service ALB access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
}

variable "helix_authentication_service_alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for Helix Authentication Service ALB access logs. If null the project prefix and module name are used."
  default     = null
}

variable "enable_helix_authentication_service_alb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the Helix Authentication Service ALB. Defaults to true."
  default     = true
}

variable "helix_authentication_service_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the Helix Authentication Service into. Private subnets are recommended."
}

variable "existing_security_groups" {
  type        = list(string)
  description = "A list of existing security group IDs to attach to the Helix Authentication Service load balancer."
  default     = []
}

variable "internal" {
  type        = bool
  description = "Set this flag to true if you do not want the Helix Authentication Service load balancer to have a public IP."
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "The TLS certificate ARN for the Helix Authentication Service load balancer."
  default     = null
  validation {
    condition     = var.create_application_load_balancer == (var.certificate_arn != null)
    error_message = "The certificate_arn variable must be set if and only if the create_application_load_balancer variable is set."
  }
}

# - Logging -
variable "helix_authentication_service_cloudwatch_log_retention_in_days" {
  type        = string
  description = "The log retention in days of the cloudwatch log group for Helix Authentication Service."
  default     = 365
}

# - Security and Permissions -
variable "custom_helix_authentication_service_role" {
  type        = string
  description = "ARN of the custom IAM Role you wish to use with Helix Authentication Service."
  default     = null
}

variable "create_helix_authentication_service_default_role" {
  type        = bool
  description = "Optional creation of Helix Authentication Service default IAM Role. Default is set to true."
  default     = true
}

variable "create_helix_authentication_service_default_policy" {
  type        = bool
  description = "Optional creation of Helix Authentication Service default IAM Policy. Default is set to true."
  default     = true
}

variable "helix_authentication_service_admin_username_secret_arn" {
  type        = string
  description = "Optionally provide the ARN of an AWS Secret for the Helix Authentication Service Administrator username."
  default     = null
}

variable "helix_authentication_service_admin_password_secret_arn" {
  type        = string
  description = "Optionally provide the ARN of an AWS Secret for the Helix Authentication Service Administrator password."
  default     = null
}

variable "debug" {
  type        = bool
  description = "Set this flag to enable execute command on service containers and force redeploys."
  default     = false
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
}