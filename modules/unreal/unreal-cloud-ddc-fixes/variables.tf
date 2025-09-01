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

variable "access_method" {
  type = string
  description = "external/public: Internet → Public NLB | internal/private: VPC → Private NLB"
  default = "external"
  
  validation {
    condition = contains(["external", "internal", "public", "private"], var.access_method)
    error_message = "Must be 'external'/'public' or 'internal'/'private'"
  }
  
  validation {
    condition = (
      contains(["external", "public"], var.access_method) && length(var.public_subnets) > 0 && length(var.private_subnets) > 0
    ) || (
      contains(["internal", "private"], var.access_method) && length(var.private_subnets) > 0
    )
    error_message = "private_subnets always required for services. For external/public access, both public_subnets and private_subnets must be provided. For internal/private access, only private_subnets required."
  }
}



########################################
# Networking
########################################
variable "vpc_id" {
  description = "VPC ID for this region"
  type        = string
}

variable "region" {
  description = "AWS region to deploy resources to. If not set, uses the default region from AWS credentials/profile. For multi-region deployments, this MUST be set to a different region than the default to avoid resource conflicts and duplicates."
  type        = string
  default     = null
}

variable "public_subnets" {
  type = list(string)
  description = "Public subnet IDs for external load balancers"
  default = []
}

variable "private_subnets" {
  type = list(string)
  description = "Private subnet IDs for internal load balancers and services"
  default = []
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
variable "enable_centralized_logging" {
  type = bool
  description = "Enable centralized logging for all DDC services (NLB, ScyllaDB, applications)"
  default = true
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

# Removed centralized_logs_bucket variable - always create our own bucket with proper permissions

variable "log_retention_by_category" {
  type = object({
    infrastructure = optional(number, 90)   # NLB, ALB, EKS logs - longer for troubleshooting
    application    = optional(number, 30)   # DDC app logs - shorter for cost
    service        = optional(number, 60)   # ScyllaDB logs - medium for analysis
  })
  description = "CloudWatch log retention in days by category"
  default = {}
  
  validation {
    condition = alltrue([
      contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_by_category.infrastructure),
      contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_by_category.application),
      contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_by_category.service)
    ])
    error_message = "All retention values must be valid CloudWatch retention periods: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653 days."
  }
}

variable "log_group_prefix" {
  type = string
  description = "CloudWatch log group prefix following /cgd/{module} pattern"
  default = "/cgd/ddc"
}





########################################
# Bearer Token Configuration
########################################
variable "ddc_bearer_token_secret_arn" {
  description = "ARN of existing DDC bearer token secret. If null, will create new token."
  type        = string
  default     = null
}

variable "existing_security_groups" {
  type        = list(string)
  description = <<EOT
    GLOBAL ACCESS: Security group IDs that provide access to DDC load balancers (NLB).
    
    Use this for:
    - General user access (your IP, office network)
    - Shared access across all DDC services
    
    Security Flow:
    User → existing_security_groups → All Load Balancers → DDC Services
    
    Example: [aws_security_group.allow_my_ip.id]
  EOT
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
    debug          = optional(bool, false)
    create_seed_node = optional(bool, true)
    existing_scylla_seed = optional(string, null)
    scylla_source_region = optional(string, null)

    # EKS Configuration
    kubernetes_version      = optional(string, "1.31")
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
    unreal_cloud_ddc_helm_values         = optional(list(string), [])
    
    # Multi-region replication
    ddc_replication_region_url = optional(string, null)
    
    # Cleanup Configuration
    auto_cleanup = optional(bool, true)

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
variable "route53_public_hosted_zone_name" {
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

variable "certificate_arn" {
  type = string
  description = "ACM certificate ARN for HTTPS listeners (created at example level)"
  default = null
}



########################################
# Tags
########################################
variable "helm_cleanup_timeout" {
  description = "Timeout in seconds for Helm cleanup during destroy operations"
  type        = number
  default     = 300
}

variable "auto_helm_cleanup" {
  description = "Automatically clean up Helm releases during destroy to prevent orphaned AWS resources. If false, manual cleanup required."
  type        = bool
  default     = true
}

variable "enable_deployment_messages" {
  description = "Enable informational messages during Terraform operations"
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
    "ModuleName"     = "terraform-aws-unreal-cloud-ddc"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc"
  }
}