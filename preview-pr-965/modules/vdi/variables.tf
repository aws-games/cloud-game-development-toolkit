variable "project_prefix" {
  type        = string
  description = "Prefix for resource names"
  default     = "cgd"
}

variable "debug" {
  type        = bool
  description = "Enable debug mode. When true, disables termination protection for CI/CD environments. When false, enables termination protection for production environments."
  default     = false
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


variable "presets" {
  type = map(object({
    # Core compute configuration
    instance_type = string
    ami           = optional(string, null)

    # Hardware configuration
    gpu_enabled = optional(bool, true)

    # Named volumes with auto-assigned drive letters
    volumes = map(object({
      capacity   = number
      type       = string
      iops       = optional(number, 3000)
      throughput = optional(number, 125)
      encrypted  = optional(bool, true)
    }))

    # Optional configuration
    iam_instance_profile   = optional(string, null)
    additional_policy_arns = optional(list(string), []) # Additional IAM policy ARNs to attach to the VDI instance role
    software_packages      = optional(list(string), null)
    tags                   = optional(map(string), {})
  }))

  description = <<EOF
Configuration blueprints defining instance types and named volumes with Windows drive mapping.

**KEY BECOMES PRESET NAME**: The map key (e.g., "ue-developer") becomes the preset name referenced by workstations.

Presets provide reusable configurations that can be referenced by multiple workstations via preset_key.

Example:
presets = {
  "ue-developer" = {           # ← This key becomes the preset name
    instance_type = "g4dn.2xlarge"
    gpu_enabled   = true
    volumes = {
      Root = { capacity = 256, type = "gp3" }  # Root volume automatically gets C:
      Projects = { capacity = 1024, type = "gp3", windows_drive = "Z:" }  # Specify drive letter
      Cache = { capacity = 500, type = "gp3" }  # Auto-assigned high-alphabet letter (Y:, X:, etc.)
    }
  }
  "basic-workstation" = {      # ← Another preset name
    instance_type = "g4dn.xlarge"
    gpu_enabled   = true
    volumes = {
      Root = { capacity = 200, type = "gp3" }  # Root volume automatically gets C:
      UserData = { capacity = 500, type = "gp3" }  # Auto-assigned high-alphabet letter
    }
  }
}

# Referenced by workstations:
workstations = {
  "alice-ws" = {
    preset_key = "ue-developer"      # ← References preset by key
  }
}

Valid volume types: "gp2", "gp3", "io1", "io2"
Drive letters are auto-assigned by Windows (typically C: for root, D:, E:, F:, etc. for additional volumes).

additional_policy_arns: List of additional IAM policy ARNs to attach to the VDI instance role.
Example: ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess", "arn:aws:iam::123456789012:policy/MyCustomPolicy"]
EOF
  default     = {}

  validation {
    condition = alltrue([
      for preset_key, config in var.presets :
      alltrue([
        for volume_name, volume in config.volumes :
        contains(["gp2", "gp3", "io1", "io2"], volume.type)
      ])
    ])
    error_message = "All volume types must be one of: gp2, gp3, io1, io2."
  }

  validation {
    condition = alltrue([
      for preset_key, config in var.presets :
      alltrue([
        for volume_name, volume in config.volumes :
        volume.capacity >= 30 && volume.capacity <= 16384
      ])
    ])
    error_message = "All volume capacities must be between 30 and 16384 GiB."
  }

  validation {
    condition = alltrue([
      for preset_key, config in var.presets :
      length([for volume_name, volume in config.volumes : volume_name if lower(volume_name) == "root"]) <= 1
    ])
    error_message = "Only one root volume is allowed per preset. The root volume is automatically assigned C: by AWS."
  }

  validation {
    condition = alltrue([
      for preset_key, config in var.presets :
      config.ami != null
    ])
    error_message = "AMI must be specified for all templates. Use data sources or direct AMI IDs."
  }
}

variable "workstations" {
  type = map(object({
    # Preset reference (optional - can use direct config instead)
    preset_key = optional(string, null)

    # Infrastructure placement
    subnet_id       = string
    security_groups = list(string)
    assigned_user   = optional(string, null) # User assigned to this workstation (for administrator/user types only)

    # Direct configuration (used when preset_key is null or as overrides)
    ami           = optional(string, null)
    instance_type = optional(string, null)
    gpu_enabled   = optional(bool, null)
    volumes = optional(map(object({
      capacity   = number
      type       = string
      iops       = optional(number, 3000)
      throughput = optional(number, 125)
      encrypted  = optional(bool, true)
    })), null)
    iam_instance_profile   = optional(string, null)
    additional_policy_arns = optional(list(string), []) # Additional IAM policy ARNs to attach to the VDI instance role
    software_packages      = optional(list(string), null)

    # Optional overrides
    allowed_cidr_blocks             = optional(list(string), null)
    capacity_reservation_preference = optional(string, null)
    tags                            = optional(map(string), null)
  }))

  description = <<EOF
Physical infrastructure instances with template references and placement configuration.

**KEY BECOMES WORKSTATION NAME**: The map key (e.g., "alice-workstation") becomes the workstation identifier used throughout the module.

Workstations inherit configuration from templates via preset_key reference.

Example:
workstations = {
  # Public connectivity - user accesses via internet
  "alice-workstation" = {
    preset_key = "ue-developer"
    subnet_id = "subnet-public-123"     # Public subnet
    security_groups = ["sg-vdi-public"]
    assigned_user = "alice"
    allowed_cidr_blocks = ["203.0.113.1/32"]  # Alice's home IP
  }
  # Private connectivity - user accesses via VPN
  "bob-workstation" = {
    preset_key = "basic-workstation"
    subnet_id = "subnet-private-456"    # Private subnet
    security_groups = ["sg-vdi-private"]
    assigned_user = "bob"
    # No allowed_cidr_blocks - accessed via Client VPN
  }
  # Additional volumes at workstation level
  "dev-workstation" = {
    preset_key = "basic-workstation"
    subnet_id = "subnet-private-789"
    security_groups = ["sg-vdi-private"]
    volumes = {
      ExtraStorage = { capacity = 2000, type = "gp3", windows_drive = "Y:" }
    }
  }
}

# User assignment is now direct:
# assigned_user = "alice"  # References users{} key directly in workstation

Drive letters are auto-assigned by Windows. Users can reassign them via Disk Management if needed.

additional_policy_arns: List of additional IAM policy ARNs to attach to the VDI instance role.
Example: ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess", "arn:aws:iam::123456789012:policy/MyCustomPolicy"]
EOF
  default     = {}

  validation {
    condition = alltrue([
      for workstation_key, config in var.workstations :
      config.preset_key != null ? contains(keys(var.presets), config.preset_key) : true
    ])
    error_message = "When preset_key is specified, it must reference an existing preset."
  }

  validation {
    condition = alltrue([
      for workstation_key, config in var.workstations :
      config.preset_key == null ? (
        config.ami != null && config.instance_type != null && config.volumes != null
      ) : true
    ])
    error_message = "When preset_key is null, ami, instance_type, and volumes must be specified directly."
  }

  validation {
    condition = alltrue([
      for workstation_key, config in var.workstations :
      config.assigned_user != null ? contains(keys(var.users), config.assigned_user) : true
    ])
    error_message = "When assigned_user is specified, it must reference an existing user key (case-sensitive). Example: assigned_user = \"john-doe\" must match a key in users = { \"john-doe\" = {...} }"
  }

  validation {
    condition = alltrue([
      for workstation_key, config in var.workstations :
      config.capacity_reservation_preference == null || contains(["open", "none"], config.capacity_reservation_preference)
    ])
    error_message = "capacity_reservation_preference must be null, 'open', or 'none' for each workstation."
  }



  validation {
    condition = alltrue([
      for workstation_key, config in var.workstations :
      config.volumes == null || length([for volume_name, volume in config.volumes : volume_name if lower(volume_name) == "root"]) <= 1
    ])
    error_message = "Only one root volume is allowed per workstation. The root volume is automatically assigned C: by AWS."
  }

  validation {
    condition = alltrue([
      for workstation_key, config in var.workstations :
      config.preset_key == null || config.volumes == null || (
        length([for volume_name, volume in config.volumes : volume_name if lower(volume_name) == "root"]) == 0 ||
        length([for volume_name, volume in var.presets[config.preset_key].volumes : volume_name if lower(volume_name) == "root"]) == 0
      )
    ])
    error_message = "Cannot define root volume in both preset and workstation. Root volume should be defined in either preset OR workstation, not both."
  }










}


variable "users" {
  type = map(object({
    given_name     = string
    family_name    = string
    email          = string
    type           = optional(string, "user") # "administrator" or "user" (Windows group)
    use_client_vpn = optional(bool, false)    # Whether this user connects via module's Client VPN
    tags           = optional(map(string), {})
  }))
  description = <<EOF
Local Windows user accounts with Windows group types and network connectivity (managed via Secrets Manager)

**KEY BECOMES WINDOWS USERNAME**: The map key (e.g., "john-doe") becomes the actual Windows username created on VDI instances.

type options (Windows groups):
- "fleet_administrator": User added to Windows Administrators group, created on ALL workstations (fleet management)
- "administrator": User added to Windows Administrators group, created only on assigned workstation
- "user": User added to Windows Users group, created only on assigned workstation

use_client_vpn options (VPN access):
- false: User accesses VDI via public internet or external VPN (default)
- true: User accesses VDI via module's Client VPN (generates VPN config)

Example:
users = {
  "vdiadmin" = {              # ← This key becomes Windows username "vdiadmin"
    given_name = "VDI"
    family_name = "Administrator"
    email = "admin@example.com"
    type = "fleet_administrator" # Windows Administrators group on ALL workstations
    use_client_vpn = false      # Accesses via public internet/external VPN
  }
  "alice" = {                 # ← Public connectivity user
    given_name = "Alice"
    family_name = "Smith"
    email = "alice@example.com"
    type = "user"               # Windows Users group
    use_client_vpn = false      # Accesses via public internet (allowed_cidr_blocks)
  }
  "bob" = {                   # ← Private connectivity user
    given_name = "Bob"
    family_name = "Johnson"
    email = "bob@example.com"
    type = "user"               # Windows Users group
    use_client_vpn = true       # Accesses via module's Client VPN
  }
}

# User assignment is now direct:
# assigned_user = "naruto-uzumaki"  # References users{} key directly in workstation
EOF
  default     = {}

  validation {
    condition = alltrue([
      for user_key, config in var.users :
      contains(["fleet_administrator", "administrator", "user"], config.type)
    ])
    error_message = "type must be 'fleet_administrator', 'administrator', or 'user' for each user."
  }

  validation {
    condition = alltrue([
      for user_key, config in var.users :
      can(config.use_client_vpn) && (config.use_client_vpn == true || config.use_client_vpn == false)
    ])
    error_message = "use_client_vpn must be either true or false for each user."
  }

  validation {
    condition = var.create_client_vpn || !anytrue([
      for user_key, config in var.users :
      config.use_client_vpn == true
    ])
    error_message = "Cannot set use_client_vpn = true for any user when create_client_vpn = false. Either enable create_client_vpn or set all users to use_client_vpn = false."
  }

  validation {
    condition = alltrue([
      for user_key, config in var.users :
      length(trimspace(config.given_name)) > 0 && length(trimspace(config.family_name)) > 0
    ])
    error_message = "given_name and family_name cannot be empty or whitespace-only strings. Both are required for Windows user creation."
  }
}







variable "ebs_kms_key_id" {
  type        = string
  description = "KMS key ID for EBS encryption (if encryption enabled)"
  default     = null
}







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
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch log retention value."
  }
}





variable "create_client_vpn" {
  type        = bool
  description = "Create AWS Client VPN endpoint infrastructure (VPN endpoint, certificates, S3 bucket for configs)"
  default     = false
}

variable "client_vpn_config" {
  type = object({
    client_cidr_block       = optional(string, "192.168.0.0/16")
    generate_client_configs = optional(bool, true)
    split_tunnel            = optional(bool, true)
  })
  description = "Client VPN configuration for private connectivity"
  default     = {}
}



variable "create_default_security_groups" {
  type        = bool
  description = "Create default security groups for VDI workstations"
  default     = true
}



variable "capacity_reservation_preference" {
  description = "Capacity reservation preference for EC2 instances"
  type        = string
  default     = null
  validation {
    condition     = var.capacity_reservation_preference == null || contains(["open", "none"], var.capacity_reservation_preference)
    error_message = "Must be null, 'open', or 'none'."
  }
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
