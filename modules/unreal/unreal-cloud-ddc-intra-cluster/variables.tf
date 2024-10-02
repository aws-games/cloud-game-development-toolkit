variable "cluster_name" {
  type        = string
  description = "Name of the EKS Cluster"
}
variable "oidc_provider_arn" {
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


variable "external_secrets_secret_manager_arn_list" {
  type        = list(string)
  description = "List of ARNS for Secret Manager Secrets to use in Unreal Cloud DDC"
  default     = []
}
