########################################
# GENERAL CONFIGURATION
########################################

variable "name" {
  type        = string
  description = "The name attached to VDI module resources."
  default     = "vdi"

  validation {
    condition     = length(var.name) > 1 && length(var.name) <= 50
    error_message = "The defined 'name' has too many characters (${length(var.name)}). This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appended to the beginning of most resource names."
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
    "iac-module"     = "VDI"
    "iac-provider"   = "Terraform"
  }
  description = "Tags to apply to resources."
}

########################################
# NETWORKING CONFIGURATION
########################################

variable "create_vpc" {
  type        = bool
  description = "Whether to create a new VPC for the VDI instance."
  default     = false
}

variable "vpc_id" {
  type        = string
  description = "The ID of the existing VPC to deploy the VDI instance into. Required if create_vpc is false."
  default     = null
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC. Only used if create_vpc is true."
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets. Only used if create_vpc is true."
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets. Only used if create_vpc is true."
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to use for the subnets. Only used if create_vpc is true."
  default     = []
}

variable "subnet_id" {
  type        = string
  description = "The subnet ID to deploy the VDI instance into. Private subnet is recommended for security. Required if create_vpc is false."
  default     = null
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether to associate a public IP address with the VDI instance."
  default     = false
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Whether to enable NAT Gateway for the private subnets. Only used if create_vpc is true."
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "Whether to use a single NAT Gateway for all private subnets. Only used if create_vpc is true and enable_nat_gateway is true."
  default     = true
}

########################################
# SECURITY CONFIGURATION
########################################

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access the VDI instance (RDP and NICE DCV ports)."
  default     = ["10.0.0.0/8"]
}

variable "key_pair_name" {
  type        = string
  description = "The name of an existing AWS key pair to use for the VDI instance. If not provided, a new key pair will be generated."
  default     = null
}

variable "create_key_pair" {
  type        = bool
  description = "Whether to create a new key pair if key_pair_name is not provided."
  default     = true
}

variable "admin_password" {
  type        = string
  description = "The administrator password for the Windows instance. This is required to set the Windows administrator password."
  default     = null
  sensitive   = true
}

variable "store_passwords_in_secrets_manager" {
  type        = bool
  description = "Whether to store generated passwords in AWS Secrets Manager."
  default     = true
}

########################################
# INSTANCE CONFIGURATION
########################################

variable "create_instance" {
  type        = bool
  description = "Whether to create the VDI instance. Set to false to only create the launch template."
  default     = true
}

variable "instance_type" {
  type        = string
  description = "The EC2 instance type for the VDI instance."
  default     = "g4dn.2xlarge"
}

variable "ami_id" {
  type        = string
  description = "The ID of a specific AMI to use for the VDI instance. If provided, this takes precedence over ami_prefix."
  default     = null
}

variable "ami_prefix" {
  type        = string
  description = "The prefix of the AMI name created by the packer template. Only used if ami_id is not provided."
  default     = "windows-server-2025"
}

variable "user_data_base64" {
  type        = string
  description = "Base64 encoded user data script to run on instance launch."
  default     = null
}

########################################
# STORAGE CONFIGURATION
########################################

variable "root_volume_size" {
  type        = number
  description = "The size of the root EBS volume in GB."
  default     = 512
}

variable "root_volume_type" {
  type        = string
  description = "The type of the root EBS volume."
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "Root volume type must be one of: gp2, gp3, io1, io2."
  }
}

variable "root_volume_iops" {
  type        = number
  description = "The IOPS for the root EBS volume (only applicable for gp3, io1, io2)."
  default     = 3000
}

variable "root_volume_throughput" {
  type        = number
  description = "The throughput for the root EBS volume in MB/s (only applicable for gp3)."
  default     = 125
}

variable "ebs_encryption_enabled" {
  type        = bool
  description = "Whether to enable EBS encryption for all volumes."
  default     = true
}

variable "ebs_kms_key_id" {
  type        = string
  description = "The KMS key ID to use for EBS encryption. If not specified, the default AWS managed key is used."
  default     = null
}

variable "additional_ebs_volumes" {
  type = list(object({
    device_name           = string
    volume_size           = number
    volume_type           = string
    iops                  = optional(number, 3000)
    throughput            = optional(number, 125)
    delete_on_termination = optional(bool, true)
  }))
  description = "List of additional EBS volumes to attach to the VDI instance."
  default     = []

  validation {
    condition = alltrue([
      for volume in var.additional_ebs_volumes : contains(["gp2", "gp3", "io1", "io2"], volume.volume_type)
    ])
    error_message = "All volume types must be one of: gp2, gp3, io1, io2."
  }
}
