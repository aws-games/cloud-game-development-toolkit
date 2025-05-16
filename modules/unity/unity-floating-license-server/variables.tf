variable "unity_ami_prefix" {
  type    = string
  default = "unity-license-server-*"
}

variable "instance_architecture" {
  type    = string
  default = "x86_64"
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "The instance type to use for the license server."
}

variable "vpc_id" {
  type        = string
  default     = null
  description = "The VPC ID to deploy the license server in."
}

variable "subnet_id" {
  type        = string
  default     = null
  description = "The subnet ID to deploy the license server in."
}

variable "eni_private_ips_list" {
  type        = list(string)
  default     = null
  description = "The list of private IPs to assign to the ENI."
}

variable "unity_license_server_s3_bucket_name" {
  type        = string
  default     = null
  description = "The name of the S3 bucket to use for the license server. Will fail if not specifed as this is the place to retain server registration information."
}

variable "create_eip" {
  type        = string
  default     = false
  description = "Whether to create an Elastic IP for the license server."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "The environment for the license server."
}

variable "unity_license_server_port" {
  type        = string
  default     = "8080"
  description = "The port for the license server."
}

variable "tags" {
  type = map(string)
  default = {
    "iac-management" = "CGD-Toolkit"
    "iac-module"     = "unity-license-server"
    "iac-provider"   = "Terraform"
  }
  description = "Tags for the license server"
}

variable "enable_instance_detailed_monitoring" {
  type        = bool
  default     = false
  description = "Enable detailed monitoring for the instance. This will increase the cost but ."
}

variable "instance_ebs_size" {
  type        = string
  default     = "20"
  description = "The size of the EBS volume in GB."
}
