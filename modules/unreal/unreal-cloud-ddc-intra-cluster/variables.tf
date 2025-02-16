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

variable "unreal_cloud_ddc_helm_values" {
  type        = list(string)
  description = "List of YAML files for Unreal Cloud DDC"
  default     = []
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
