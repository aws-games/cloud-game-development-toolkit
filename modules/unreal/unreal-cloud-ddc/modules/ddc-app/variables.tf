########################################
# GENERAL CONFIGURATION
########################################

variable "name" {
  description = "Unreal Cloud DDC Workload Name"
  type        = string
  default     = "unreal-cloud-ddc"
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload"
  default     = "cgd"
}

variable "environment" {
  type        = string
  description = "Environment name for deployment (dev, staging, prod, etc.)"
  default     = "dev"
}

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-west-2"
}

variable "debug" {
  type        = bool
  description = "Enable debug mode for development and testing. When true, forces CodeBuild deployment and testing actions to run on every terraform apply (regardless of configuration changes). When false, actions only run when there are actual changes to configuration, buildspecs, or assets. Passed from parent module."
  default     = false
}

########################################
# COMPUTE CONFIGURATION
########################################

variable "ddc_application_config" {
  type = object({
    # DDC Logical Namespaces
    default_ddc_namespace = optional(string, "default")
    ddc_namespaces = optional(map(object({
      description = optional(string, null)
      regions = optional(list(string), null)
    })), null)
    
    # Pod Resources (Main DDC Service)
    instance_type    = optional(string, "i4i.xlarge")
    cpu_requests     = optional(string, "2000m")
    memory_requests  = optional(string, "8Gi")
    replica_count    = optional(number, 2)
    
    # Pod Resources (Worker Pods)
    worker_cpu_requests = optional(string, "1000m")
    worker_memory_requests = optional(string, "4Gi")
    
    # Application Configuration
    ddc_access_group = optional(string, "app-cloud-ddc-project")
    ddc_admin_group  = optional(string, "cloud-ddc-admin")
    container_image = optional(string, "ghcr.io/epicgames/unreal-cloud-ddc:1.2.0")
    helm_chart = optional(string, "oci://ghcr.io/epicgames/unreal-cloud-ddc:1.2.0+helm")
    
    # Multi-Region Replication
    enable_multi_region_replication = optional(bool, false)
    replication_mode = optional(string, "speculative")
    
    # Authentication
    bearer_token_secret_arn = optional(string, null)
    

    # Deployment Orchestration
    cluster_ready_timeout_minutes = optional(number, 10)
    enable_single_region_validation = optional(bool, true)
    single_region_validation_timeout_minutes = optional(number, 5)
    enable_multi_region_validation = optional(bool, false)
    peer_region_ddc_endpoint = optional(string, null)
    multi_region_validation_timeout_minutes = optional(number, 3)
    
    # Custom Helm Values Override
    custom_helm_values = optional(map(any), null)
  })
  description = <<EOT
DDC application configuration passed from parent module.

## DDC Logical Namespaces
- default_ddc_namespace: Fallback namespace for testing
- ddc_namespaces: Map of game project namespaces with regions for replication

## Pod Resources (Main DDC Service)
- instance_type: EC2 instance type for DDC pods
- cpu_requests: CPU per DDC pod (determines node sizing)
- memory_requests: Memory per DDC pod (determines node sizing)
- replica_count: Number of DDC service pods (NOT related to replication)

## Pod Resources (Worker Pods)
- worker_cpu_requests: CPU for background worker pods
- worker_memory_requests: Memory for background worker pods

## Application Configuration
- ddc_access_group: JWT group for basic DDC access
- ddc_admin_group: JWT group for admin privileges
- container_image: Container image reference (must exist in accessible registry):
  * Epic's default: "ghcr.io/epicgames/unreal-cloud-ddc:1.2.0" (auto-cached)
  * Custom GHCR: "ghcr.io/yourorg/custom-ddc:1.0.0" (cached in module ECR)
  * Custom ECR: "123456789012.dkr.ecr.us-east-1.amazonaws.com/custom-ddc:1.0.0" (cached in module ECR)
  * Docker Hub: "yourorg/custom-ddc:1.0.0" (cached in module ECR)
  * ❌ Local images NOT supported (must push to remote registry first)
- helm_chart: Helm chart reference (must exist in accessible registry):
  * Epic's OCI charts: "oci://ghcr.io/epicgames/unreal-cloud-ddc:1.2.0+helm" (auto-handles +helm suffix)
  * Custom OCI charts: "oci://ghcr.io/yourorg/custom-ddc:1.0.0" (cached in module ECR)
  * Custom ECR charts: "oci://123456789012.dkr.ecr.us-east-1.amazonaws.com/custom-ddc:1.0.0" (cached in module ECR)
  * ❌ Local charts NOT supported (must push to remote registry first)

## Multi-Region Replication
- enable_multi_region_replication: Enable cross-region data replication
- replication_mode: "speculative" (push), "on-demand" (pull), "hybrid" (both)

## Authentication
- bearer_token_secret_arn: AWS Secrets Manager ARN for existing token (multi-region sharing)

## Deployment Orchestration
- cluster_ready_timeout_minutes: Wait time for EKS cluster readiness
- enable_single_region_validation: Run single-region DDC tests (default: true)
  * Tests this specific region's DDC functionality
  * Valuable for both single-region and multi-region deployments
  * debug=true forces this to run regardless of changes
- enable_multi_region_validation: Run multi-region connectivity tests (default: false)
  * Tests cross-region DDC replication and connectivity
  * Should only be enabled in PRIMARY region (peer_region_ddc_endpoint=null)
  * Automatically blocked in secondary regions to prevent duplication
  * debug=true does NOT force this to run (avoids multi-region test duplication)
- peer_region_ddc_endpoint: DDC endpoint of peer region (null = primary region)
- single_region_validation_timeout_minutes: Timeout for single-region tests
- multi_region_validation_timeout_minutes: Timeout for multi-region tests

## Custom Helm Values
- custom_helm_values: Override all generated values with custom chart values (for non-Epic charts)
  * If null (default): Uses generated Epic-compatible values
  * If provided: Completely replaces generated values (Epic config attributes ignored)
  * ⚠️ When using custom values, Epic-specific attributes (replica_count, cpu_requests, etc.) are ignored

NOTE: replica_count is for Kubernetes pod scaling (performance), NOT replication (data redundancy).
Data replication is handled by enable_multi_region_replication and ScyllaDB.

## Multi-Region Deployment (Self-Healing)
DDC handles multi-region deployment automatically:
1. Deploy both regions simultaneously with enable_multi_region_replication = true
2. DDC deploys with peer endpoints (even if they don't exist yet)
3. Replication enters retry/backoff loop until peers are available
4. Once both regions are up, replication starts working automatically
5. Set debug=true to force pod restart for immediate verification (optional)
EOT
}

variable "replication_factor" {
  description = "ScyllaDB replication factor (legacy - use database_connection instead)"
  type        = number
  default     = 3
}

########################################
# STORAGE & LOGGING CONFIGURATION
########################################

variable "enable_centralized_logging" {
  description = "Whether centralized logging is enabled from parent module"
  type        = bool
}

variable "log_group_prefix" {
  description = "Log group prefix from parent module"
  type        = string
}

variable "log_retention_days" {
  description = "Log retention days from parent module"
  type        = number
}

variable "s3_bucket_id" {
  description = "S3 bucket ID"
  type        = string
  default     = null
}

########################################
# NETWORKING CONFIGURATION
########################################

variable "vpc_id" {
  type        = string
  description = "VPC ID for AWS Load Balancer Controller configuration"
}

variable "ddc_endpoint_pattern" {
  type        = string
  description = "DDC hostname for this region (e.g., 'us-east-1.dev.ddc.example.com')"
}

variable "ddc_dns_endpoint" {
  type        = string
  description = "DDC DNS endpoint for testing (optional)"
  default     = null
}

variable "bearer_token_secret_arn" {
  type        = string
  description = "Bearer token secret ARN for testing (optional)"
  default     = null
}

variable "nlb_dns_name" {
  description = "DDC NLB DNS name"
  type        = string
  default     = null
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listeners (optional)"
  default     = null
}

variable "load_balancers_config" {
  type = object({
    nlb = optional(object({
      internet_facing = optional(bool, true)
    }), null)
  })
  description = "Load balancer configuration from parent module"
  default     = null
}

variable "subnets" {
  type        = list(string)
  description = "Subnets for CodeBuild VPC configuration"
}

variable "eks_node_group_subnets" {
  type        = list(string)
  description = "EKS node group subnets for CodeBuild VPC configuration"
}

variable "cluster_security_group_id" {
  type        = string
  description = "EKS cluster security group ID for CodeBuild VPC configuration"
}

variable "nlb_security_group_id" {
  type        = string
  description = "Terraform-managed NLB security group ID to prevent EKS Auto Mode orphaned resources"
}

# DNS zone IDs for External-DNS split-horizon configuration
# Split-horizon DNS enables same hostname to resolve from both VPC and Internet:
# - VPC clients (CodeBuild, EKS pods, VPN users) → Query private zone → Internal routing to NLB
# - Internet clients (developers, CI/CD) → Query public zone → External routing to NLB
variable "private_zone_id" {
  type        = string
  description = "Private Route53 hosted zone ID for VPC-based DNS resolution"
}

variable "public_zone_id" {
  type        = string
  description = "Public Route53 hosted zone ID for Internet-based DNS resolution (optional)"
  default     = null
}

########################################
# KUBERNETES CONFIGURATION
########################################

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = null
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = null
}

variable "kubernetes_service_account_name" {
  type        = string
  description = "Kubernetes service account name from ddc_infra_config"
}

variable "service_account_arn" {
  description = "ARN of the service account IAM role"
  type        = string
  default     = null
}

########################################
# SECURITY CONFIGURATION
########################################

variable "ddc_bearer_token" {
  type        = string
  description = "DDC bearer token"
  sensitive   = true
}

variable "ghcr_credentials_secret_arn" {
  type        = string
  description = "ARN for GHCR credentials in secret manager"
}

########################################
# DATABASE CONFIGURATION
########################################

variable "database_connection" {
  type = object({
    type = string           # "scylla" or "keyspaces"
    host = string           # Connection endpoint
    port = number           # Connection port
    auth_type = string      # "credentials" or "iam"
    keyspace_name = string  # Keyspace/database name
    multi_region = bool     # Whether multi-region is enabled
  })
  description = "Database connection information from ddc-infra module"
}

variable "scylla_ips" {
  description = "ScyllaDB node IPs (legacy - use database_connection instead)"
  type        = list(string)
  default     = []
}

variable "scylla_dns_name" {
  description = "ScyllaDB cluster DNS name (legacy - use database_connection instead)"
  type        = string
  default     = null
}

variable "scylla_datacenter_name" {
  description = "ScyllaDB datacenter name (legacy - use database_connection instead)"
  type        = string
  default     = null
}

variable "scylla_keyspace_suffix" {
  description = "ScyllaDB keyspace suffix (legacy - use database_connection instead)"
  type        = string
  default     = null
}

variable "ssm_document_name" {
  type        = string
  description = "Name of SSM document for keyspace configuration (from ddc-infra)"
  default     = null
}

variable "scylla_seed_instance_id" {
  type        = string
  description = "Instance ID of ScyllaDB seed node for SSM execution"
  default     = null
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources"
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "-"
    "ModuleName"     = "ddc-app"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/modules/ddc-app"
  }
}

# COMMENTED OUT FOR EKS AUTO MODE TESTING
# EKS Auto Mode creates OIDC provider automatically
# variable "oidc_provider_arn" {
#   description = "OIDC provider ARN for EKS cluster (for IRSA)"
#   type        = string
#   default     = null
# }