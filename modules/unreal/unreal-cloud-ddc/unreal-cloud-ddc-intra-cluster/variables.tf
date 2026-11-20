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
  type = map(any)
  default = {
    "ModuleBy"   = "CGD-Toolkit"
    "ModuleName" = "Unreal DDC"
    "IaC"        = "Terraform"
  }
  description = "Tags to apply to resources."
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
  description = "Path to your Unreal Cloud DDC helm values template for single region deployments. Not used when is_multi_region_deployment is true."
  default     = null

  validation {
    condition     = var.is_multi_region_deployment || var.unreal_cloud_ddc_helm_base_infra_chart != null
    error_message = "unreal_cloud_ddc_helm_base_infra_chart is required for single region deployments."
  }
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

variable "ebs_csi_use_pod_identity" {
  type        = bool
  default     = false
  description = "Use EKS Pod Identity instead of IRSA for the EBS CSI driver controller. Required in accounts where an Organization RCP/SCP denies sts:AssumeRoleWithWebIdentity. When true, the EBS CSI driver addon is managed natively with a Pod Identity association and the eks-pod-identity-agent addon is installed; when false, the legacy IRSA path is used."
}

variable "unreal_cloud_ddc_helm_timeout" {
  type        = number
  default     = 900
  description = "Seconds Helm waits for the Unreal Cloud DDC release to become ready (pods running and the load balancer Service assigned an address). A healthy install finishes in about 5 minutes; a stuck install (for example a load balancer that cannot be created) fails after this long instead of hanging."
  validation {
    condition     = var.unreal_cloud_ddc_helm_timeout >= 300
    error_message = "unreal_cloud_ddc_helm_timeout must be at least 300 seconds."
  }
}

variable "unreal_cloud_ddc_load_balancer_name" {
  type        = string
  description = "Name of the Network Load Balancer the AWS Load Balancer Controller creates for the Unreal Cloud DDC Service. Passed to the helm values template as load_balancer_name. Must be unique per account and region, at most 32 characters."
  default     = "cgd-unreal-cloud-ddc"

  validation {
    condition     = length(var.unreal_cloud_ddc_load_balancer_name) <= 32
    error_message = "unreal_cloud_ddc_load_balancer_name must be at most 32 characters."
  }
}

variable "unreal_cloud_ddc_replication_peer_hostname" {
  type        = string
  description = "Stable hostname of the peer region's Unreal Cloud DDC endpoint (for example a Route53 alias to the peer's load balancer). Passed to the replication values template as ddc_replication_region_url. Required for multi region deployments."
  default     = null

  validation {
    condition     = !var.is_multi_region_deployment || var.unreal_cloud_ddc_replication_peer_hostname != null
    error_message = "unreal_cloud_ddc_replication_peer_hostname is required for multi region deployments."
  }
}
