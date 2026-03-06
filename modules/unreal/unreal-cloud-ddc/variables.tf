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

variable "force_codebuild_run" {
  type        = bool
  description = "Force CodeBuild deployment and testing actions to run on every terraform apply, regardless of whether configuration has changed. Useful for development and troubleshooting. Set to false for production to only run CodeBuild when actual changes are detected."
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
    error_message = "For security purposes, 0.0.0.0/0 is not allowed for ingress. Specify actual CIDR blocks or use prefix lists."
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
    kubernetes_version     = optional(string, "1.35")
    external_dns_addon_version = optional(string, "v0.20.0-eksbuild.3")
    fluent_bit_addon_version = optional(string, "v4.2.2-eksbuild.1")
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
DDC Infrastructure Configuration - Controls EKS cluster, ScyllaDB database, and Kubernetes resources.
Set to null to skip infrastructure creation (infrastructure-only or application-only deployments).

GENERAL CONFIGURATION:
- name: Resource name prefix (default: "unreal-cloud-ddc")
- project_prefix: Project identifier for resource naming (default: "cgd")
- environment: Environment name (dev/staging/prod) for resource tagging
- region: AWS region override (uses provider region if null)

EKS CLUSTER CONFIGURATION:
- kubernetes_version: EKS cluster version (default: "1.35")
- eks_node_group_subnets: Private subnets for EKS nodes (required)
- endpoint_public_access: Allow public API access (default: true)
- endpoint_private_access: Allow private API access (default: true)
- public_access_cidrs: CIDR blocks for public API access (null = all IPs)

NODE GROUP CONFIGURATION (EKS Auto Mode - automatically managed):
NVME Node Group (DDC cache storage):
- nvme_managed_node_instance_type: Instance type with NVMe storage (default: "i3en.large")
- nvme_managed_node_desired_size: Target number of NVMe nodes (default: 2)
- nvme_managed_node_max_size: Maximum NVMe nodes for scaling (default: 2)
- nvme_managed_node_min_size: Minimum NVMe nodes (default: 1)

Worker Node Group (DDC application pods):
- worker_managed_node_instance_type: General compute instances (default: "c5.large")
- worker_managed_node_desired_size: Target worker nodes (default: 1)
- worker_managed_node_max_size: Maximum worker nodes (default: 1)
- worker_managed_node_min_size: Minimum worker nodes (default: 0)

System Node Group (Kubernetes system pods):
- system_managed_node_instance_type: System workload instances (default: "m5.large")
- system_managed_node_desired_size: Target system nodes (default: 1)
- system_managed_node_max_size: Maximum system nodes (default: 2)
- system_managed_node_min_size: Minimum system nodes (default: 1)

SCYLLADB DATABASE CONFIGURATION:
current_region: This region's ScyllaDB settings
- datacenter_name: ScyllaDB datacenter identifier (auto-generated if null)
- keyspace_suffix: Keyspace naming suffix (auto-generated if null)
- replication_factor: Number of ScyllaDB instances AND data copies (default: 3)

peer_regions: Multi-region ScyllaDB configuration (map of region → settings)
- datacenter_name: Remote datacenter identifier
- replication_factor: Data copies in remote region (default: 2)

ScyllaDB Infrastructure:
- enable_cross_region_replication: Enable multi-region data sync (default: true)
- keyspace_naming_strategy: Keyspace naming pattern (default: "region_suffix")
- create_seed_node: Create ScyllaDB seed node (default: true)
- existing_scylla_seed: Use existing seed node IP (for secondary regions)
- scylla_source_region: Source region for multi-region setup
- subnets: Private subnets for ScyllaDB instances
- scylla_ami_name: ScyllaDB AMI name (default: "ScyllaDB 6.0.1")
- scylla_instance_type: EC2 instance type with NVMe (default: "i4i.2xlarge")
- scylla_architecture: CPU architecture - "x86_64" or "arm64" (default: "x86_64")
- scylla_db_storage: EBS storage size in GB (default: 100)
- scylla_db_throughput: EBS throughput in MB/s (default: 200)
- scylla_ips_by_region: Pre-allocated ScyllaDB IPs by region (for advanced setups)

KUBERNETES CONFIGURATION:
- kubernetes_namespace: Kubernetes namespace for DDC resources (default: "unreal-cloud-ddc")
- kubernetes_service_account_name: Service account for DDC pods (default: "unreal-cloud-ddc-sa")

CERTIFICATE MANAGEMENT:
- certificate_manager_hosted_zone_arn: Route53 zones for cert-manager (list of ARNs)
- enable_certificate_manager: Install cert-manager for automatic TLS (default: false)

MULTI-REGION IAM ROLE SHARING (for cross-region deployments):
- eks_cluster_role_arn: Shared EKS cluster IAM role ARN
- eks_node_group_role_arns: Shared node group IAM role ARNs by type
- oidc_provider_arn: Shared OIDC provider ARN for service accounts

EXAMPLE SINGLE-REGION:
ddc_infra_config = {
  kubernetes_version = "1.35"
  eks_node_group_subnets = ["subnet-12345", "subnet-67890"]
  scylla_config = {
    current_region = {
      replication_factor = 3
    }
    subnets = ["subnet-abc", "subnet-def"]
  }
}

EXAMPLE MULTI-REGION:
Primary region:
ddc_infra_config = {
  scylla_config = {
    current_region = {
      datacenter_name = "us-east-1"
      replication_factor = 3
    }
    peer_regions = {
      "us-west-2" = {
        datacenter_name = "us-west-2"
        replication_factor = 2
      }
    }
  }
}

Secondary region:
ddc_infra_config = {
  scylla_config = {
    current_region = {
      datacenter_name = "us-west-2"
      replication_factor = 2
    }
    create_seed_node = false
    existing_scylla_seed = "10.0.1.100"  # Primary region seed IP
    scylla_source_region = "us-east-1"
  }
}
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
    bearer_token_secret_name = optional(string, null)

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
DDC Application Configuration - Controls DDC service deployment, resources, and testing.
Set to null to skip application deployment (infrastructure-only deployments).

DDC LOGICAL NAMESPACES (→ Helm values):
- default_ddc_namespace: Default namespace for DDC API calls and testing (default: "default")
- ddc_namespaces: Map of game project namespaces with optional region targeting
  Example: { "game1" = { description = "Main Game", regions = ["us-east-1", "us-west-2"] } }

MAIN POD RESOURCES (→ Helm values):
- instance_type: EC2 instance type for DDC pods (default: "i4i.xlarge")
  Must match available instance types in EKS Auto Mode node groups
- cpu_requests: CPU allocation per DDC pod (default: "2000m" = 2 cores)
- memory_requests: Memory allocation per DDC pod (default: "8Gi" = 8GB RAM)
- replica_count: Number of DDC pod replicas for high availability (default: 2)
  Note: Independent of ScyllaDB node count - scales DDC service layer only

WORKER POD RESOURCES (→ Helm values):
- worker_cpu_requests: CPU for DDC worker pods (default: "1000m" = 1 core)
- worker_memory_requests: Memory for DDC worker pods (default: "4Gi" = 4GB RAM)

DDC APPLICATION CONFIGURATION (→ Helm values):
- ddc_access_group: JWT group name for basic DDC access (default: "app-cloud-ddc-project")
- ddc_admin_group: JWT group name for DDC admin access (default: "cloud-ddc-admin")
- container_image: DDC container image URL (default: Epic's official image)
- helm_chart: Helm chart OCI URL (default: Epic's official chart)

AUTHENTICATION (→ Terraform only):
- bearer_token_secret_arn: AWS Secrets Manager ARN containing DDC bearer token
  If null, module creates a new token automatically
  Required for DDC API authentication and functional testing

MULTI-REGION REPLICATION (→ Terraform + Helm values):
- enable_multi_region_replication: Enable cross-region data synchronization (default: false)
- replication_mode: Data replication strategy (default: "speculative"):
  * "speculative": Proactively pushes new data to peer regions (lowest latency)
    Best for: Active multi-region development teams, real-time collaboration
  * "on-demand": Pulls missing data from peer regions when requested (cost optimized)
    Best for: Occasional cross-region access, cost-sensitive deployments
  * "hybrid": Combines push and pull strategies (maximum performance)
    Best for: Production environments with mixed usage patterns

DEPLOYMENT ORCHESTRATION (→ Terraform Actions only):
Cluster Readiness:
- cluster_ready_timeout_minutes: Wait time for EKS nodes to be ready (default: 10)

Single-Region Testing:
- enable_single_region_validation: Run DDC functional tests after deployment (default: true)
- single_region_validation_timeout_minutes: Test timeout in minutes (default: 5)
  Tests: Health checks, PUT/GET operations, bearer token authentication

Multi-Region Testing:
- enable_multi_region_validation: Run cross-region replication tests (default: false)
- peer_region_ddc_endpoint: Other region's DDC endpoint for cross-region testing
  Format: "https://us-west-2.dev.ddc.example.com" (required if multi-region testing enabled)
- multi_region_validation_timeout_minutes: Cross-region test timeout (default: 3)
  Tests: Cross-region PUT/GET, data integrity verification, replication timing

TESTING CONTROL PATTERNS:
Single-Region Deployment:
  enable_single_region_validation = true   # Test this region
  enable_multi_region_validation = false   # No cross-region tests

Multi-Region Deployment (Primary Region):
  enable_single_region_validation = true   # Test this region
  enable_multi_region_validation = true    # Test cross-region replication
  peer_region_ddc_endpoint = null          # Identifies as primary

Multi-Region Deployment (Secondary Region):
  enable_single_region_validation = true   # Test this region
  enable_multi_region_validation = false   # Skip cross-region tests (primary handles it)
  peer_region_ddc_endpoint = "https://primary-region.ddc.example.com"

EXAMPLE SINGLE-REGION:
ddc_application_config = {
  default_ddc_namespace = "mygame"
  instance_type = "i4i.xlarge"
  replica_count = 3
  bearer_token_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ddc-token"
}

EXAMPLE MULTI-REGION PRIMARY:
ddc_application_config = {
  enable_multi_region_replication = true
  replication_mode = "speculative"
  enable_multi_region_validation = true
  peer_region_ddc_endpoint = null  # Primary region
  ddc_namespaces = {
    "game1" = {
      description = "Main Game Project"
      regions = ["us-east-1", "us-west-2"]
    }
  }
}

EXAMPLE MULTI-REGION SECONDARY:
ddc_application_config = {
  enable_multi_region_replication = true
  replication_mode = "speculative"
  enable_multi_region_validation = false  # Primary handles cross-region tests
  peer_region_ddc_endpoint = "https://us-east-1.dev.ddc.example.com"
}
EOT

  default = null

  # Note: Validation removed - primary region can have enable_multi_region_validation=true with peer_region_ddc_endpoint=null
  # This identifies the primary region that runs cross-region tests

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
  description = "ARN of AWS Secrets Manager secret containing GitHub credentials for Epic Games container registry access. Secret must contain 'username' and 'accessToken' fields for GHCR authentication. For multi-region deployments, replicate this secret to all target regions using AWS Console > Secrets Manager > [Secret] > Replicate secret."
  default     = null
}


########################################
# Multi-Region IAM Role Sharing
########################################
variable "existing_iam_role_arns" {
  type = object({
    external_dns_role_arn                    = optional(string, null)
    aws_load_balancer_controller_role_arn    = optional(string, null)
    cert_manager_role_arn                    = optional(string, null)
    oidc_provider_arn                        = optional(string, null)
    codebuild_role_arn                       = optional(string, null)
  })
  description = "Existing IAM role ARNs to use instead of creating new ones. Can be from primary region, security team, or separate IAM module."
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


