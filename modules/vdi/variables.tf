########################################
# GENERAL CONFIGURATION
########################################

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appended to the beginning of most resource names."
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
  description = "Tags to apply to resources."
}

variable "auto_detect_public_ip" {
  type        = bool
  description = "Whether to automatically detect and allow the user's public IP for DCV, RDP, and HTTPS access"
  default     = true
}

########################################
# NETWORKING CONFIGURATION
########################################

variable "vpc_id" {
  type        = string
  description = "The ID of the existing VPC to deploy the VDI instances into."
}

variable "subnets" {
  type        = list(string)
  description = "List of subnet IDs available for VDI instances."
}

########################################
# VDI CONFIGURATION
########################################

variable "vdi_config" {
  type = map(object({
    # Compute
    ami           = optional(string)
    instance_type = string
    
    # Networking
    availability_zone               = string
    subnet_id                      = string
    associate_public_ip_address    = optional(bool, false)
    
    # Security
    iam_instance_profile           = optional(string)
    create_default_security_groups = optional(bool, true)
    existing_security_groups       = optional(list(string), [])
    allowed_cidr_blocks           = optional(list(string), ["10.0.0.0/8"])
    
    # Key Pair Management
    key_pair_name   = optional(string)
    create_key_pair = optional(bool, true)
    
    # Password Management
    admin_password                     = optional(string)
    store_passwords_in_secrets_manager = optional(bool, true)
    
    # Storage
    volumes = map(object({
      capacity   = number
      type       = string
      iops       = optional(number, 3000)
      throughput = optional(number, 125)
    }))
    
    # Active Directory
    join_ad = optional(bool, false)
    
    # Tags for user identification
    tags = map(string)
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
# SHARED CONFIGURATION
########################################

variable "ami_prefix" {
  type        = string
  description = "The prefix of the AMI name created by the packer template. Used when ami is not specified in vdi_config."
  default     = "windows-server-2025"
}

########################################
# STORAGE CONFIGURATION
########################################

variable "ebs_encryption_enabled" {
  type        = bool
  description = "Whether to enable EBS encryption for all volumes."
  default     = false
}

variable "ebs_kms_key_id" {
  type        = string
  description = "The KMS key ID to use for EBS encryption. If not specified, the default AWS managed key is used."
  default     = null
}

########################################
# ACTIVE DIRECTORY CONFIGURATION
########################################

variable "enable_ad_integration" {
  type        = bool
  description = "Whether to enable Active Directory integration. When false, all AD-related resources are skipped."
  default     = true
}

variable "directory_id" {
  type        = string
  description = "ID of AWS Directory Service AD domain. Required when enable_ad_integration is true and join_ad is true for any user."
  default     = null
}

variable "directory_name" {
  type        = string
  description = "Name of AWS Directory Service AD domain. Required when join_ad is true for any user."
  default     = null
}

variable "directory_ou" {
  type        = string
  description = "Organizational unit of AWS Directory Service AD domain (e.g., DC=corp,DC=example,DC=com). If not provided, will use the domain root."
  default     = null
}

variable "dns_ip_addresses" {
  type        = list(string)
  description = "List of DNS IP addresses for the AD domain. Required if directory_id is provided."
  default     = []
}

variable "ad_admin_password" {
  type        = string
  description = "The AD domain administrator password. Used for domain joining operations."
  default     = ""
  sensitive   = true
}

variable "shared_temp_password" {
  type        = string
  description = "Shared temporary password for initial user login. Users will be forced to change this on first AD login. Required when join_ad is true for any user."
  default     = null
  sensitive   = true
}

variable "domain_join_timeout" {
  type        = number
  description = "Timeout in seconds for domain join operation."
  default     = 300
}