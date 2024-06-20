variable "fully_qualified_domain_name" {
  type        = string
  description = "Provide the FQDN that should be used for routing."
  default     = null
}

variable "jenkins_agent_secret_arns" {
  type        = list(string)
  description = "A list of ARNs for secrets Jenkins should have access to"
  default     = []
}

variable "build_farm_compute" {
  type = map(object({
    ami : string
    instance_type : string
  }))
  description = "Each object corresponds to an autoscaling group that Jenkins can use as build nodes."
  default     = {}
}

variable "build_farm_fsx_openzfs_storage" {
  type = map(object({
    storage_type        = string
    throughput_capacity = number
    storage_capacity    = number
  }))
  description = "Each object corresponds to an OpenZFS filesystem that can be used for persistent build storage."
  default     = {}
}
