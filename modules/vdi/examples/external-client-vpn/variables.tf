variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Project prefix for resource naming"
  type        = string
  default     = "my-company"
}

variable "vpc_name" {
  description = "Name tag of existing VPC"
  type        = string
}

variable "existing_client_vpn_name" {
  description = "Name tag of existing Client VPN endpoint"
  type        = string
}

variable "client_vpn_cidr" {
  description = "CIDR block of your existing Client VPN (for security group rules)"
  type        = string
  default     = "192.168.0.0/16"
}

variable "create_dns_records" {
  description = "Create internal DNS records for easy workstation access"
  type        = bool
  default     = true
}

variable "internal_domain" {
  description = "Internal domain name for DNS records"
  type        = string
  default     = "vdi.internal"
}