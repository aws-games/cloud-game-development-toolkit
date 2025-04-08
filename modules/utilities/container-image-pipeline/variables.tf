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

variable "parent_container_image" {
  type        = string
  description = "The parent container image to use in the container recipe."
}

variable "container_recipe_version" {
  type        = string
  description = "The version of the container recipe. Must follow semantic versioning (major.minor.patch)."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.container_recipe_version))
    error_message = "The container_recipe_version value must follow semantic versioning (major.minor.patch)."
  }
}

variable "ecr_kms_key_id" {
  description = "KMS key ARN/ID to encrypt the ECR repository. Replace with your own KMS key ARN/ID if needed."
  type        = string
  default     = "alias/aws/ecr"
}

variable "imagebuilder_component_kms_key_id" {
  description = "Optional KMS key ARN/ID to encrypt the EC2 Image Builder component. Replace with your own KMS key ARN/ID if needed."
  type        = string
  default     = null
}

variable "imagebuilder_instance_types" {
  description = "The instance types to use for the EC2 Image Builder component."
  type        = list(string)
  default     = ["t3a.nano"]
}

variable "security_group_ids" {
  description = "Optional list of security group IDs for the infrastructure configuration"
  type        = list(string)
  default     = null
}

variable "subnet_id" {
  description = "Optional subnet ID for the infrastructure configuration"
  type        = string
  default     = null
}

variable "image_builder_base_component_version" {
  type        = string
  description = "The version of the base component to use in the container image pipeline. Must follow semantic versioning (major.minor.patch)."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.image_builder_base_component_version))
    error_message = "The image_builder_base_component_version value must follow semantic versioning (major.minor.patch)."
  }
}
