variable "monitoring_subnets" {
  type        = list(string)
  default     = []
  description = "A list of subnet IDs where Scylla will be deployed. Private subnets are strongly recommended."
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where Scylla will be deployed."
}
