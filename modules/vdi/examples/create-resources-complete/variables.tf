########################################
# GENERAL CONFIGURATION
########################################

variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in"
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "The name attached to VDI module resources"
  default     = "vdi-example"
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload"
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
    "iac-module"     = "VDI"
    "iac-provider"   = "Terraform"
  }
  description = "Tags to apply to resources"
}

########################################
# VPC CONFIGURATION
########################################

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets"
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets (used for Managed AD)"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

########################################
# INSTANCE CONFIGURATION
########################################

variable "instance_type" {
  type        = string
  description = "The EC2 instance type for the VDI instance"
  default     = "g4dn.2xlarge"
}

# Note: associate_public_ip_address and create_key_pair are now always true in the VDI module

########################################
# MANAGED MICROSOFT AD CONFIGURATION
########################################

variable "directory_admin_password_secret_name" {
  type        = string
  description = "Name of the AWS Secrets Manager secret that will store the auto-generated AD administrator password"
  default     = null # Will be generated with random suffix
}

variable "directory_admin_password" {
  type        = string
  description = "Optional: Manually specify AD administrator password. If not provided, a secure random password will be generated automatically."
  sensitive   = true
  default     = null
}

variable "directory_name" {
  type        = string
  description = "Name of AWS Directory Service AD domain. Used as the domain name for Managed Microsoft AD."
  default     = "corp.example.company.com"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$", var.directory_name))
    error_message = "Directory name must be a valid domain name (e.g., corp.example.com)."
  }
}

variable "directory_edition" {
  type        = string
  description = "The edition of the Managed Microsoft AD directory (Standard or Enterprise)"
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Enterprise"], var.directory_edition)
    error_message = "Directory edition must be either 'Standard' or 'Enterprise'."
  }
}

########################################
# OPTIONAL DNS CONFIGURATION
########################################

variable "domain_name" {
  type        = string
  description = "Optional: Domain name for DNS record (e.g., example.com). If provided, creates vdi.example.com record."
  default     = null
}
