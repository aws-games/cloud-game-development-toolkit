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
    
    # Hardware configuration
    gpu_enabled       = optional(bool, false)
    
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
Configuration blueprints defining instance types and named volumes with Windows drive mapping.

**KEY BECOMES TEMPLATE NAME**: The map key (e.g., "ue-developer") becomes the template name referenced by workstations.

Templates provide reusable configurations that can be referenced by multiple workstations via template_key.

Example:
templates = {
  "ue-developer" = {           # ← This key becomes the template name
    instance_type = "g4dn.2xlarge"
    gpu_enabled   = true
    volumes = {
      Root = { capacity = 256, type = "gp3", windows_drive = "C:" }
      Projects = { capacity = 1024, type = "gp3", windows_drive = "D:" }
    }
  }
  "basic-workstation" = {      # ← Another template name
    instance_type = "g4dn.xlarge"
    gpu_enabled   = true
  }
}

# Referenced by workstations:
workstations = {
  "alice-ws" = {
    template_key = "ue-developer"    # ← References template by key
  }
}

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
    
    # Optional overrides
    allowed_cidr_blocks = optional(list(string), ["10.0.0.0/16"])
    tags                = optional(map(string), {})
  }))
  
  description = <<EOF
Physical infrastructure instances with template references and placement configuration.

**KEY BECOMES WORKSTATION NAME**: The map key (e.g., "alice-workstation") becomes the workstation identifier used throughout the module.

Workstations inherit configuration from templates via template_key reference.

Example:
workstations = {
  "alice-workstation" = {        # ← This key becomes the workstation name
    template_key = "ue-developer"  # ← References templates{} key
    subnet_id = "subnet-123"
    availability_zone = "us-east-1a"
    security_groups = ["sg-456"]
    allowed_cidr_blocks = ["203.0.113.1/32"]
  }
  "vdi-001" = {                  # ← Another workstation name
    template_key = "basic-workstation"
    subnet_id = "subnet-456"
  }
}

# Referenced by assignments:
workstation_assignments = {
  "alice-workstation" = {        # ← Must match workstations{} key
    user = "alice"                # ← References users{} key
  }
}
EOF
  default     = {}

  validation {
    condition = alltrue([
      for workstation_key, config in var.workstations : 
      length(config.template_key) > 0
    ])
    error_message = "Each workstation must reference a valid template_key."
  }


}

# 3. LOCAL USERS - Windows user accounts with group types and connectivity
variable "users" {
  type = map(object({
    given_name        = string
    family_name       = string
    email             = string
    type              = optional(string, "user")  # "administrator" or "user" (Windows group)
    connectivity_type = optional(string, "public")  # "public" or "private" (network access)
    tags              = optional(map(string), {})
  }))
  description = <<EOF
Local Windows user accounts with Windows group types and network connectivity (managed via Secrets Manager)

**KEY BECOMES WINDOWS USERNAME**: The map key (e.g., "john-doe") becomes the actual Windows username created on VDI instances.

type options (Windows groups):
- "administrator": User added to Windows Administrators group, created on ALL workstations
- "user": User added to Windows Users group, created only on assigned workstation

connectivity_type options (network access):
- "public": User accesses VDI via public internet (default)
- "private": User accesses VDI via Client VPN (generates VPN config)

Example:
users = {
  "vdiadmin" = {              # ← This key becomes Windows username "vdiadmin"
    given_name = "VDI"
    family_name = "Administrator"
    email = "admin@company.com"
    type = "administrator"      # Windows Administrators group
  }
  "naruto-uzumaki" = {         # ← This key becomes Windows username "naruto-uzumaki"
    given_name = "Naruto"
    family_name = "Uzumaki"
    email = "naruto@konoha.com"
    type = "user"               # Windows Users group
  }
}

# Referenced by assignments:
workstation_assignments = {
  "vdi-001" = {
    user = "naruto-uzumaki"     # ← Must match users{} key
  }
}
EOF
  default     = {}
  
  validation {
    condition = alltrue([
      for user_key, config in var.users :
      contains(["administrator", "user"], config.type)
    ])
    error_message = "type must be either 'administrator' or 'user' for each user."
  }
  
  validation {
    condition = alltrue([
      for user_key, config in var.users :
      contains(["public", "private"], config.connectivity_type)
    ])
    error_message = "connectivity_type must be either 'public' or 'private' for each user."
  }
  
  validation {
    condition = alltrue([
      for user_key, config in var.users :
      length(trimspace(config.given_name)) > 0 && length(trimspace(config.family_name)) > 0
    ])
    error_message = "given_name and family_name cannot be empty or whitespace-only strings. Both are required for Windows user creation."
  }
}



# 6. WORKSTATION ASSIGNMENTS - Workstation-centric user mapping
variable "workstation_assignments" {
  type = map(object({
    user = string
    tags = optional(map(string), {})
  }))
  description = <<EOF
Workstation assignments mapping workstations to users.

Key must match a workstation key. Maps each workstation to a specific user.

Example:
workstation_assignments = {
  "alice-workstation" = {
    user = "alice"          # References users{} key
  }
  "bob-workstation" = {
    user = "bob-smith"      # References users{} key
  }
}

All users use local Windows accounts with Secrets Manager authentication.
EOF
  default     = {}
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

# Authentication method:
# - Local users → EC2 keys + Secrets Manager
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
# CONNECTIVITY CONFIGURATION
########################################

variable "connectivity_type" {
  type        = string
  description = "VDI connectivity type: 'public' for internet access, 'private' for Client VPN access"
  default     = "public"
  
  validation {
    condition     = contains(["public", "private"], var.connectivity_type)
    error_message = "connectivity_type must be either 'public' or 'private'."
  }
}

variable "enable_private_connectivity" {
  type        = bool
  description = "Enable private connectivity infrastructure (Client VPN endpoint, S3 bucket for configs)"
  default     = false
}

variable "client_vpn_config" {
  type = object({
    client_cidr_block = optional(string, "192.168.0.0/16")
    generate_client_configs = optional(bool, true)
  })
  description = "Client VPN configuration for private connectivity"
  default     = {}
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

variable "debug_force_user_recreation" {
  description = "Enable to force user recreation on every terraform apply (debug only)"
  type        = bool
  default     = false
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
variable "force_user_creation_rerun" {
  description = "Change this value to force SSM user creation to re-run (e.g., after IAM permission fixes)"
  type        = string
  default     = "1"
}