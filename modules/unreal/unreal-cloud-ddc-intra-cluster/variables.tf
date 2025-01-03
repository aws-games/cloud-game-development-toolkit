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

variable "gchr_credentials_secret_manager_arn" {
  type        = string
  description = "Arn for credentials stored in secret manager. Needs to be prefixed with 'ecr-pullthroughcache/' to be compatible with ECR pull through cache."
  validation {
    condition     = length(regexall("ecr-pullthroughcache/", var.gchr_credentials_secret_manager_arn)) > 0
    error_message = "Needs to be prefixed with 'ecr-pullthroughcache/' to be compatible with ECR pull through cache."
  }
}

variable "oidc_credentials_secret_manager_arn" {
  type        = string
  description = "Arn for oidc credentials stored in secret manager."
}

variable "unreal_cloud_ddc_version" {
  type        = string
  description = "Version of the Unreal Cloud DDC Helm chart"
  default     = "1.2.0"
}
