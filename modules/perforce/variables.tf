variable "vpc_id" {
  type        = string
  description = "The VPC to deploy this Perforce module into."
}

variable "helix_core_servers" {
  type = map(object({
    server_type              = string // "commit" "edge" "standby"
    instance_type            = optional(string, "c6in.large")
    instance_subnet_id       = string
    existing_security_groups = optional(list(string), null)
    internal                 = optional(bool, false)
    storage = object({
      type                 = optional(string, "EBS")
      depot_volume_size    = optional(number, 64) // size of the depot volume in GiB
      metadata_volume_size = optional(number, 32) // size of the metadata volume in GiB
      logs_volume_size     = optional(number, 32) // size of the logs volume in GiB
    })
    custom_helix_core_role         = optional(string, null)
    create_helix_core_default_role = optional(bool, true)
  }))
  default = {}

  validation {
    condition = alltrue([
      for server in var.helix_core_servers : contains(["p4d_master", "p4d_replica"], server.server_type)
    ])
    error_message = "Sorry. Invalid server_type. The valid server types are 'p4d_master' and 'p4d_replica'"
  }

  validation {
    condition = alltrue([
      for server in var.helix_core_servers : contains(["EBS", "FSxZ"], lookup(server.storage, "type", null))
    ])
    error_message = "Sorry. Invalid storage type. The valid storage types are 'EBS' and 'FSxZ'"
  }
}

variable "helix_swarm" {
  type = object({
    alb_subnet_ids                       = list(string)
    instance_subnet_id                   = string
    instance_type                        = optional(string, null)
    existing_security_groups             = optional(list(string), null)
    internal                             = optional(bool, false)
    certificate_arn                      = string
    enable_swarm_alb_access_logs         = optional(bool, false)
    swarm_alb_access_logs_bucket         = optional(string, null)
    swarm_alb_access_logs_prefix         = optional(string, null)
    enable_swarm_alb_deletion_protection = optional(bool, false)
    custom_swarm_role                    = optional(string, null)
    create_swarm_default_role            = optional(bool, true)
  })
  default     = null
  description = "Helix Swarm deployment settings."

  # TODO: Add validation to ensure cert and subnet are included if create is true
}

# - General -
variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appeneded to the beginning of most resource names."
  default     = "cgd"
}

variable "environment" {
  type        = string
  description = "The current environment (e.g. dev, prod, etc.). Defaults to dev."
  default     = "dev"
}

variable "tags" {
  type = map(any)
  default = {
    "IAC_MANAGEMENT" = "CGD-Toolkit"
    "IAC_MODULE"     = "Perforce"
    "IAC_PROVIDER"   = "Terraform"
  }
  description = "Tags to apply to resources."
}

