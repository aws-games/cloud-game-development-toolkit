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

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-west-2"
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources"
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "ModuleName"     = "ddc-services"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc"
  }
}

########################################
# Infrastructure Inputs (from ddc-infra)
########################################

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = null
}

variable "nlb_arn" {
  description = "DDC NLB ARN"
  type        = string
  default     = null
}

variable "nlb_target_group_arn" {
  description = "DDC NLB target group ARN"
  type        = string
  default     = null
}

variable "nlb_dns_name" {
  description = "DDC NLB DNS name"
  type        = string
  default     = null
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = null
}

variable "service_account" {
  description = "Kubernetes service account"
  type        = string
  default     = null
}

variable "service_account_arn" {
  description = "ARN of the service account IAM role"
  type        = string
  default     = null
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for EKS cluster"
  type        = string
  default     = null
}

variable "ebs_csi_role_arn" {
  description = "EBS CSI driver IAM role ARN"
  type        = string
  default     = null
}

variable "enable_certificate_manager" {
  description = "Enable Certificate Manager for Ingress"
  type        = bool
  default     = false
}

variable "certificate_manager_hosted_zone_arn" {
  description = "ARN of the Certificate Manager hosted zone"
  type        = list(string)
  default     = []
}

variable "s3_bucket_id" {
  description = "S3 bucket ID"
  type        = string
  default     = null
}

variable "scylla_ips" {
  description = "ScyllaDB node IPs"
  type        = list(string)
  default     = []
}

variable "scylla_datacenter_name" {
  description = "ScyllaDB datacenter name (region with -1 suffix removed)"
  type        = string
  default     = null
}

variable "scylla_keyspace_suffix" {
  description = "ScyllaDB keyspace suffix (region with dashes replaced by underscores)"
  type        = string
  default     = null
}

variable "replication_factor" {
  description = "ScyllaDB replication factor"
  type        = number
  default     = 3
}

########################################
# Service Configuration
########################################

variable "unreal_cloud_ddc_version" {
  type        = string
  description = "Version of the Unreal Cloud DDC Helm chart"
  default     = "1.3.0"
}

variable "unreal_cloud_ddc_helm_base_infra_chart" {
  type        = string
  description = "Path to base infrastructure Helm chart"
  default     = null
}

variable "unreal_cloud_ddc_helm_replication_chart" {
  type        = string
  description = "Path to replication Helm chart"
  default     = null
}

variable "ddc_replication_region_url" {
  type        = string
  description = "URL of primary region DDC for replication"
  default     = null
}

variable "ddc_bearer_token" {
  type        = string
  description = "DDC bearer token"
  sensitive   = true
}

########################################
# Credentials
########################################

variable "ghcr_credentials_secret_manager_arn" {
  type        = string
  description = "ARN for GHCR credentials in secret manager"
}

variable "oidc_credentials_secret_manager_arn" {
  type        = string
  description = "ARN for OIDC credentials in secret manager"
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