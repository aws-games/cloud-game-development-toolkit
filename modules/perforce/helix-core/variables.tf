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
    "IAC_MANAGEMENT" = "CGD-Toolkit"
    "IAC_MODULE"     = "helix-core"
    "IAC_PROVIDER"   = "Terraform"
  }
  description = "Tags to apply to resources."
}

########################################
# NETWORKING AND SECURITY
########################################
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
    condition     = contains(["p4d_master", "p4d_replica"], var.server_type)
    error_message = "${var.server_type} is not one of p4d_master or p4d_replica."
  }
}

# tflint-ignore: terraform_unused_declarations
variable "storage_type" {
  type        = string
  description = "The type of backing store [EBS, FSxZ]"
  validation {
    condition     = contains(["EBS", "FSxZ"], var.storage_type)
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


########################################
# IAM CONFIGURATION
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

variable "vpc_id" {
  type        = string
  description = "The VPC where Helix Core should be deployed"
}

variable "create_default_sg" {
  type        = bool
  description = "Whether to create a default security group for the Helix Core instance."
  default     = true
}
