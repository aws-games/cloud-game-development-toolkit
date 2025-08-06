variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in"
  default     = "us-west-2"
}

variable "admin_password" {
  type        = string
  description = "The administrator password for the Windows instance"
  sensitive   = true
  # No default - should be provided via command line or .tfvars file
}

variable "allowed_ip_address" {
  type        = string
  description = "Your public IP address in CIDR notation (e.g., 203.0.113.1/32)"
  default     = "" # Should be provided via command line or .tfvars file
}

variable "name" {
  type        = string
  description = "The name attached to resources"
  default     = "new-vpc-vdi"
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload"
  default     = "cgd"
}

variable "environment" {
  type        = string
  description = "The current environment (e.g. dev, prod, etc.)"
  default     = "dev"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to resources"
  default     = {}
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to use for the subnets"
  default     = []
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Whether to enable NAT Gateway for the private subnets"
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "Whether to use a single NAT Gateway for all private subnets"
  default     = true
}
