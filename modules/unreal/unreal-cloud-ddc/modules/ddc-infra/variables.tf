########################################
# GENERAL CONFIGURATION
########################################

variable "name" {
  description = "Unreal Cloud DDC Workload Name"
  type        = string
  default     = "unreal-cloud-ddc"
  validation {
    condition     = length(var.name) > 1 && length(var.name) <= 50
    error_message = "The defined 'name' has too many characters. This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}

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

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-west-2"
}

variable "create_seed_node" {
  description = "Whether this region creates the ScyllaDB seed node (bootstrap node for cluster formation)"
  type        = bool
  default     = true
}

variable "is_primary_region" {
  description = "Whether this is the primary region that creates global IAM resources"
  type        = bool
  default     = true
}

variable "debug" {
  description = "Enable debug mode"
  type        = bool
  default     = false
}

variable "scylla_config" {
  description = "ScyllaDB configuration from parent module (null if using Keyspaces)"
  default     = null
}



variable "keyspace_name" {
  description = "Keyspace name from parent module to avoid duplication"
  type        = string
  default     = null
}

variable "internet_gateway_id" {
  type        = string
  description = "Internet Gateway ID for proper dependency ordering during destroy"
  default     = null
}

########################################
# COMPUTE CONFIGURATION
########################################

variable "scylla_replication_factor" {
  type        = number
  description = "How many copies of your data are stored across the cluster. This will reflect how many scylla worker nodes are created."
}

variable "scylla_instance_type" {
  type        = string
  default     = "i4i.2xlarge"
  description = "The type and size of the Scylla instance."
  nullable    = false
  validation {
    condition     = contains(["i8g", "i7ie", "i4g", "i4i", "im4gn", "is4gen", "i4i", "i3", "i3en"], split(".", var.scylla_instance_type)[0])
    error_message = "Must be an instance family that contains NVME"
  }
  validation {
    condition     = (contains(["arm64"], var.scylla_architecture) && contains(["i8g", "i4g", "im4gn", "is4gen"], split(".", var.scylla_instance_type)[0])) || (contains(["x86_64"], var.scylla_architecture) && contains(["i7ie", "i4i", "i4i", "i3", "i3en"], split(".", var.scylla_instance_type)[0]))
    error_message = "Chip architecture must match instance type"
  }
}

variable "scylla_architecture" {
  type        = string
  default     = "x86_64"
  description = "The chip architecture to use when finding the scylla image. Valid values: x86_64, arm64"
  nullable    = false
  validation {
    condition     = contains(["x86_64", "arm64"], var.scylla_architecture)
    error_message = "Must be a supported chip architecture"
  }
}

variable "scylla_ami_name" {
  type        = string
  default     = "ScyllaDB 6.0.1"
  description = "Name of the Scylla AMI to be used to get the AMI ID"
  nullable    = false
}

variable "existing_scylla_ips" {
  type        = list(string)
  default     = []
  description = "List of existing ScyllaDB IPs to be used for the ScyllaDB instance"
}

variable "scylla_ips_by_region" {
  type        = map(list(string))
  default     = {}
  description = "Map of ScyllaDB IPs organized by region for monitoring dashboard separation"
}

variable "existing_scylla_seed" {
  type        = string
  description = "The IP address of the seed instance of the ScyllaDB cluster"
  default     = null
}

variable "scylla_source_region" {
  type        = string
  description = "Name of the primary region for multi-region deployments"
  default     = null
}

########################################
# STORAGE & LOGGING CONFIGURATION
########################################

variable "scylla_db_storage" {
  type        = number
  default     = 100
  description = "Size of gp3 ebs volumes attached to Scylla DBs"
  nullable    = false
}

variable "scylla_db_throughput" {
  type        = number
  default     = 200
  description = "Throughput of gp3 ebs volumes attached to Scylla DBs"
  nullable    = false
}

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

variable "eks_cluster_cloudwatch_log_group_prefix" {
  type        = string
  default     = "/aws/eks/unreal-cloud-ddc/cluster"
  description = "Prefix to be used for the EKS cluster CloudWatch log group."
}

variable "eks_cluster_logging_types" {
  type = list(string)
  default = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  description = "List of EKS cluster log types to be enabled."
}

########################################
# NETWORKING CONFIGURATION
########################################

variable "vpc_id" {
  description = "String for VPC ID"
  type        = string
}

variable "scylla_subnets" {
  type        = list(string)
  default     = []
  description = "A list of subnet IDs where Scylla will be deployed. Private subnets are strongly recommended."
}

variable "eks_node_group_subnets" {
  type        = list(string)
  default     = []
  description = "A list of subnets ids you want the EKS nodes to be installed into. Private subnets are strongly recommended."
}

variable "nlb_subnet_id" {
  type        = string
  description = "Specific subnet ID for NLB placement (passed to ddc-app for service annotations)"
  default     = null
}

variable "route53_hosted_zone_name" {
  type        = string
  description = "Route53 hosted zone name for External-DNS (e.g., 'example.com' or 'cgd.internal')"
  default     = null
}

variable "eks_uses_vpc_endpoint" {
  type        = bool
  description = "Whether EKS uses VPC endpoint for API access"
  default     = false
}

variable "endpoint_public_access" {
  type        = bool
  description = "Enable public API server endpoint"
  default     = true
}

variable "endpoint_private_access" {
  type        = bool
  description = "Enable private API server endpoint"
  default     = true
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks that can access the public API server endpoint"
  default     = null
}

########################################
# KUBERNETES CONFIGURATION
########################################

variable "kubernetes_version" {
  type        = string
  default     = "1.31"
  description = "Kubernetes version to be used by the EKS cluster."
  nullable    = false
  validation {
    condition     = contains(["1.31", "1.32", "1.33"], var.kubernetes_version)
    error_message = "Version number must be supported version in AWS Kubernetes"
  }
}

# CRITICAL: This namespace name MUST match exactly in:
# - Helm release namespace
# - IAM role trust policy: system:serviceaccount:{namespace}:{service_account}
# - TargetGroupBinding namespace
variable "unreal_cloud_ddc_namespace" {
  type        = string
  description = "Namespace for Unreal Cloud DDC"
  default     = null  # Will use name_prefix if not specified
}

# CRITICAL: This service account name MUST match exactly in:
# - IAM role trust policy: system:serviceaccount:{namespace}:{service_account}
# - Helm chart serviceAccount.name value
variable "unreal_cloud_ddc_service_account_name" {
  type        = string
  description = "Name of Unreal Cloud DDC service account."
  default     = "unreal-cloud-ddc-sa"
}

variable "certificate_manager_hosted_zone_arn" {
  type        = list(string)
  description = "ARN of the Certificate Manager for Ingress."
  default     = []
}

variable "enable_certificate_manager" {
  type        = bool
  description = "Enable Certificate Manager for Ingress. Required for TLS termination."
  default     = false
  validation {
    condition     = var.enable_certificate_manager ? length(var.certificate_manager_hosted_zone_arn) > 0 : true
    error_message = "Certificate Manager hosted zone ARN is required."
  }
}

variable "oidc_credentials_secret_manager_arn" {
  type        = string
  description = "ARN for OIDC credentials stored in secret manager (for external service authentication)"
  default     = null
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
    Map of EKS access entries for granting cluster access to additional IAM principals.
    
    Key = unique identifier for the access entry
    Value = access entry configuration
    
    Example:
    eks_access_entries = {
      "argocd" = {
        principal_arn = "arn:aws:iam::123456789012:role/ArgoCD-Role"
        type         = "STANDARD"
        policy_associations = [{
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }]
      }
      "dev_team" = {
        principal_arn = "arn:aws:iam::123456789012:role/DevTeam-Role"
        policy_associations = [{
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["development"]
          }
        }]
      }
    }
  EOT
  default = {}
}

########################################
# SECURITY CONFIGURATION
########################################

variable "additional_nlb_security_groups" {
  type        = list(string)
  description = "Additional security group IDs to attach specifically to the DDC Network Load Balancer (for game developer access)"
  default     = []
}

variable "additional_eks_security_groups" {
  type        = list(string)
  description = "Additional security group IDs to attach specifically to the EKS cluster (for DevOps kubectl access)"
  default     = []
}

variable "ddc_app_resource" {
  description = "DDC app module resource to ensure EKS cluster waits for cleanup"
  type        = any
  default     = null
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "terraform-aws-unreal-cloud-ddc"
    "ModuleName"     = "infrastructure"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc"
  }
}

variable "force_destroy_s3_bucket" {
  type        = bool
  description = "Force destroy S3 bucket even if it contains objects"
  default     = false
}
