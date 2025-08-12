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

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether to associate a public IP address with the VDI instance"
  default     = true
}

variable "create_key_pair" {
  type        = bool
  description = "Whether to create a new key pair"
  default     = false
}

variable "store_passwords_in_secrets_manager" {
  type        = bool
  description = "Whether to store generated passwords in AWS Secrets Manager"
  default     = true
}

variable "ami_prefix" {
  type        = string
  description = "The prefix of the AMI name created by the packer template"
  default     = "windows-server-2025"
}

########################################
# STORAGE CONFIGURATION
########################################

variable "root_volume_size" {
  type        = number
  description = "The size of the root EBS volume in GB"
  default     = 512
}

variable "root_volume_iops" {
  type        = number
  description = "The IOPS for the root EBS volume"
  default     = 4000
}

variable "root_volume_throughput" {
  type        = number
  description = "The throughput for the root EBS volume in MB/s"
  default     = 250
}

variable "additional_ebs_volumes" {
  type = list(object({
    device_name           = string
    volume_size           = number
    volume_type           = string
    iops                  = optional(number, 3000)
    throughput            = optional(number, 125)
    delete_on_termination = optional(bool, true)
  }))
  description = "List of additional EBS volumes to attach to the VDI instance"
  default = [
    {
      device_name           = "/dev/xvdf"
      volume_size           = 1000
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true
    }
  ]
}

########################################
# SECURITY CONFIGURATION
########################################

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "Additional CIDR blocks allowed to access the VDI instance (user's public IP is automatically detected)"
  default     = []
}

variable "admin_password" {
  type        = string
  description = "Shared temporary password for all VDI users. AD users will be forced to change this on first login."
  sensitive   = true
}

########################################
# MANAGED MICROSOFT AD CONFIGURATION
########################################

variable "directory_admin_password" {
  type        = string
  description = "The password for the Managed Microsoft AD administrator account"
  sensitive   = true
}

variable "directory_name" {
  type        = string
  description = "Name of AWS Directory Service AD domain. Used as the domain name for Managed Microsoft AD."

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