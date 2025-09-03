########################################
# General
########################################
variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appended to the beginning of most resource names."
  default     = "cgd"

  validation {
    condition     = length(var.project_prefix) > 1 && length(var.project_prefix) <= 10
    error_message = "The defined 'project_prefix' has too many characters (${length(var.project_prefix)}). This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}

variable "internet_facing" {
  type        = bool
  description = "Whether load balancers should be internet-facing (true) or internal (false)"
  default     = true
}



########################################
# Networking
########################################
variable "existing_vpc_id" {
  type        = string
  description = "VPC ID where resources will be created"
}

variable "region" {
  description = "AWS region to deploy resources to. If not set, uses the default region from AWS credentials/profile. For multi-region deployments, this MUST be set to a different region than the default to avoid resource conflicts and duplicates."
  type        = string
  default     = null
}

variable "existing_load_balancer_subnets" {
  type        = list(string)
  description = "Subnets for load balancers (public for internet-facing, private for internal)"
  
  validation {
    condition = length(var.existing_load_balancer_subnets) > 0
    error_message = "At least one load balancer subnet must be provided."
  }
}

variable "existing_service_subnets" {
  type        = list(string)
  description = "Subnets for services (EKS, databases, applications)"
}

variable "allowed_external_cidrs" {
  type = list(string)
  description = "CIDR blocks for external access. Use prefix lists for multiple IPs."
  default = []

  validation {
    condition = !contains(var.allowed_external_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 not allowed for ingress. Specify actual CIDR blocks or use prefix lists."
  }
}

variable "external_prefix_list_id" {
  type = string
  description = "Managed prefix list ID for external access (recommended for multiple IPs)"
  default = null
}

# Note: Always create NLB - tightly coupled to our EKS infrastructure

########################################
# Centralized Logging Configuration (Issue #726)
########################################
variable "centralized_logging" {
  type = object({
    infrastructure = optional(map(object({
      enabled        = optional(bool, true)
      retention_days = optional(number, 90)
    })), {})
    application = optional(map(object({
      enabled        = optional(bool, true)
      retention_days = optional(number, 30)
    })), {})
    service = optional(map(object({
      enabled        = optional(bool, true)
      retention_days = optional(number, 60)
    })), {})
    log_group_prefix = optional(string, null)
  })
  
  description = <<-EOT
    Centralized logging configuration for DDC components by category.
    
    IMPORTANT: This module only supports specific predefined components. Adding unsupported 
    components will result in log groups being created but no actual log shipping configured.
    
    ## Supported Components by Category:
    
    ### infrastructure (AWS managed services):
    - "nlb" - Network Load Balancer access logs → S3 + CloudWatch
    - "eks" - EKS control plane logs → CloudWatch
    
    ### application (Primary business logic):
    - "ddc" - DDC application pod logs → CloudWatch (via Fluent Bit)
    
    ### service (Supporting services):
    - "scylla" - ScyllaDB database logs → CloudWatch (via CloudWatch agent)
    
    ## Structure:
    Log groups follow the pattern: {log_group_prefix}/{category}/{component}
    - Default prefix: "{project_prefix}-{service_name}-{region}"
    - Example: "cgd-unreal-cloud-ddc-us-east-1/infrastructure/nlb"
    
    ## Configuration:
    - enabled: Enable/disable logging for this component (default: true)
    - retention_days: CloudWatch log retention in days (defaults: infra=90, app=30, service=60)
    - log_group_prefix: Custom prefix to replace default naming (optional)
    
    ## Examples:
    
    # Enable all supported components with defaults
    centralized_logging = {
      infrastructure = { nlb = {}, eks = {} }
      application    = { ddc = {} }
      service        = { scylla = {} }
    }
    
    # Custom retention and prefix
    centralized_logging = {
      infrastructure = { 
        nlb = { retention_days = 365 }
        eks = { retention_days = 180 }
      }
      application = { 
        ddc = { retention_days = 14 }
      }
      service = { 
        scylla = { retention_days = 90 }
      }
      log_group_prefix = "mycompany-ddc-prod"
    }
    
    # Disable specific components
    centralized_logging = {
      infrastructure = { 
        nlb = { enabled = false }  # Disable NLB logging
        eks = {}                   # Enable EKS logging
      }
      application = { ddc = {} }
      service     = { scylla = {} }
    }
    
    ## Cost Considerations:
    - Shorter retention = lower costs
    - infrastructure logs (90 days default) - needed for troubleshooting
    - application logs (30 days default) - balance between debugging and cost
    - service logs (60 days default) - database analysis and performance tuning
    
    ## Security:
    All log groups are created with proper IAM permissions and encryption.
    S3 bucket includes lifecycle policies for cost optimization.
  EOT
  
  default = null

  # CRITICAL: Enforce only supported components
  validation {
    condition = var.centralized_logging == null ? true : alltrue([
      # Infrastructure: only nlb, eks allowed
      alltrue([
        for component in keys(var.centralized_logging.infrastructure) :
        contains(["nlb", "eks"], component)
      ]),
      # Application: only ddc allowed
      alltrue([
        for component in keys(var.centralized_logging.application) :
        contains(["ddc"], component)
      ]),
      # Service: only scylla allowed
      alltrue([
        for component in keys(var.centralized_logging.service) :
        contains(["scylla"], component)
      ]),

    ])
    error_message = <<-EOT
      Unsupported logging component specified. Only these components are supported:
      - infrastructure: nlb, eks
      - application: ddc
      - service: scylla
      
      Adding unsupported components will create log groups but no actual log shipping.
      Contact the module maintainers to request support for additional components.
    EOT
  }

  # Validate retention days are valid CloudWatch values
  validation {
    condition = var.centralized_logging == null ? true : alltrue(flatten([
      [for category in ["infrastructure", "application", "service"] :
        [for component, config in var.centralized_logging[category] :
          contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], 
                   try(config.retention_days, category == "infrastructure" ? 90 : category == "application" ? 30 : 60))
        ]
      ]
    ]))
    error_message = "retention_days must be a valid CloudWatch retention period: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653 days."
  }
}

variable "debug_mode" {
  type        = string
  description = "Debug mode for development and troubleshooting. 'enabled' allows additional debug features including HTTP access. 'disabled' enforces production security settings."
  default     = "disabled"

  validation {
    condition     = contains(["enabled", "disabled"], var.debug_mode)
    error_message = "debug_mode must be either 'enabled' or 'disabled'."
  }
}

variable "database_migration_mode" {
  type        = bool
  description = <<-EOT
    Enable database migration mode to temporarily allow both Scylla and Keyspaces configurations during migration.
    
    CRITICAL WARNINGS:
    - Only enable during active database migration
    - Creates both database infrastructures simultaneously (increased costs)
    - Requires manual coordination of database_migration_target
    - Must be disabled after migration completion
    - Not intended for long-term use
    
    MIGRATION PROCESS:
    1. Set database_migration_mode = true, database_migration_target = "scylla"
    2. Apply (creates both databases, DDC stays on Scylla)
    3. Optional: Migrate data manually
    4. Set database_migration_target = "keyspaces"
    5. Apply (switches DDC to Keyspaces)
    6. Remove old database config
    7. Set database_migration_mode = false
  EOT
  default     = false
}

variable "database_migration_target" {
  type        = string
  description = "Target database during migration when both are configured. 'scylla' or 'keyspaces'. Only used when database_migration_mode = true."
  default     = "keyspaces"
  
  validation {
    condition     = contains(["scylla", "keyspaces"], var.database_migration_target)
    error_message = "database_migration_target must be 'scylla' or 'keyspaces'."
  }
}

variable "scylla_config" {
  type = object({
    # Current region configuration
    current_region = object({
      datacenter_name       = optional(string, null)  # Auto-generated from region if null
      keyspace_suffix       = optional(string, null)  # Auto-generated from region if null
      replication_factor    = optional(number, 3)
      node_count           = optional(number, 3)
    })

    # Multi-region peer configuration (for replication setup)
    peer_regions = optional(map(object({
      datacenter_name    = optional(string, null)  # Auto-generated from region if null
      replication_factor = optional(number, 2)
    })), {})

    # Advanced options
    enable_cross_region_replication = optional(bool, true)
    keyspace_naming_strategy       = optional(string, "region_suffix")  # "region_suffix" or "datacenter_suffix"
  })

  description = <<EOT
    ScyllaDB configuration for single and multi-region deployments.

    # Current Region Configuration
    current_region.datacenter_name: ScyllaDB datacenter name (auto-generated: us-east-1 → us-east)
    current_region.keyspace_suffix: Keyspace naming suffix (auto-generated: us-east-1 → us_east_1)
    current_region.replication_factor: Number of data copies in this region (recommended: 3)
    current_region.node_count: Number of ScyllaDB nodes in this region

    # Multi-Region Configuration
    peer_regions: Map of other regions for cross-region replication
    enable_cross_region_replication: Whether to set up cross-region data sync

    # Naming Strategy
    keyspace_naming_strategy: How to name keyspaces
    - "region_suffix": jupiter_local_ddc_us_east_1 (matches cwwalb pattern)
    - "datacenter_suffix": jupiter_local_ddc_us_east
    
    # DDC Keyspace Naming Requirements:
    ScyllaDB keyspaces are auto-generated following DDC conventions:
    - Single region: "jupiter_local_ddc_{region_suffix}" (e.g., "jupiter_local_ddc_us_east_1")
    - Multi-region: Uses replication map with datacenter-specific naming
    - Names are automatically generated based on region and naming strategy

    # Example Single Region:
    scylla_config = {
      current_region = {
        replication_factor = 3
        node_count = 3
      }
    }

    # Example Multi-Region:
    scylla_config = {
      current_region = {
        replication_factor = 3
        node_count = 3
      }
      peer_regions = {
        "us-west-2" = {
          replication_factor = 2
        }
      }
    }
  EOT

  default = null

  validation {
    condition = var.scylla_config == null || var.scylla_config.current_region.replication_factor <= var.scylla_config.current_region.node_count
    error_message = "Replication factor cannot exceed node count in current region."
  }

  validation {
    condition = var.scylla_config == null || contains(["region_suffix", "datacenter_suffix"], var.scylla_config.keyspace_naming_strategy)
    error_message = "keyspace_naming_strategy must be 'region_suffix' or 'datacenter_suffix'."
  }
  
}

variable "amazon_keyspaces_config" {
  type = object({
    # Keyspaces configuration (map allows multiple keyspaces)
    keyspaces = map(object({
      enable_cross_region_replication = optional(bool, false)
      peer_regions = optional(list(string), [])
      point_in_time_recovery = optional(bool, false)
    }))
  })
  
  description = <<EOT
    Amazon Keyspaces configuration supporting multiple keyspaces.
    
    # Keyspaces Configuration
    keyspaces: Map where KEY = ACTUAL KEYSPACE NAME, value = configuration
    - The map key becomes the literal keyspace name in Amazon Keyspaces
    - enable_cross_region_replication: Create global keyspace with multi-region replication
    - peer_regions: List of regions for global table replication
    - point_in_time_recovery: Enable point-in-time recovery for tables
    
    # DDC Keyspace Naming Requirements:
    For DDC compatibility, keyspace names should follow the pattern:
    - Single region: "jupiter_local_ddc_{region_suffix}" (e.g., "jupiter_local_ddc_us_east_1")
    - Multi-region: Same regional naming per region (e.g., "jupiter_local_ddc_us_east_1", "jupiter_local_ddc_us_west_2")
    - Custom names are allowed but may require DDC configuration changes
    
    # Example Single Region with Multiple Keyspaces:
    amazon_keyspaces_config = {
      keyspaces = {
        "jupiter_local_ddc_us_east_1" = {
          point_in_time_recovery = false
        }
        "custom_keyspace" = {
          point_in_time_recovery = true
        }
      }
    }
    
    # Example Multi-Region:
    amazon_keyspaces_config = {
      keyspaces = {
        "jupiter_local_ddc_us_east_1" = {
          enable_cross_region_replication = true
          peer_regions = ["us-west-2"]
          point_in_time_recovery = true
        }
      }
    }
  EOT
  
  default = null
  
  # Allow at least one database backend
  validation {
    condition = var.scylla_config != null || var.amazon_keyspaces_config != null
    error_message = "At least one database backend must be configured: scylla_config or amazon_keyspaces_config."
  }
  
  # Prevent both backends unless in migration mode
  validation {
    condition = !(var.scylla_config != null && var.amazon_keyspaces_config != null) || var.database_migration_mode
    error_message = "Both database backends configured but database_migration_mode = false. To migrate: 1) Set database_migration_mode = true, 2) Add new database config, 3) Apply, 4) Test connectivity, 5) Remove old database config, 6) Set database_migration_mode = false, 7) Apply."
  }
  
  # Validate database sync during migration
  validation {
    condition = !(var.scylla_config != null && var.amazon_keyspaces_config != null && var.database_migration_mode) || (
      # Multi-region settings must match for primary keyspace
      var.scylla_config.enable_cross_region_replication == values(var.amazon_keyspaces_config.keyspaces)[0].enable_cross_region_replication &&
      # Peer regions must match (convert Scylla map keys to list for comparison)
      toset(keys(var.scylla_config.peer_regions)) == toset(values(var.amazon_keyspaces_config.keyspaces)[0].peer_regions) &&
      # Single region must have empty peer regions
      (!var.scylla_config.enable_cross_region_replication ? length(var.scylla_config.peer_regions) == 0 && length(values(var.amazon_keyspaces_config.keyspaces)[0].peer_regions) == 0 : true)
    )
    error_message = "Database configurations must match during migration: enable_cross_region_replication, peer_regions, and single-region settings must be identical between Scylla and Keyspaces configs."
  }
}

########################################
# DDC Application Configuration
########################################
variable "ddc_application_config" {
  type = object({
    namespaces = map(object({
      description      = optional(string, "")
      prevent_deletion = optional(bool, false)
      deletion_policy  = optional(string, "retain") # "retain" or "delete"
    }))
    bearer_token_secret_arn = optional(string, null)
  })
  description = <<EOT
    DDC application configuration including namespaces and authentication.

    # Namespaces (Map of Objects)
    namespaces: Map where key = namespace name, value = configuration

    Example:
    namespaces = {
      "call-of-duty" = {
        description = "Call of Duty franchise"
        prevent_deletion = true
      }
      "overwatch" = {
        description = "Overwatch franchise"
        prevent_deletion = true
      }
      "dev-sandbox" = {
        description = "Development testing"
        deletion_policy = "delete"
      }
    }

    # Authentication
    bearer_token_secret_arn: ARN of existing DDC bearer token secret. If null, creates new token.
  EOT

  default = {
    namespaces = {
      "default" = {
        description = "Default DDC namespace"
      }
    }
  }

  validation {
    condition = alltrue([
      for ns_name, ns_config in var.ddc_application_config.namespaces :
      contains(["retain", "delete"], ns_config.deletion_policy)
    ])
    error_message = "deletion_policy must be 'retain' or 'delete'"
  }
}

variable "create_bearer_token" {
  description = "Create new DDC bearer token secret. Set to false in secondary regions to use existing token from primary region."
  type        = bool
  default     = true
}

variable "bearer_token_replica_regions" {
  type        = list(string)
  description = "List of AWS regions to replicate the bearer token secret to for multi-region access"
  default     = []
}

########################################
# SSM Automation Configuration
########################################
variable "ssm_retry_config" {
  type = object({
    max_attempts           = optional(number, 20)
    retry_interval_seconds = optional(number, 30)
    initial_delay_seconds  = optional(number, 60)
  })
  description = <<EOT
    SSM automation retry configuration for DDC keyspace initialization.

    max_attempts: Maximum retry attempts to check for DDC readiness (default: 20 = 10 minutes)
    retry_interval_seconds: Seconds between retry attempts (default: 30)
    initial_delay_seconds: Initial delay before first check (default: 60)

    Total timeout: initial_delay + (max_attempts * retry_interval)
    Default: 60s + (20 * 30s) = 660s (11 minutes)
  EOT

  default = {
    max_attempts = 20
    retry_interval_seconds = 30
    initial_delay_seconds = 60
  }

  validation {
    condition = var.ssm_retry_config.max_attempts > 0 && var.ssm_retry_config.max_attempts <= 50
    error_message = "max_attempts must be between 1 and 50"
  }

  validation {
    condition = var.ssm_retry_config.retry_interval_seconds >= 10 && var.ssm_retry_config.retry_interval_seconds <= 300
    error_message = "retry_interval_seconds must be between 10 and 300 seconds"
  }
}

variable "existing_security_groups" {
  type        = list(string)
  description = "Security group IDs for general access to public services"
  default     = []
}

variable "existing_load_balancer_security_groups" {
  type        = list(string)
  description = "Additional security group IDs for load balancer access"
  default     = []
}

variable "existing_eks_security_groups" {
  type        = list(string)
  description = "Additional security group IDs for EKS API access"
  default     = []
}

########################################
# DDC Infrastructure Configuration (Conditional)
########################################
variable "ddc_infra_config" {
  type = object({
    # General
    name           = optional(string, "unreal-cloud-ddc")
    project_prefix = optional(string, "cgd")
    environment    = optional(string, "dev")
    region         = optional(string, null)
    # debug is inherited from parent module debug_mode
    create_seed_node = optional(bool, true)
    existing_scylla_seed = optional(string, null)
    scylla_source_region = optional(string, null)

    # EKS Configuration
    kubernetes_version      = optional(string, "1.33")
    eks_node_group_subnets = optional(list(string), [])

    # Node Groups
    nvme_managed_node_instance_type   = optional(string, "i3en.large")
    nvme_managed_node_desired_size    = optional(number, 2)
    nvme_managed_node_max_size        = optional(number, 2)
    nvme_managed_node_min_size        = optional(number, 1)

    worker_managed_node_instance_type = optional(string, "c5.large")
    worker_managed_node_desired_size  = optional(number, 1)
    worker_managed_node_max_size      = optional(number, 1)
    worker_managed_node_min_size      = optional(number, 0)

    system_managed_node_instance_type = optional(string, "m5.large")
    system_managed_node_desired_size  = optional(number, 1)
    system_managed_node_max_size      = optional(number, 2)
    system_managed_node_min_size      = optional(number, 1)

    # ScyllaDB Configuration
    scylla_replication_factor         = optional(number, 3)
    scylla_subnets                    = optional(list(string), [])
    scylla_ami_name                   = optional(string, "ScyllaDB 6.0.1")
    scylla_instance_type              = optional(string, "i4i.2xlarge")
    scylla_architecture               = optional(string, "x86_64")
    scylla_db_storage                 = optional(number, 100)
    scylla_db_throughput              = optional(number, 200)

    # EKS Access Configuration
    eks_api_access_cidrs = optional(list(string), [])
    eks_cluster_public_access               = optional(bool, true)
    eks_cluster_private_access              = optional(bool, true)

    # Kubernetes Configuration
    unreal_cloud_ddc_namespace            = optional(string, "unreal-cloud-ddc")
    unreal_cloud_ddc_service_account_name = optional(string, "unreal-cloud-ddc-sa")

    # Certificate Management
    certificate_manager_hosted_zone_arn = optional(list(string), [])
    enable_certificate_manager          = optional(bool, false)

    # Additional Security Groups (Targeted Access)
    additional_nlb_security_groups = optional(list(string), [])
    additional_eks_security_groups = optional(list(string), [])

    # Multi-region monitoring (from cwwalb branch)
    scylla_ips_by_region = optional(map(list(string)), {})
  })

  # Security Group Access Patterns:
  #
  # GLOBAL ACCESS (existing_security_groups):
  #   User → Global SG → ALL Load Balancers → All Services
  #   Use for: General access, your IP, office network
  #
  # TARGETED ACCESS (additional_*_security_groups):
  #   additional_nlb_security_groups: DDC NLB only (game clients, build systems)
  #   additional_eks_security_groups: EKS cluster only (kubectl, CI/CD, direct service access)

  #
  # Example Usage:
  #   existing_security_groups = [aws_security_group.allow_my_ip.id]  # Everyone gets basic access
  #   additional_nlb_security_groups = [aws_security_group.game_clients.id]  # Game clients get DDC access
  #   additional_eks_security_groups = [aws_security_group.devops_team.id]   # DevOps gets kubectl access

  description = <<EOT
    Configuration object for DDC infrastructure (EKS, ScyllaDB, NLB, Kubernetes resources).
    Set to null to skip creating infrastructure.

    # General
    name: "The string included in the naming of resources related to Unreal Cloud DDC. Default is 'unreal-cloud-ddc'"
    project_prefix: "The project prefix for this workload. This is appended to the beginning of most resource names."
    environment: "The current environment (e.g. dev, prod, etc.)"
    region: "The AWS region to deploy to"
    debug: "Enable debug mode"
    create_seed_node: "Whether this region creates the ScyllaDB seed node (bootstrap node for cluster formation)"
    existing_scylla_seed: "IP of existing ScyllaDB seed node (for secondary regions)"

    # EKS Configuration
    kubernetes_version: "Kubernetes version to be used by the EKS cluster."
    eks_node_group_subnets: "A list of subnets ids you want the EKS nodes to be installed into. Private subnets are strongly recommended."

    # EKS Access Configuration
    eks_cluster_public_access: "Enable public endpoint access to EKS API server. Default: true (allows external Terraform, CI/CD, kubectl access). Set to false for VPN-only environments."
    eks_cluster_private_access: "Enable private endpoint access to EKS API server from within VPC. Default: true (allows internal services, CodeBuild, VPC-based access)."
    eks_api_access_cidrs: "List of CIDR blocks allowed to access the EKS API server for kubectl commands and Terraform operations. This controls WHO can manage the Kubernetes cluster, separate from DDC service access. Examples: ['203.0.113.0/24'] for office network, ['10.0.0.0/8'] for VPN users, or ['1.2.3.4/32'] for specific IP. Empty list blocks ALL public API access. IMPORTANT: This is different from security groups which control DDC service access for game clients."

    # ScyllaDB Configuration
    scylla_replication_factor: "Number of ScyllaDB replicas (3 for primary, 2 for secondary regions)"
    scylla_subnets: "A list of subnet IDs where Scylla will be deployed. Private subnets are strongly recommended."
    scylla_instance_type: "The type and size of the Scylla instance."
    scylla_architecture: "The chip architecture to use when finding the scylla image."
  EOT

  default = null

  validation {
    condition     = var.ddc_infra_config == null || var.ddc_infra_config.scylla_architecture == "arm64" || var.ddc_infra_config.scylla_architecture == "x86_64"
    error_message = "The ddc_infra_config.scylla_architecture variable must be either 'arm64' or 'x86_64'."
  }

  validation {
    condition     = var.ddc_infra_config == null || contains(["i8g", "i7ie", "i4g", "i4i", "im4gn", "is4gen", "i4i", "i3", "i3en"], split(".", var.ddc_infra_config.scylla_instance_type)[0])
    error_message = "Must be an instance family that contains NVME"
  }
}





########################################
# ECR Configuration
########################################
variable "ecr_secret_suffix" {
  type        = string
  description = "Suffix for ECR pull-through cache secret name (after 'ecr-pullthroughcache/'). Defaults to project_prefix-name pattern."
  default     = null
}

########################################
# DDC Services Configuration (Conditional)
########################################
variable "ddc_services_config" {
  type = object({
    # General
    name           = optional(string, "unreal-cloud-ddc")
    project_prefix = optional(string, "cgd")
    region         = optional(string, "us-west-2")

    # Application Settings
    unreal_cloud_ddc_version             = optional(string, "1.2.0")  # HIGHLY RECOMMENDED: Do not change unless testing fixes

    # Multi-region replication
    ddc_replication_region_url = optional(string, null)

    # Cleanup Configuration
    auto_cleanup = optional(bool, true)
    remove_tgb_finalizers = optional(bool, false)

    # Credentials
    ghcr_credentials_secret_manager_arn = string
    oidc_credentials_secret_manager_arn = optional(string, null)
  })

  description = <<EOT
    Configuration object for DDC service components (Helm charts only, no AWS infrastructure).
    Set to null to skip deploying services.

    # General
    name: "The string included in the naming of resources related to Unreal Cloud DDC applications."
    project_prefix: "The project prefix for this workload."

    # Application Settings
    unreal_cloud_ddc_version: "Version of the Unreal Cloud DDC Helm chart. DEFAULT: 1.2.0 (HIGHLY RECOMMENDED). DDC 1.3.0 has known configuration parsing bugs that cause crashes. Only change if testing fixes or newer versions."
    unreal_cloud_ddc_helm_values: "List of YAML files for Unreal Cloud DDC"
    ddc_replication_region_url: "URL of primary region DDC for replication (secondary regions only)"

    # Cleanup Configuration
    auto_cleanup: "Automatically clean up Helm releases during destroy to prevent orphaned AWS resources (ENIs, Load Balancers). If false, manual cleanup required before destroying EKS cluster. Default: true (recommended)."
    remove_tgb_finalizers: "Remove TargetGroupBinding finalizers immediately after creation to enable single-step destroy. When enabled: Allows 'terraform destroy' to complete without manual intervention. When disabled: Requires manual TGB cleanup before destroy. Default: false."

    # Credentials
    ghcr_credentials_secret_manager_arn: "ARN for credentials stored in secret manager. CRITICAL: Secret name MUST be prefixed with EXACTLY 'ecr-pullthroughcache/' AND have something after the slash (e.g., 'ecr-pullthroughcache/UnrealCloudDDC'). AWS will reject secrets named just 'ecr-pullthroughcache/' or with different prefixes."
    oidc_credentials_secret_manager_arn: "ARN for oidc credentials stored in secret manager."
  EOT

  default = null

  validation {
    condition     = var.ddc_services_config == null || length(regexall("ecr-pullthroughcache/", var.ddc_services_config.ghcr_credentials_secret_manager_arn)) > 0
    error_message = "CRITICAL: ghcr_credentials_secret_manager_arn MUST be prefixed with EXACTLY 'ecr-pullthroughcache/' AND have something after the slash. AWS requires this exact format. Example: 'ecr-pullthroughcache/UnrealCloudDDC' or 'ecr-pullthroughcache/github-credentials'. Secrets named just 'ecr-pullthroughcache/' or 'pullthroughcache/something' will be REJECTED by AWS."
  }

  validation {
    condition     = var.ddc_services_config == null || can(regex("ecr-pullthroughcache/[a-zA-Z0-9-_]*", var.ddc_services_config.ghcr_credentials_secret_manager_arn))
    error_message = "ECR pull-through cache secret name must follow pattern 'ecr-pullthroughcache/[name]' where [name] contains only alphanumeric characters, hyphens, and underscores (or can be empty)."
  }
}



########################################
# DNS Configuration
########################################
variable "existing_route53_public_hosted_zone_name" {
  type        = string
  description = "The name of the public Route53 Hosted Zone for DDC resources (e.g., 'yourcompany.com'). Creates region-specific DNS like us-east-1.ddc.yourcompany.com"
  default     = null
}



variable "additional_vpc_associations" {
  type = map(object({
    vpc_id = string
    region = string
  }))
  description = "Additional VPCs to associate with private zone (for cross-region access)"
  default = {}
}

variable "is_primary_region" {
  type = bool
  description = "Whether this is the primary region (for future use)"
  default = true
}

variable "create_private_dns_records" {
  type = bool
  description = "Create private DNS records (set to false for secondary regions to avoid conflicts)"
  default = true
}

variable "existing_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listeners (required for internet-facing services unless debug_mode enabled)"
  default     = null
}



########################################
# Tags
########################################
variable "enable_auto_cleanup" {
  description = "Enable automatic cleanup of all resources during destroy (Helm releases, ECR repos, TGB finalizers)"
  type        = bool
  default     = true
}



variable "auto_cleanup_timeout" {
  description = "Timeout in seconds for auto cleanup operations during destroy (Helm, TGB, etc.)"
  type        = number
  default     = 300
}

variable "auto_cleanup_status_messages" {
  description = "Show progress messages during cleanup operations with [DDC CLEANUP - COMPONENT]: format"
  type        = bool
  default     = true
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "-"
    "ModuleName"     = "terraform-aws-unreal-cloud-ddc"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc"
  }
}
