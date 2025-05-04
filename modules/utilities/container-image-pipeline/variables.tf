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

variable "ecr_kms_key_id" {
  description = "KMS key ARN/ID to encrypt the ECR repository. Replace with your own KMS key ARN/ID if needed."
  type        = string
  default     = "alias/aws/ecr"
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

variable "dockerfile_template" {
  description = "Path to the Dockerfile template and its variables"
  type = object({
    template_path = string
    variables     = map(string)
  })

  validation {
    condition     = fileexists(var.dockerfile_template.template_path)
    error_message = "Dockerfile template must exist at the specified path."
  }

  validation {
    condition     = endswith(var.dockerfile_template.template_path, ".tpl")
    error_message = "Template file must have .tpl extension"
  }
}

variable "codebuild_build_timeout" {
  description = "Number of minutes, from 5 to 2160 (36 hours), for AWS CodeBuild to wait until timing out any related build that does not get marked as completed."
  type        = number
  default     = 60
}

variable "codebuild_compute_type" {
  description = "The compute type for the build environment. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#compute_type-1"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_image" {
  description = "The Docker image to use for the CodeBuild project."
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

variable "codebuild_type" {
  description = "The type of the build environment."
  type        = string
  default     = "LINUX_CONTAINER"
}

variable "source_image" {
  description = "Configuration for the source container image"
  default     = null
  type = object({
    provider = string
    image    = string
    tag      = string
    auth = object({
      secret_arn = optional(string)
      role_arn   = optional(string)
      account_id = optional(string)
      region     = optional(string)
    })
  })

  # Validate provider is one of the allowed values
  validation {
    condition     = contains(["amazon_ecr", "dockerhub", "ghcr"], var.source_image.provider)
    error_message = "Provider must be one of: amazon_ecr, dockerhub, ghcr"
  }

  # ECR validation
  validation {
    condition = var.source_image.provider == "amazon_ecr" ? (
      var.source_image.auth.secret_arn == null && # ECR doesn't use secret_arn
      (var.source_image.auth.role_arn != null ||  # Must have either role_arn
      var.source_image.auth.account_id != null)   # or account_id for cross-account
    ) : true
    error_message = "For amazon_ecr provider: secret_arn must be null, and either role_arn or account_id must be provided for cross-account access"
  }

  # Docker Hub validation
  validation {
    condition = var.source_image.provider == "dockerhub" ? (
      var.source_image.auth.secret_arn != null && # Must have secret_arn
      var.source_image.auth.role_arn == null &&   # Shouldn't have role_arn
      var.source_image.auth.account_id == null && # Shouldn't have account_id
      var.source_image.auth.region == null        # Shouldn't have region
    ) : true
    error_message = "For dockerhub provider: only secret_arn should be provided, other auth fields must be null"
  }

  # GitHub Container Registry validation
  validation {
    condition = var.source_image.provider == "ghcr" ? (
      var.source_image.auth.secret_arn != null && # Must have secret_arn
      var.source_image.auth.role_arn == null &&   # Shouldn't have role_arn
      var.source_image.auth.account_id == null && # Shouldn't have account_id
      var.source_image.auth.region == null        # Shouldn't have region
    ) : true
    error_message = "For ghcr provider: only secret_arn should be provided, other auth fields must be null"
  }
}
