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

variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "terraform-aws-unreal-cloud-ddc"
    "ModuleName"     = "applications"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc"
  }
}

variable "is_multi_region_deployment" {
  type        = bool
  description = "Determines whether this is a multi region Unreal DDC deployment."
  default     = false
}

variable "region" {
  type        = string
  description = "The region where the Unreal Cloud DDC deployment will reside"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS Cluster"
}

variable "cluster_oidc_provider_arn" {
  type        = string
  description = "ARN of the OIDC Provider from EKS Cluster"
}

variable "s3_bucket_id" {
  type        = string
  description = "ID of the S3 Bucket for Unreal Cloud DDC to use"
}

variable "unreal_cloud_ddc_namespace" {
  type        = string
  description = "Namespace for Unreal Cloud DDC"
  default     = "unreal-cloud-ddc"
}

variable "unreal_cloud_ddc_helm_config" {
  type        = map(string)
  description = "Configuration values to pass to the Unreal Cloud DDC helm chart."
  default     = {}
}

variable "unreal_cloud_ddc_helm_base_infra_chart" {
  type        = string
  description = "Path to your Unreal Cloud DDC helm chart"
}

variable "unreal_cloud_ddc_helm_replication_chart" {
  type        = string
  description = "Path to your Unreal Cloud DDC helm chart if replication is needed. This is used in multi-region deployments and is not required for single region deployments."
  default     = null

  validation {
    condition     = (var.is_multi_region_deployment && var.unreal_cloud_ddc_helm_replication_chart != null) || (!var.is_multi_region_deployment && var.unreal_cloud_ddc_helm_replication_chart == null)
    error_message = "Replication chart is required for multi-region deployments."
  }
}

variable "ghcr_credentials_secret_manager_arn" {
  type        = string
  description = "Arn for credentials stored in secret manager. Needs to be prefixed with 'ecr-pullthroughcache/' to be compatible with ECR pull through cache."
  validation {
    condition     = length(regexall("ecr-pullthroughcache/", var.ghcr_credentials_secret_manager_arn)) > 0
    error_message = "Needs to be prefixed with 'ecr-pullthroughcache/' to be compatible with ECR pull through cache."
  }
}

variable "oidc_credentials_secret_manager_arn" {
  type        = string
  description = "Arn for oidc credentials stored in secret manager."
  default     = null
}

variable "unreal_cloud_ddc_version" {
  type        = string
  description = "Version of the Unreal Cloud DDC Helm chart."
  default     = "1.2.0"
}

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
