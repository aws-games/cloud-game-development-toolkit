########################################
# CORE CONFIGURATION
########################################

variable "project_prefix" {
  type        = string
  description = "Prefix for resource names"
  default     = "cgd"
}

variable "region" {
  type        = string
  description = "AWS region for deployment"
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

########################################
# VDI ARCHITECTURE - 5-TIER DESIGN
########################################

# 1. TEMPLATES - Configuration blueprints with named volumes
variable "templates" {
  type = map(object({
    # Core compute configuration
    instance_type = string
    ami           = optional(string, null)
    
    # Software and customization
    software_packages = optional(list(string), [])
    gpu_enabled       = optional(bool, false)
    custom_scripts    = optional(list(string), [])
    
    # Named volumes with Windows drive mapping
    volumes = map(object({
      capacity      = number
      type          = string
      windows_drive = string
      iops          = optional(number, 3000)
      throughput    = optional(number, 125)
      encrypted     = optional(bool, true)
    }))
    
    # Optional configuration
    iam_instance_profile = optional(string, null)
    tags                 = optional(map(string), {})
  }))
  
  description = <<EOF
Configuration blueprints defining instance types, software packages, and named volumes with Windows drive mapping.

Templates provide reusable configurations that can be referenced by multiple workstations.

Example:
templates = {
  "ue-developer" = {
    instance_type = "g4dn.2xlarge"
    gpu_enabled   = true
    software_packages = ["chocolatey", "visual-studio-2022", "git", "unreal-engine-5.3"]
    custom_scripts = ["scripts/setup-ue-project.ps1"]
    volumes = {
      Root = { capacity = 256, type = "gp3", windows_drive = "C:" }
      Projects = { capacity = 1024, type = "gp3", windows_drive = "D:" }
    }
  }
}

Valid software_packages: "chocolatey", "visual-studio-2022", "git", "unreal-engine-5.3", "perforce"
Valid volume types: "gp2", "gp3", "io1", "io2"
Windows drives: "C:", "D:", "E:", etc.
EOF
  default     = {}

  validation {
    condition = alltrue([
      for template_key, config in var.templates : 
      alltrue([
        for volume_name, volume in config.volumes : 
        contains(["gp2", "gp3", "io1", "io2"], volume.type)
      ])
    ])
    error_message = "All volume types must be one of: gp2, gp3, io1, io2."
  }

  validation {
    condition = alltrue([
      for template_key, config in var.templates : 
      alltrue([
        for volume_name, volume in config.volumes : 
        volume.capacity >= 30 && volume.capacity <= 16384
      ])
    ])
    error_message = "All volume capacities must be between 30 and 16384 GiB."
  }

  validation {
    condition = alltrue([
      for template_key, config in var.templates : 
      alltrue([
        for volume_name, volume in config.volumes : 
        can(regex("^[A-Z]:$", volume.windows_drive))
      ])
    ])
    error_message = "Windows drive must be in format 'C:', 'D:', 'E:', etc."
  }

  validation {
    condition = alltrue([
      for template_key, config in var.templates : 
      alltrue([
        for package in config.software_packages : 
        contains(["chocolatey", "visual-studio-2022", "git", "unreal-engine-5.3", "perforce"], package)
      ])
    ])
    error_message = "software_packages must only contain: chocolatey, visual-studio-2022, git, unreal-engine-5.3, perforce"
  }
}

# 2. WORKSTATIONS - Physical infrastructure with template references
variable "workstations" {
  type = map(object({
    # Template reference
    template_key = string
    
    # Infrastructure placement
    subnet_id         = string
    availability_zone = string
    security_groups   = list(string)
    
    # Software flexibility per workstation
    software_packages_additions = optional(list(string), [])
    software_packages_exclusions = optional(list(string), [])
    custom_scripts    = optional(list(string), [])
    
    # Optional overrides
    allowed_cidr_blocks = optional(list(string), ["10.0.0.0/16"])
    tags                = optional(map(string), {})
  }))
  
  description = <<EOF
Physical infrastructure instances with template references and placement configuration.

Workstations inherit configuration from templates but can add or exclude software packages.

Example:
workstations = {
  "alice-workstation" = {
    template_key = "ue-developer"  # Inherits from templates
    subnet_id = "subnet-123"
    availability_zone = "us-east-1a"
    security_groups = ["sg-456"]
    software_packages_additions = ["perforce"]  # Add to template packages
    software_packages_exclusions = ["visual-studio-2022"]  # Remove from template
    custom_scripts = ["scripts/alice-setup.ps1"]
    allowed_cidr_blocks = ["203.0.113.1/32"]
  }
}

Valid software_packages: "chocolatey", "visual-studio-2022", "git", "unreal-engine-5.3", "perforce"
EOF
  default     = {}

  validation {
    condition = alltrue([
      for workstation_key, config in var.workstations : 
      length(config.template_key) > 0
    ])
    error_message = "Each workstation must reference a valid template_key."
  }

  validation {
    condition = alltrue([
      for workstation_key, config in var.workstations : 
      alltrue([
        for package in config.software_packages_additions : 
        contains(["chocolatey", "visual-studio-2022", "git", "unreal-engine-5.3", "perforce"], package)
      ])
    ])
    error_message = "software_packages_additions must only contain: chocolatey, visual-studio-2022, git, unreal-engine-5.3, perforce"
  }

  validation {
    condition = alltrue([
      for workstation_key, config in var.workstations : 
      alltrue([
        for package in config.software_packages_exclusions : 
        contains(["chocolatey", "visual-studio-2022", "git", "unreal-engine-5.3", "perforce"], package)
      ])
    ])
    error_message = "software_packages_exclusions must only contain: chocolatey, visual-studio-2022, git, unreal-engine-5.3, perforce"
  }
}

# 3. LOCAL USERS - Windows user accounts
variable "users" {
  type = map(object({
    given_name  = string
    family_name = string
    email       = string
    tags        = optional(map(string), {})
  }))
  description = "Local Windows user accounts (managed via Secrets Manager)"
  default     = {}
}

# 4. AD USERS - Active Directory user accounts
variable "ad_users" {
  type = map(object({
    given_name       = string
    family_name      = string
    email            = string
    group_membership = optional(list(string), [])  # References ad_groups keys
    tags             = optional(map(string), {})
  }))
  description = "Active Directory user accounts (UNSUPPORTED in current version - planned for future release)"
  default     = {}
  
  validation {
    condition     = length(var.ad_users) == 0
    error_message = "Active Directory users are not supported in this version of the VDI module. This feature is planned for a future release. Use the 'users' variable for local user accounts instead."
  }
}

# 5. AD GROUPS - Active Directory groups
variable "ad_groups" {
  type = map(object({
    description = string
    tags        = optional(map(string), {})
  }))
  description = "Active Directory groups for user organization (UNSUPPORTED in current version - planned for future release)"
  default     = {}
  
  validation {
    condition     = length(var.ad_groups) == 0
    error_message = "Active Directory groups are not supported in this version of the VDI module. This feature is planned for a future release."
  }
}

# 6. WORKSTATION ASSIGNMENTS - Workstation-centric user mapping
variable "workstation_assignments" {
  type = map(object({
    user        = string
    user_source = string
    tags        = optional(map(string), {})
  }))
  description = <<EOF
Workstation assignments mapping workstations to users.

Key must match a workstation key. Maps each workstation to a specific user.

Example:
workstation_assignments = {
  "alice-workstation" = {
    user = "alice"          # References users{} key
    user_source = "local"   # Local Windows account
  }
  "bob-workstation" = {
    user = "bob-smith"      # References ad_users{} key  
    user_source = "ad"      # Active Directory account
  }
}

Valid user_source: "local" (uses users{}), "ad" (uses ad_users{})
EOF
  default     = {}
  
  validation {
    condition = alltrue([
      for assignment in var.workstation_assignments : 
      contains(["local", "ad"], assignment.user_source)
    ])
    error_message = "user_source must be either 'local' or 'ad'"
  }
}

########################################
# DCV SESSION MANAGEMENT
########################################

variable "enable_admin_fleet_access" {
  type        = bool
  description = "Enable admin accounts (Administrator, VDIAdmin, DomainAdmin) to access all VDI instances in the deployment"
  default     = true
}

variable "dcv_session_permissions" {
  type = object({
    admin_default_permissions = optional(string, "full")  # "view" or "full"
    user_can_share_session   = optional(bool, false)     # Allow users to share their own sessions
    auto_create_user_session = optional(bool, true)      # Create session for assigned user at boot
  })
  description = "DCV session management and permission configuration"
  default     = {}
  
  validation {
    condition = contains(["view", "full"], var.dcv_session_permissions.admin_default_permissions)
    error_message = "admin_default_permissions must be either 'view' or 'full'."
  }
}

########################################
# AUTHENTICATION CONFIGURATION
########################################

# Authentication method is automatically inferred:
# - Local users (user_source = "local") → EC2 keys + Secrets Manager
# - AD users (user_source = "ad") → EC2 keys + Active Directory
# - Admin accounts always get EC2 keys + Secrets Manager (for break-glass access)

variable "dual_admin_pattern" {
  type = object({
    enabled                   = optional(bool, true)   # Use dual admin accounts
    administrator_unchanging  = optional(bool, true)   # Administrator account never rotates (break-glass)
    managed_admin_name       = optional(string, "VDIAdmin")  # Managed admin account name
    user_can_change_password = optional(bool, false)   # Allow users to change their own passwords
  })
  description = "Dual admin account pattern configuration (no automatic rotation - use AD for that)"
  default     = {}
}



########################################
# LEGACY CONFIGURATION (REMOVED IN v2.0.0)
########################################

# BREAKING CHANGE: vdi_instances and vdi_users variables removed
# Use new 5-tier architecture: templates, workstations, users, groups, assignments
# Migration guide: See docs/migration-v1-to-v2.md

########################################
# ACTIVE DIRECTORY (Optional)
########################################

variable "enable_ad_integration" {
  type        = bool
  description = "Enable Active Directory integration for domain-joined VDI (UNSUPPORTED in current version - planned for future release)"
  default     = false
  
  validation {
    condition     = var.enable_ad_integration == false
    error_message = "Active Directory integration is not supported in this version of the VDI module. This feature is planned for a future release. Use local users with Secrets Manager authentication instead."
  }
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

# tflint-ignore: terraform_unused_declarations
variable "dns_ip_addresses" {
  type        = list(string)
  description = "DNS IP addresses for the directory"
  default     = null
}

# tflint-ignore: terraform_unused_declarations
variable "ad_admin_password" {
  type        = string
  description = "Directory administrator password"
  default     = null
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
  description = "AMI name prefix for auto-discovery when ami not specified in templates"
  default     = "vdi_lightweight_ws2025"
}

########################################
# CENTRALIZED LOGGING (CGD PATTERN)
########################################

variable "enable_centralized_logging" {
  type        = bool
  description = "Enable centralized logging with CloudWatch log groups following CGD Toolkit patterns"
  default     = false
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention period in days"
  default     = 30
  
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch log retention value."
  }
}

variable "log_group_prefix" {
  type        = string
  description = "Prefix for CloudWatch log group names (useful for multi-module deployments)"
  default     = null
}

########################################
# S3 BUCKET CONFIGURATION
########################################

variable "s3_bucket_prefix" {
  type        = string
  description = "Prefix for S3 bucket names (will be combined with project_prefix and random suffix)"
  default     = "vdi"
}

# Note: S3 buckets are always created for emergency keys and installation scripts
# This ensures proper functionality of break-glass access and software installation

########################################
# DNS CONFIGURATION (Optional)
########################################

variable "dns_config" {
  type = object({
    private_zone = object({
      enabled     = optional(bool, true)
      domain_name = optional(string, "vdi.internal")
      vpc_id      = optional(string, null)
    })
    regional_endpoints = object({
      enabled = optional(bool, false)
      pattern = optional(string, "{region}.{domain}")
    })
    load_balancer_alias = object({
      enabled   = optional(bool, false)
      subdomain = optional(string, "lb")
    })
  })
  description = "DNS configuration for VDI instances and services"
  default     = null
}

########################################
# SECURITY (Optional)
########################################

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "Default CIDR blocks allowed for VDI access (can be overridden per user)"
  default     = ["10.0.0.0/16"]
}

variable "create_default_security_groups" {
  type        = bool
  description = "Create default security groups for VDI workstations"
  default     = true
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "-"
    "ModuleName"     = "terraform-aws-vdi"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi"
  }
}
