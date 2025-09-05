#------------------------------------------------------------------------------
# SHARED CONFIGURATION (Always at top)
#------------------------------------------------------------------------------

variable "region" {
  type        = string
  description = "AWS region to deploy resources to. If not set, uses the default region from AWS credentials/profile. For multi-region deployments, this MUST be set to a different region than the default to avoid resource conflicts and duplicates."
  default     = null
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appended to the beginning of most resource names."
  default     = "cgd"

  validation {
    condition     = length(var.project_prefix) > 1 && length(var.project_prefix) <= 10
    error_message = "The defined 'project_prefix' has too many characters (${length(var.project_prefix)}). This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
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

variable "debug_mode" {
  type        = string
  description = "Debug mode for development and troubleshooting. 'enabled' allows additional debug features including HTTP access. 'disabled' enforces production security settings."
  default     = "disabled"

  validation {
    condition     = contains(["enabled", "disabled"], var.debug_mode)
    error_message = "debug_mode must be either 'enabled' or 'disabled'."
  }
}

variable "environment" {
  type        = string
  description = "Environment name for deployment (dev, staging, prod, etc.)"
  default     = "dev"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment must contain only lowercase letters, numbers, and hyphens."
  }
}











#------------------------------------------------------------------------------
# TIER 1: CORE INFRASTRUCTURE (Required, no defaults)
#------------------------------------------------------------------------------

variable "vpc_id" {
  type        = string
  description = "VPC ID where resources will be created"
}



variable "load_balancers_config" {
  type = object({
    nlb = optional(object({
      internet_facing = optional(bool, true)
      subnets         = list(string)
      security_groups = optional(list(string), [])
    }), null)
  })
  description = "Load balancers configuration. Supports conditional creation based on presence. Currently implemented: NLB (Network Load Balancer). Future: ALB, GLB can be added to this structure."

  validation {
    condition     = var.load_balancers_config.nlb == null || length(var.load_balancers_config.nlb.subnets) > 0
    error_message = "At least one NLB subnet must be provided when NLB is configured."
  }
}



#------------------------------------------------------------------------------
# TIER 2: OPTIONAL CONFIGURATION (Common use cases, with defaults)
#------------------------------------------------------------------------------



variable "route53_hosted_zone_name" {
  type        = string
  description = "The name of the public Route53 Hosted Zone for DDC resources (e.g., 'yourcompany.com'). Creates region-specific DNS like us-east-1.ddc.yourcompany.com"
  default     = null
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listeners (required for internet-facing services unless debug_mode enabled)"
  default     = null
}

variable "allowed_external_cidrs" {
  type        = list(string)
  description = "CIDR blocks for external access. Use prefix lists for multiple IPs."
  default     = null

  validation {
    condition     = var.allowed_external_cidrs == null || !contains(var.allowed_external_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 not allowed for ingress. Specify actual CIDR blocks or use prefix lists."
  }
}

variable "external_prefix_list_id" {
  type        = string
  description = "Managed prefix list ID for external access (recommended for multiple IPs)"
  default     = null
}



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

#------------------------------------------------------------------------------
# TIER 3: ADVANCED CONFIGURATION (Complex configurations)
#------------------------------------------------------------------------------

variable "additional_vpc_associations" {
  type = map(object({
    vpc_id = string
    region = string
  }))
  description = "Additional VPCs to associate with private zone (for cross-region access)"
  default     = null
}

variable "is_primary_region" {
  type        = bool
  description = "Whether this is the primary region (for future use)"
  default     = true
}

variable "create_private_dns_records" {
  type        = bool
  description = "Create private DNS records (set to false for secondary regions to avoid conflicts)"
  default     = true
}



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
    Unreal Cloud DDC application configuration including namespaces and authentication.

    # Namespaces (Map of Objects)
    namespaces: Map where key = namespace name, value = configuration

    Example:
    namespaces = {
      "civ" = {
        description = "The Civilization series"
        prevent_deletion = true
      }
      "kingdom-hearts-2" = {
        description = "Kingdom Hearts 2 franchise"
        prevent_deletion = true
      }
      "journey" = {
        description = "Journey game development"
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
  default     = null
}

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
    max_attempts           = 20
    retry_interval_seconds = 30
    initial_delay_seconds  = 60
  }

  validation {
    condition     = var.ssm_retry_config.max_attempts > 0 && var.ssm_retry_config.max_attempts <= 50
    error_message = "max_attempts must be between 1 and 50"
  }

  validation {
    condition     = var.ssm_retry_config.retry_interval_seconds >= 10 && var.ssm_retry_config.retry_interval_seconds <= 300
    error_message = "retry_interval_seconds must be between 10 and 300 seconds"
  }
}

variable "ddc_infra_config" {
  type = object({
    # General Configuration
    name           = optional(string, "unreal-cloud-ddc")
    project_prefix = optional(string, "cgd")
    environment    = optional(string, "dev")
    region         = optional(string, null)

    # EKS Cluster Configuration
    kubernetes_version     = optional(string, "1.33")
    eks_node_group_subnets = optional(list(string), [])

    # EKS API Access Configuration
    eks_access_config = optional(object({
      # Access mode: private, public, or hybrid
      mode = optional(string, "hybrid")

      # Public access configuration (required for public/hybrid)
      public = optional(object({
        enabled        = optional(bool, true)
        allowed_cidrs  = list(string)
        prefix_list_id = optional(string, null)
      }), null)

      # Private access configuration (required for private/hybrid)
      private = optional(object({
        enabled         = optional(bool, true)
        security_groups = list(string)
      }), null)
      }), {
      mode    = "hybrid"
      public  = null
      private = null
    })

    # NVME Node Group
    nvme_managed_node_instance_type = optional(string, "i3en.large")
    nvme_managed_node_desired_size  = optional(number, 2)
    nvme_managed_node_max_size      = optional(number, 2)
    nvme_managed_node_min_size      = optional(number, 1)

    # Worker Node Group
    worker_managed_node_instance_type = optional(string, "c5.large")
    worker_managed_node_desired_size  = optional(number, 1)
    worker_managed_node_max_size      = optional(number, 1)
    worker_managed_node_min_size      = optional(number, 0)

    # System Node Group
    system_managed_node_instance_type = optional(string, "m5.large")
    system_managed_node_desired_size  = optional(number, 1)
    system_managed_node_max_size      = optional(number, 2)
    system_managed_node_min_size      = optional(number, 1)

    # ScyllaDB Configuration
    scylla_config = optional(object({
      # Current region configuration
      current_region = object({
        datacenter_name    = optional(string, null) # Auto-generated from region if null
        keyspace_suffix    = optional(string, null) # Auto-generated from region if null
        replication_factor = optional(number, 3)
        node_count         = optional(number, 3)
      })

      # Multi-region peer configuration (for replication setup)
      peer_regions = optional(map(object({
        datacenter_name    = optional(string, null) # Auto-generated from region if null
        replication_factor = optional(number, 2)
      })), {})

      # Advanced options
      enable_cross_region_replication = optional(bool, true)
      keyspace_naming_strategy        = optional(string, "region_suffix") # "region_suffix" or "datacenter_suffix"

      # Infrastructure settings
      create_seed_node     = optional(bool, true)
      existing_scylla_seed = optional(string, null)
      scylla_source_region = optional(string, null)
      subnets              = optional(list(string), [])
      scylla_ami_name      = optional(string, "ScyllaDB 6.0.1")
      scylla_instance_type = optional(string, "i4i.2xlarge")
      scylla_architecture  = optional(string, "x86_64")
      scylla_db_storage    = optional(number, 100)
      scylla_db_throughput = optional(number, 200)
      scylla_ips_by_region = optional(map(list(string)), {})
    }), null)

    # Kubernetes Configuration
    unreal_cloud_ddc_namespace            = optional(string, "unreal-cloud-ddc")
    unreal_cloud_ddc_service_account_name = optional(string, "unreal-cloud-ddc-sa")

    # Certificate Management
    certificate_manager_hosted_zone_arn = optional(list(string), [])
    enable_certificate_manager          = optional(bool, false)


  })
  description = <<EOT
    Configuration object for DDC infrastructure (EKS, ScyllaDB, NLB, Kubernetes resources). 
    Set to null to skip creating infrastructure.
    
    All infrastructure settings are grouped here for clear submodule alignment:
    - EKS cluster configuration and access patterns
    - ScyllaDB database configuration and multi-region setup
    - Node group configurations
    - Kubernetes namespace and service account settings
    
    This entire object gets passed to the ddc_infra submodule.
  EOT
  default     = null

  validation {
    condition     = var.ddc_infra_config == null || var.ddc_infra_config.scylla_config == null || contains(["arm64", "x86_64"], var.ddc_infra_config.scylla_config.scylla_architecture)
    error_message = "The ddc_infra_config.scylla_config.scylla_architecture variable must be either 'arm64' or 'x86_64'."
  }

  validation {
    condition     = var.ddc_infra_config == null || var.ddc_infra_config.scylla_config == null || contains(["i8g", "i7ie", "i4g", "i4i", "im4gn", "is4gen", "i4i", "i3", "i3en"], split(".", var.ddc_infra_config.scylla_config.scylla_instance_type)[0])
    error_message = "Must be an instance family that contains NVME"
  }

  validation {
    condition     = var.ddc_infra_config == null || var.ddc_infra_config.scylla_config == null || var.ddc_infra_config.scylla_config.current_region.replication_factor <= var.ddc_infra_config.scylla_config.current_region.node_count
    error_message = "Replication factor cannot exceed node count in current region."
  }

  validation {
    condition     = var.ddc_infra_config == null || var.ddc_infra_config.scylla_config == null || contains(["region_suffix", "datacenter_suffix"], var.ddc_infra_config.scylla_config.keyspace_naming_strategy)
    error_message = "keyspace_naming_strategy must be 'region_suffix' or 'datacenter_suffix'."
  }
}

variable "vpc_endpoints" {
  type = object({
    # EKS API endpoint (eliminates proxy NLB complexity)
    eks = optional(object({
      enabled = bool
    }), null)
    
    # S3 Gateway endpoint (for DDC S3 bucket access)
    s3 = optional(object({
      enabled         = bool
      route_table_ids = list(string) # Required for Gateway endpoint
    }), null)
    
    # CloudWatch Logs endpoint (for log shipping)
    logs = optional(object({
      enabled = bool
    }), null)
    
    # Secrets Manager endpoint (for bearer token access)
    secretsmanager = optional(object({
      enabled = bool
    }), null)
    
    # SSM endpoint (for ScyllaDB automation)
    ssm = optional(object({
      enabled = bool
    }), null)
  })
  
  description = <<-EOT
    VPC endpoints configuration for private AWS API access.
    
    When enabled, eliminates need for internet egress and proxy infrastructure.
    Each service can be enabled individually or reference existing endpoints.
    
    ## EKS Endpoint Benefits:
    - Eliminates complex proxy NLB infrastructure (~$16/month → ~$7/month)
    - True private access - no internet egress required
    - Simplified security model
    - Better performance - direct API access
    
    ## Example:
    vpc_endpoints = {
      eks = {
        enabled = true  # Replaces proxy NLB automatically
      }
    }
    
    ## Supported Endpoints:
    - eks: EKS API access (primary focus)
    - ecr_api: ECR API calls
    - ecr_dkr: ECR Docker registry
    - s3: S3 API calls (Gateway endpoint)
  EOT
  
  default = null

  validation {
    condition = var.vpc_endpoints == null ? true : (
      var.vpc_endpoints.s3 == null || !var.vpc_endpoints.s3.enabled || length(var.vpc_endpoints.s3.route_table_ids) > 0
    )
    error_message = "S3 Gateway endpoint requires route_table_ids when enabled."
  }

  # Validate EKS VPC endpoint doesn't conflict with public access patterns
  validation {
    condition = (
      var.vpc_endpoints == null || 
      var.vpc_endpoints.eks == null ||
      !var.vpc_endpoints.eks.enabled ||
      var.ddc_infra_config == null ||
      var.ddc_infra_config.eks_access_config == null ||
      var.ddc_infra_config.eks_access_config.mode == "private" ||
      (
        var.ddc_infra_config.eks_access_config.mode == "hybrid" &&
        var.ddc_infra_config.eks_access_config.public == null
      )
    )
    error_message = <<-EOT
      EKS VPC endpoint conflicts with public access configuration.
      
      When vpc_endpoints.eks.enabled = true:
      - Use eks_access_config.mode = "private" for VPC-only access
      - OR use eks_access_config.mode = "hybrid" with public = null
      
      VPC endpoints provide private access within VPC, making public CIDR restrictions unnecessary.
      For internet access, set vpc_endpoints.eks.enabled = false and use allowed_cidrs instead.
    EOT
  }
}

variable "ddc_app_config" {
  type = object({
    # General Configuration
    name           = optional(string, "unreal-cloud-ddc")
    project_prefix = optional(string, "cgd")
    region         = optional(string, "us-west-2")

    # Application Settings
    unreal_cloud_ddc_version = optional(string, "1.2.0")

    # Multi-region Configuration
    ddc_replication_region_url = optional(string, null)

    # Credentials
    ghcr_credentials_secret_manager_arn = string
    oidc_credentials_secret_manager_arn = optional(string, null)
  })
  description = "Configuration object for DDC application deployment (Helm charts, Kubernetes resources). Set to null to skip deploying application."
  default     = null

  validation {
    condition     = var.ddc_app_config == null || length(regexall("ecr-pullthroughcache/", var.ddc_app_config.ghcr_credentials_secret_manager_arn)) > 0
    error_message = "CRITICAL: ghcr_credentials_secret_manager_arn MUST be prefixed with EXACTLY 'ecr-pullthroughcache/' AND have something after the slash."
  }

  validation {
    condition     = var.ddc_app_config == null || can(regex("ecr-pullthroughcache/[a-zA-Z0-9-_]*", var.ddc_app_config.ghcr_credentials_secret_manager_arn))
    error_message = "ECR pull-through cache secret name must follow pattern 'ecr-pullthroughcache/[name]'."
  }
}