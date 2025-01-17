variable "name" {
  type = string 
  default = "teamcity"
  description = "The name applied to resources in the TeamCity module"
}

variable "container_cpu" {
    type = number
    default = 1024
    description = "The number of CPU units to allocate to the TeamCity server container"
}
variable "container_memory" {
    type = number
    default = 4096
    description = "The number of MB of memory to allocate to the TeamCity server container"
}

variable "container_name" {
    type = string
    default = "teamcity"
    description = "The name of the TeamCity server container"
}

variable "container_port" {
    type = number
    default = 8111
    description = "The port on which the TeamCity server container listens"
}

variable "service_subnets" {
    type = list(string)
    description = "The subnets in which the TeamCity server service will be deployed"
}

variable "vpc_id" {
    type = string
    description = "The ID of the VPC in which the service will be deployed"
}
# Logging
variable "teamcity_cloudwatch_log_retention_in_days" {
  type        = string
  description = "The log retention in days of the cloudwatch log group for TeamCity."
  default     = 365
}