########################################
# General
########################################
variable "name" {
  type        = string
  description = "Name for this workload"
  default     = "unreal-cloud-ddc"
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appended to the beginning of most resource names."
  default     = "cgd"

  validation {
    condition     = length(var.project_prefix) > 1 && length(var.project_prefix) <= 10
    error_message = "The defined 'project_prefix' has too many characters (${length(var.project_prefix)}). This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }

  validation {
    condition     = length("${var.project_prefix}-dev-ddc-nlb-tg-xx") <= 32
    error_message = "project_prefix '${var.project_prefix}' will create target group names longer than 32 characters. Use a shorter prefix (current: ${length(var.project_prefix)} chars, max recommended: ${32 - length("-dev-ddc-nlb-tg-xx")} chars)."
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

  validation {
    condition     = length("cgd-${var.environment}-ddc-nlb-tg-xx") <= 32
    error_message = "environment '${var.environment}' will create target group names longer than 32 characters. Use a shorter name (current: ${length(var.environment)} chars, max recommended: ${32 - length("cgd--ddc-nlb-tg-xx")} chars)."
  }
}

variable "region" {
  type        = string
  description = "AWS region to deploy resources to. If not set, uses the default region from AWS credentials/profile. For multi-region deployments, this MUST be set to a different region than the default to avoid resource conflicts and duplicates."
  default     = null
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

variable "debug" {
  type        = bool
  description = "Enable debug mode for development and testing. When true, forces CodeBuild deployment and testing actions to run on every terraform apply (regardless of configuration changes). When false, actions only run when there are actual changes to configuration, buildspecs, or assets. Use true for development/troubleshooting, false for production."
  default     = false
}





########################################
# Networking
########################################
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
  default     = null

  validation {
    condition     = var.load_balancers_config == null || var.load_balancers_config.nlb == null || length(var.load_balancers_config.nlb.subnets) > 0
    error_message = "At least one NLB subnet must be provided when NLB is configured."
  }
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

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listeners (required for internet-facing services unless debug_mode enabled)"
  default     = null
}

variable "route53_hosted_zone_name" {
  type        = string
  description = "The name of the public Route53 Hosted Zone for DDC resources (e.g., 'yourcompany.com'). Creates region-specific DNS like us-east-1.ddc.yourcompany.com"
  default     = null
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
  default     = ""
}

########################################
# DDC Infrastructure Configuration
########################################
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

    # EKS API Access Configuration (matches AWS provider exactly)
    endpoint_public_access  = optional(bool, true)
    endpoint_private_access = optional(bool, true)
    public_access_cidrs     = optional(list(string), null)

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
      current_region = object({
        datacenter_name    = optional(string, null)
        keyspace_suffix    = optional(string, null)
        replication_factor = optional(number, 3)  # Creates N ScyllaDB instances AND stores N data copies per key. Uses manual EC2 instances with persistent NVMe storage for optimal performance.

      })
      peer_regions = optional(map(object({
        datacenter_name    = optional(string, null)
        replication_factor = optional(number, 2)
      })), null)
      enable_cross_region_replication = optional(bool, true)
      keyspace_naming_strategy        = optional(string, "region_suffix")
      create_seed_node     = optional(bool, true)
      existing_scylla_seed = optional(string, null)
      scylla_source_region = optional(string, null)
      subnets              = optional(list(string), null)
      scylla_ami_name      = optional(string, "ScyllaDB 6.0.1")
      scylla_instance_type = optional(string, "i4i.2xlarge")
      scylla_architecture  = optional(string, "x86_64")
      scylla_db_storage    = optional(number, 100)
      scylla_db_throughput = optional(number, 200)
      scylla_ips_by_region = optional(map(list(string)), null)
    }), null)

    # Kubernetes Configuration
    kubernetes_namespace     = optional(string, "unreal-cloud-ddc")
    kubernetes_service_account_name = optional(string, "unreal-cloud-ddc-sa")

    # Certificate Management
    certificate_manager_hosted_zone_arn = optional(list(string), null)
    enable_certificate_manager          = optional(bool, false)

    # Multi-region IAM role sharing
    eks_cluster_role_arn = optional(string, null)
    eks_node_group_role_arns = optional(object({
      system_role = optional(string, null)
      worker_role = optional(string, null)
      nvme_role   = optional(string, null)
    }), null)
    oidc_provider_arn = optional(string, null)
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
    condition     = var.ddc_infra_config == null || var.ddc_infra_config.scylla_config == null || contains(["region_suffix", "datacenter_suffix"], var.ddc_infra_config.scylla_config.keyspace_naming_strategy)
    error_message = "keyspace_naming_strategy must be 'region_suffix' or 'datacenter_suffix'."
  }
}

########################################
# DDC Application Configuration
########################################
variable "ddc_application_config" {
  type = object({
    # DDC Logical Namespaces (→ Helm template)
    default_ddc_namespace = optional(string, "default")
    ddc_namespaces = optional(map(object({
      description = optional(string, null)
      regions = optional(list(string), null)  # List of regions for speculative (bidirectional) replication
    })), null)
    
    # Main Pod Resources (→ Helm template)
    instance_type    = optional(string, "i4i.xlarge")
    cpu_requests     = optional(string, "2000m")
    memory_requests  = optional(string, "8Gi")
    replica_count    = optional(number, 2)
    
    # DDC Application Config (→ Helm template)
    ddc_access_group     = optional(string, "app-cloud-ddc-project")
    ddc_admin_group      = optional(string, "cloud-ddc-admin")
    container_image = optional(string, "ghcr.io/epicgames/unreal-cloud-ddc:1.2.0")
    helm_chart = optional(string, "oci://ghcr.io/epicgames/unreal-cloud-ddc:1.2.0+helm")

    worker_cpu_requests  = optional(string, "1000m")
    worker_memory_requests = optional(string, "4Gi")
    
    # Authentication (→ Terraform only)
    bearer_token_secret_arn = optional(string, null)
    
    # Multi-Region Replication (→ Terraform + Helm template)
    enable_multi_region_replication = optional(bool, false)
    replication_mode = optional(string, "speculative")  # "speculative" (push), "on-demand" (pull), "hybrid" (both)
    
    # Deployment Orchestration (→ Terraform only)
    cluster_ready_timeout_minutes = optional(number, 10)
    enable_single_region_validation = optional(bool, true)
    single_region_validation_timeout_minutes = optional(number, 5)
    enable_multi_region_validation = optional(bool, false)
    peer_region_ddc_endpoint = optional(string, null)
    multi_region_validation_timeout_minutes = optional(number, 3)
  })
  description = <<EOT
DDC application configuration with flattened structure:

## DDC Logical Namespaces (→ Helm template)
- `default_ddc_namespace`: Fallback namespace for testing
- `ddc_namespaces`: Map of game project namespaces

## Main Pod Resources (→ Helm template)
- `instance_type`: EC2 instance type (m6i.xlarge, i4i.xlarge, c6a.xlarge, etc.)
- `cpu_requests`: CPU per pod ("2000m" = 2 cores)
- `memory_requests`: Memory per pod ("8Gi" = 8GB)
- `replica_count`: Number of DDC pods (independent of ScyllaDB nodes)

## DDC Application Config (→ Helm template)
- `ddc_access_group`: JWT group for basic access
- `ddc_admin_group`: JWT group for admin access
- `container_image`: Docker image URL
- `helm_chart`: Helm chart to deploy (defaults to Epic's official chart)
- `worker_cpu_requests`: CPU for worker pods
- `worker_memory_requests`: Memory for worker pods

## Authentication (→ Terraform only)
- `bearer_token_secret_arn`: AWS Secrets Manager ARN

## Multi-Region Replication (→ Terraform + Helm template)
- `enable_multi_region_replication`: Enable cross-region data replication
- `replication_mode`: Replication strategy selection:
  * "speculative" (default): Proactively pushes new data to peer regions for lowest latency. Best for active multi-region development teams.
  * "on-demand": Pulls missing data from peer regions only when requested. Best for cost optimization with occasional cross-region access.
  * "hybrid": Combines both strategies for maximum performance and reliability. Best for production environments with mixed usage patterns.

## Deployment Orchestration (→ Terraform only)
- `cluster_ready_timeout_minutes`: Wait time for EKS nodes
- `enable_single_region_validation`: Run DDC tests after deploy
- `single_region_validation_timeout_minutes`: Test timeout
- `enable_multi_region_validation`: Run cross-region tests
- `peer_region_ddc_endpoint`: Other region endpoint for tests
- `multi_region_validation_timeout_minutes`: Cross-region test timeout
EOT

  default = null

  validation {
    condition = (
      !var.ddc_application_config.enable_multi_region_validation ||
      var.ddc_application_config.peer_region_ddc_endpoint != null
    )
    error_message = "peer_region_ddc_endpoint is required when enable_multi_region_validation = true."
  }

  validation {
    condition = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.ddc_application_config.instance_type))
    error_message = "instance_type must be a valid EC2 instance type format (e.g., m6i.xlarge, i4i.xlarge). This value goes into Helm templates and EKS Auto Mode nodeSelector - invalid types cause pod scheduling failures."
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

variable "ghcr_credentials_secret_arn" {
  type        = string
  description = "ARN of AWS Secrets Manager secret containing GitHub credentials for Epic Games container registry access. Secret must contain 'username' and 'accessToken' fields for GHCR authentication."
  default     = null
}



########################################
# Advanced Configuration
########################################
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

variable "eks_access_entries" {
  type = map(object({
    principal_arn = string
    type         = optional(string, "STANDARD")
    policy_associations = optional(list(object({
      policy_arn = string
      access_scope = object({
        type       = string
        namespaces = optional(list(string))
      })
    })), [])
  }))
  description = <<EOT
    EKS access entries for granting cluster access to additional IAM principals (ArgoCD, CI/CD, team members).
    
    The cluster creator automatically gets admin access - this is for additional users/services.
    
    Example:
    eks_access_entries = {
      "argocd" = {
        principal_arn = "arn:aws:iam::123456789012:role/ArgoCD-Role"
        policy_associations = [{
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }]
      }
    }
  EOT
  default = {}
}



