variable "name" {
  description = "(Required) The name prepended to resources created by the module."
  type        = string
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appeneded to the beginning of most resource names."
  default     = "cgd"
}

variable "environment" {
  type        = string
  description = "The current environment (e.g. Development, Staging, Production, etc.). This will tag ressources and set ASPNETCORE_ENVIRONMENT variable."
  default     = "Development"
}

variable "tags" {
  type = map(any)
  default = {
    "iac-management" = "CGD-Toolkit"
    "iac-module"     = "container-image-pipeline"
    "iac-provider"   = "Terraform"
  }
  description = "Tags to apply to resources."
}

variable "ghcr_credentials_secret_manager_arn" {
  type        = string
  description = "Arn for credentials stored in secret manager."
}

variable "ecr_kms_key_id" {
  description = "KMS key ARN/ID to encrypt the ECR repository. Replace with your own KMS key ARN/ID if needed."
  type        = string
  default     = "alias/aws/ecr"
}

variable "base_image" {
  description = "The base image to use for the custom image build. This is the image that will be used as the starting point for the build."
  type        = string
  default     = null

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]*/[a-zA-Z0-9._-]*/[a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+$", var.base_image))
    error_message = "The base image must be in the format 'repository:tag' or 'namespace/repository:tag'."
  }
}

variable "image_tags" {
  description = "List of tags to use for the custom image build. This is a list of tags that will be applied to the built image."
  type        = list(string)

  validation {
    condition = alltrue([
      for tag in var.image_tags :
      can(regex("^[a-zA-Z0-9._-]+$", tag))
    ])
    error_message = "Image tags must be alphanumeric and can include '.', '_', and '-'."
  }
}
