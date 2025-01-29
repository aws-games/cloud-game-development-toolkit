variable "vpc_id" {
  type        = string
  description = "The VPC where Helix Core should be deployed"
}

variable "instance_subnet_id" {
  type        = string
  description = "The subnet where the Helix Core instance will be deployed."
}

variable "root_domain_name" {
  type        = string
  description = "The root domain name you would like to use for DNS."
}

variable "fsxn_region" {
  description = "The ID of the Storage Virtual Machine (SVM) for the FSx ONTAP filesystem."
  type        = string
  default     = "us-west-2"

  validation {
    condition     = length(var.fsxn_region) > 0
    error_message = "The fsxn_region variable must be provided when storage_type is FSxN."
  }
}

variable "protocol" {
  description = "Specify the protocol (NFS or ISCSI)"
  type        = string
  default     = ""
  validation {
    condition     = contains(["NFS", "ISCSI"], var.protocol)
    error_message = "The protocol variable must be either 'NFS' or 'ISCSI'."
  }
}

variable "fsxn_password" {
  description = "FSxN admin user password AWS secret manager arn"
  type        = string
  default     = ""
  validation {
    condition     = var.protocol != "ISCSI" || length(var.fsxn_password) > 0
    error_message = "The fsxn_password variable must be provided when storage_type is FSxN and ISCSI protocol."
  }
}

variable "fsxn_aws_profile" {
  description = "AWS profile for managing FSxN"
  type        = string
  default     = ""
  validation {
    condition     = var.protocol != "ISCSI" || length(var.fsxn_aws_profile) > 0
    error_message = "The fsxn_aws_profile variable must be provided when storage_type is FSxN and ISCSI protocol."
  }
}




