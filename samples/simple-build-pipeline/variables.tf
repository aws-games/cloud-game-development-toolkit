variable "helix_authentication_service_certificate_arn" {
  type        = string
  description = "The certificate used by the Helix Authentication Service"
}

variable "helix_swarm_certificate_arn" {
  type        = string
  description = "The certificate used by Helix Swarm"
}

variable "helix_swarm_environment_variables" {
  type = object({
    p4d_super_user_arn          = string
    p4d_super_user_password_arn = string
    p4d_swarm_user_arn          = string
    p4d_swarm_password_arn      = string
  })
  description = "The required environment variables for Helix Swarm configuration."
}

variable "jenkins_certificate_arn" {
  type        = string
  description = "The certificate used by Jenkins"
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
}
