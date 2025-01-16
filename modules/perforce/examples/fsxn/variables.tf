########################################
# GENERAL CONFIGURATION
########################################
variable "name" {
  type        = string
  description = "The name attached to swarm module resources."
  default     = "helix-core"

  validation {
    condition     = length(var.name) > 1 && length(var.name) <= 50
    error_message = "The defined 'name' has too many characters (${length(var.name)}). This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appeneded to the beginning of most resource names."
  default     = "cgd"

}

variable "environment" {
  type        = string
  description = "The current environment (e.g. dev, prod, etc.)"
  default     = "dev"
}

variable "tags" {
  type = map(any)
  default = {
    "iac-management" = "CGD-Toolkit"
    "iac-module"     = "helix-core"
    "iac-provider"   = "Terraform"
  }
  description = "Tags to apply to resources."
}

variable "instance_architecture" {
  type        = string
  description = "The architecture of the Helix Core instance. Allowed values are 'arm64' or 'x86_64'."
  default     = "arm64"
  validation {
    condition     = var.instance_architecture == "arm64" || var.instance_architecture == "x86_64"
    error_message = "The instance_architecture variable must be either 'arm64' or 'x86_64'."
  }
}

variable "unicode" {
  type        = bool
  description = "Whether to enable Unicode configuration for Helix Core the -xi flag for p4d. Set to true to enable Unicode support."
  default     = false
}

variable "selinux" {
  type        = bool
  description = "Whether to apply SELinux label updates for Helix Core. Don't enable this if SELinux is disabled on your target operating system."
  default     = false
}

########################################
# Networking and Security
########################################
variable "vpc_id" {
  type        = string
  description = "The VPC where Helix Core should be deployed"
}

variable "create_default_sg" {
  type        = bool
  description = "Whether to create a default security group for the Helix Core instance."
  default     = true
}

variable "instance_subnet_id" {
  type        = string
  description = "The subnet where the Helix Core instance will be deployed."
}

variable "existing_security_groups" {
  type        = list(string)
  description = "A list of existing security group IDs to attach to the Helix Core load balancer."
  default     = []
}

variable "internal" {
  type        = bool
  description = "Set this flag to true if you do not want the Helix Core instance to have a public IP."
  default     = false
}

variable "fully_qualified_domain_name" {
  type        = string
  description = "The fully qualified domain name where Helix Core will be available. This is used to generate self-signed certificates on the Helix Core server."
  default     = null
}

########################################
# INSTANCE CONFIGURATION
########################################
variable "instance_type" {
  type        = string
  description = "The instance type for Perforce Helix Core. Defaults to c6in.large."
  default     = "c6in.large"
}

variable "server_type" {
  type        = string
  description = "The Perforce Helix Core server type."
  validation {
    condition     = contains(["p4d_commit", "p4d_replica"], var.server_type)
    error_message = "${var.server_type} is not one of p4d_commit or p4d_replica."
  }
}

# tflint-ignore: terraform_unused_declarations
variable "storage_type" {
  type        = string
  description = "The type of backing store [EBS, FSxZ, FSxN]"
  validation {
    condition     = contains(["EBS", "FSxZ", "FSxN"], var.storage_type)
    error_message = "Not a valid storage type."
  }
}

variable "logs_volume_size" {
  type        = number
  description = "The size of the logs volume in GiB. Defaults to 32 GiB."
  default     = 32
}

variable "metadata_volume_size" {
  type        = number
  description = "The size of the metadata volume in GiB. Defaults to 32 GiB."
  default     = 32
}

variable "depot_volume_size" {
  type        = number
  description = "The size of the depot volume in GiB. Defaults to 128 GiB."
  default     = 128
}

variable "fsxn_region" {
  description = "The ID of the Storage Virtual Machine (SVM) for the FSx ONTAP filesystem."
  type        = string
  default     = ""
}

########################################
# Helix Core Instance Roles
########################################
variable "custom_helix_core_role" {
  type        = string
  description = "ARN of the custom IAM Role you wish to use with Helix Core."
  default     = null
}

variable "create_helix_core_default_role" {
  type        = bool
  description = "Optional creation of Helix Core default IAM Role with SSM managed instance core policy attached. Default is set to true."
  default     = true
}


########################################
# Super User Credentials
########################################
variable "helix_core_super_user_password_secret_arn" {
  type        = string
  description = "If you would like to manage your own super user credentials through AWS Secrets Manager provide the ARN for the super user's password here."
  default     = null
}

variable "helix_core_super_user_username_secret_arn" {
  type        = string
  description = "If you would like to manage your own super user credentials through AWS Secrets Manager provide the ARN for the super user's username here. Otherwise, the default of 'perforce' will be used."
  default     = null
}

variable "helix_authentication_service_url" {
  type        = string
  description = "The URL for the Helix Authentication Service."
  default     = null
}

########################################
# Helix Core settings
########################################
variable "helix_case_sensitive" {
  type        = bool
  description = "Whether or not the server should be case insensitive (Server will run '-C1' mode), or if the server will run with case sensitivity default of the underlying platform. False enables '-C1' mode"
  default     = true
}

variable "plaintext" {
  type        = bool
  description = "Whether to enable plaintext authentication for Helix Core. This is not recommended for production environments unless you are using a load balancer for TLS termination."
  default     = false
}
