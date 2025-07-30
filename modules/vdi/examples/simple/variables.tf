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
