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

variable "container_image" {
  type        = string
  description = "The container image to use."
}

variable "container_recipe_arn" {
  type        = string
  description = "The ARN of the container recipe to use."
}

variable "infrastructure_configuration_arn" {
  description = "ARN of the container image pipeline infrastructure configuration"
  type        = string
}

variable "ecr_kms_key_id" {
  description = "KMS key ARN/ID to encrypt the ECR repository. Replace with your own KMS key ARN/ID if needed."
  type        = string
  default     = "alias/aws/ecr"
}

variable "imagebuilder_component_kms_key_id" {
  description = "Optional KMS key ARN/ID to encrypt the EC2 Image Builder component. Replace with your own KMS key ARN/ID if needed."
  type        = string
  default     = "alias/aws/imagebuilder"
}
