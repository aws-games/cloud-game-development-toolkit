variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "name_prefix" {
  description = "Name prefix for all VPC resources"
  type        = string
  nullable    = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "availability_zones" {
  description = "List of availability zones (minimum 2)"
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required."
  }
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch"
  type        = bool
  default     = false
}

variable "peering_routes" {
  description = "Routes to peered VPCs added to the private route table. The route table manages its routes inline, so routes created elsewhere with aws_route are removed on the next apply; pass them here instead."
  type = list(object({
    cidr_block                = string
    vpc_peering_connection_id = string
  }))
  default = []
}
