########################################
# CORE CONFIGURATION
########################################

variable "project_prefix" {
  type        = string
  description = "Prefix for resource names"
  default     = "cgd"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod, etc.)"
  default     = "dev"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where VDI instances will be deployed"
}

variable "subnets" {
  type        = list(string)
  description = "List of subnet IDs available for VDI instances (fallback if not specified per user)"
  default     = []
}

########################################
# VDI USER CONFIGURATION
########################################

variable "vdi_config" {
  type = map(object({
    # Required - Core compute and networking
    instance_type     = string
    availability_zone = string
    subnet_id         = string

    # Required - Storage configuration
    volumes = map(object({
      capacity   = number
      type       = string
      iops       = optional(number, 3000)
      throughput = optional(number, 125)
    }))

    # Optional - Customization
    ami                      = optional(string)
    iam_instance_profile     = optional(string)
    existing_security_groups = optional(list(string), [])
    allowed_cidr_blocks      = optional(list(string), ["10.0.0.0/16"])
    key_pair_name            = optional(string)
    admin_password           = optional(string)
    tags                     = optional(map(string), {})

    # Boolean Choices (3 total)
    join_ad                        = optional(bool, false) # AD integration vs local users
    create_default_security_groups = optional(bool, true)  # Convenience vs existing SGs
    create_key_pair                = optional(bool, true)  # Convenience vs existing keys
  }))

  description = "Configuration for each VDI user workstation"

  validation {
    condition = alltrue([
      for user, config in var.vdi_config : contains(["gp2", "gp3", "io1", "io2"], config.volumes.Root.type)
    ])
    error_message = "Root volume type must be one of: gp2, gp3, io1, io2."
  }

  validation {
    condition = alltrue([
      for user, config in var.vdi_config : config.volumes.Root.capacity >= 30 && config.volumes.Root.capacity <= 16384
    ])
    error_message = "Root volume capacity must be between 30 and 16384 GiB."
  }
}

########################################
# ACTIVE DIRECTORY (Optional)
########################################

variable "enable_ad_integration" {
  type        = bool
  description = "Enable Active Directory integration for domain-joined VDI"
  default     = false
}

variable "directory_id" {
  type        = string
  description = "AWS Managed Microsoft AD directory ID (required if enable_ad_integration = true)"
  default     = null
}

variable "directory_name" {
  type        = string
  description = "Fully qualified domain name (FQDN) of the directory"
  default     = null
}

variable "dns_ip_addresses" {
  type        = list(string)
  description = "DNS IP addresses for the directory"
  default     = []
}

variable "ad_admin_password" {
  type        = string
  description = "Directory administrator password"
  default     = ""
  sensitive   = true
}

variable "manage_ad_users" {
  type        = bool
  description = "Automatically create AD users (vs using existing users)"
  default     = false
}

variable "individual_user_passwords" {
  type        = map(string)
  description = "Map of individual user passwords for AD users (username -> password)"
  default     = {}
  sensitive   = true
}

variable "directory_ou" {
  type        = string
  description = "Organizational unit (OU) in the directory for computer accounts"
  default     = null
}

########################################
# STORAGE (Optional)
########################################

variable "ebs_encryption_enabled" {
  type        = bool
  description = "Enable EBS encryption for VDI volumes"
  default     = false
}

variable "ebs_kms_key_id" {
  type        = string
  description = "KMS key ID for EBS encryption (if encryption enabled)"
  default     = null
}

########################################
# SHARED CONFIGURATION
########################################

variable "ami_prefix" {
  type        = string
  description = "AMI name prefix for auto-discovery when ami not specified per user"
  default     = "windows-server-2025"
}

########################################
# SECURITY (Optional)
########################################

variable "auto_detect_public_ip" {
  type        = bool
  description = "Automatically detect and allow user's public IP for access"
  default     = true
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "Default CIDR blocks allowed for VDI access (can be overridden per user)"
  default     = ["10.0.0.0/16"]
}

variable "tags" {
  type        = map(string)
  description = "Default tags applied to all resources"
  default = {
    "iac-management" = "CGD-Toolkit"
    "iac-module"     = "VDI"
    "iac-provider"   = "Terraform"
  }
}
