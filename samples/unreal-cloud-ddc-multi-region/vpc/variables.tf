variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR Block"
}

variable "additional_tags" {
  default     = {}
  description = "Additional resource tags"
  type        = map(string)
}

variable "private_subnets_cidrs" {
  type        = list(string)
  description = "Private Subnet CIDR Range"
}

variable "public_subnets_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR Range"
}

variable "region" {
  type        = string
  description = "AWS Region"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability Zones"
}
