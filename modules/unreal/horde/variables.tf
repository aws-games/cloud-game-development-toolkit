########################################
# GENERAL CONFIGURATION
########################################
variable "name" {
  type        = string
  description = "The name attached to Unreal Engine Horde module resources."
  default     = "unreal-horde"

  validation {
    condition     = length(var.name) > 1 && length(var.name) <= 50
    error_message = "The defined 'name' has too many characters (${length(var.name)}). This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appeneded to the beginning of most resource names."
  default     = "cgd"

}

variable "environment" {
  type        = string
  description = "The current environment (e.g. Development, Staging, Production, etc.). This will tag ressources and set ASPNETCORE_ENVIRONMENT variable."
  default     = "Development"
}

variable "tags" {
  type = map(any)
  default = {
    "iac-management" = "CGD-Toolkit"
    "iac-module"     = "unreal-horde"
    "iac-provider"   = "Terraform"
  }
  description = "Tags to apply to resources."
}

variable "debug" {
  type        = bool
  description = "Set this flag to enable ECS execute permissions on the Unreal Horde container and force new service deployments on Terraform apply."
  default     = false
}

########################################
# NETWORKING
########################################

variable "vpc_id" {
  type        = string
  description = "The ID of the existing VPC you would like to deploy Unreal Horde into."
}

########################################
# ECS
########################################

variable "image" {
  type        = string
  description = "The Horde Server image to use in the ECS service."
  default     = "ghcr.io/epicgames/horde-server:latest-bundled"
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster to deploy the Unreal Horde into. Defaults to null and a cluster will be created."
  default     = null
}

variable "unreal_horde_service_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the Unreal Horde service into. Private subnets are recommended."
}

# - Container Specs -

variable "container_name" {
  type        = string
  description = "The name of the Unreal Horde container."
  default     = "unreal-horde-container"
  nullable    = false
}

variable "container_api_port" {
  type        = number
  description = "The container port for the Unreal Horde web server."
  default     = 5000
  nullable    = false
}

variable "container_grpc_port" {
  type        = number
  description = "The container port for the Unreal Horde GRPC channel."
  default     = 5002
  nullable    = false
}

variable "container_cpu" {
  type        = number
  description = "The CPU allotment for the Unreal Horde container."
  default     = 1024
  nullable    = false
}

variable "container_memory" {
  type        = number
  description = "The memory allotment for the Unreal Horde container."
  default     = 4096
  nullable    = false
}

variable "desired_container_count" {
  type        = number
  description = "The desired number of containers running Unreal Horde."
  default     = 1
  nullable    = false
}

########################################
# LOAD BALANCING
########################################

variable "create_external_alb" {
  type        = bool
  description = "Set this flag to true to create an external load balancer for Unreal Horde."
  default     = true
}

variable "create_internal_alb" {
  type        = bool
  description = "Set this flag to true to create an internal load balancer for Unreal Horde."
  default     = true
}

variable "unreal_horde_external_alb_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the Unreal Horde load balancer into. Public subnets are recommended."
  validation {
    condition     = var.create_external_alb ? length(var.unreal_horde_external_alb_subnets) > 0 : true
    error_message = "You must provide subnets for the external ALB."
  }
  default = []
}

variable "unreal_horde_internal_alb_subnets" {
  type        = list(string)
  description = "A list of subnets to deploy the Unreal Horde internal load balancer into. Private subnets are recommended."
  validation {
    condition     = var.create_internal_alb ? length(var.unreal_horde_internal_alb_subnets) > 0 : true
    error_message = "You must provide subnets for the internal ALB."
  }
  default = []
}

variable "enable_unreal_horde_alb_access_logs" {
  type        = bool
  description = "Enables access logging for the Unreal Horde ALB. Defaults to true."
  default     = true
}

variable "unreal_horde_alb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for Unreal Horde ALB access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
}

variable "unreal_horde_alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for Unreal Horde ALB access logs. If null the project prefix and module name are used."
  default     = null
}

variable "enable_unreal_horde_alb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the Unreal Horde ALB. Defaults to true."
  default     = false
}

variable "existing_security_groups" {
  type        = list(string)
  description = "A list of existing security group IDs to attach to the Unreal Horde load balancer."
  default     = []
}

variable "certificate_arn" {
  type        = string
  description = "The TLS certificate ARN for the Unreal Horde load balancer."
}

# - Logging -
variable "unreal_horde_cloudwatch_log_retention_in_days" {
  type        = string
  description = "The log retention in days of the cloudwatch log group for Unreal Horde."
  default     = 365
}

# - Security and Permissions -
variable "custom_unreal_horde_role" {
  type        = string
  description = "ARN of the custom IAM Role you wish to use with Unreal Horde."
  default     = null
}

variable "create_unreal_horde_default_role" {
  type        = bool
  description = "Optional creation of Unreal Horde default IAM Role. Default is set to true."
  default     = true
}

variable "create_unreal_horde_default_policy" {
  type        = bool
  description = "Optional creation of Unreal Horde default IAM Policy. Default is set to true."
  default     = true
}

variable "github_credentials_secret_arn" {
  type        = string
  description = "A secret containing the Github username and password with permissions to the EpicGames organization."
  default     = null
}

######################
# OIDC CONFIG
######################

variable "p4_port" {
  type        = string
  description = "The Perforce server to connect to."
  default     = null
}

variable "p4_super_user_username_secret_arn" {
  type        = string
  description = "Optionally provide the ARN of an AWS Secret for the p4d super user username."
  default     = null

  validation {
    condition     = var.p4_super_user_username_secret_arn == null || var.p4_port != null
    error_message = "p4_super_user_username_secret_arn cannot be passed unless p4_port is also passed."
  }
}

variable "p4_super_user_password_secret_arn" {
  type        = string
  description = "Optionally provide the ARN of an AWS Secret for the p4d super user password."
  default     = null

  validation {
    condition     = var.p4_super_user_password_secret_arn == null || var.p4_port != null
    error_message = "p4_super_user_password_secret_arn cannot be passed unless p4_port is also passed."
  }

  validation {
    condition     = (var.p4_super_user_username_secret_arn == null) == (var.p4_super_user_password_secret_arn == null)
    error_message = "p4_super_user_username_secret_arn and p4_super_user_password_secret_arn must be provided together."
  }
}

######################
# OIDC CONFIG
######################

variable "auth_method" {
  type        = string
  description = "The authentication method for the Horde server."
  default     = null
  validation {
    condition     = var.auth_method == null || contains(["Anonymous", "Okta", "OpenIdConnect", "Horde"], var.auth_method)
    error_message = "Invalid authentication method. Must be one of: Anonymous, Okta, OpenIdConnect, Horde"
  }
}

variable "oidc_authority" {
  type        = string
  description = "The authority for the OIDC authentication provider used."
  default     = null
  validation {
    condition     = var.auth_method != null && contains(["Okta", "OpenIdConnect"], var.auth_method) ? var.oidc_authority != null : var.oidc_authority == null
    error_message = "An OIDC authority must be provided for Okta and OpenIdConnect authentication methods."
  }
}

variable "oidc_audience" {
  type        = string
  description = "The audience used for validating externally issued tokens."
  default     = null
  validation {
    condition     = var.auth_method != null && contains(["Okta", "OpenIdConnect"], var.auth_method) ? var.oidc_audience != null : var.oidc_audience == null
    error_message = "An OIDC audience must be provided for Okta and OpenIdConnect authentication methods."
  }
}

variable "oidc_client_id" {
  type        = string
  description = "The client ID used for authenticating with the OIDC provider."
  default     = null
  validation {
    condition     = var.auth_method != null && contains(["Okta", "OpenIdConnect"], var.auth_method) ? var.oidc_client_id != null : var.oidc_client_id == null
    error_message = "An OIDC client ID must be provided for Okta and OpenIdConnect authentication methods."
  }
}

variable "oidc_client_secret" {
  type        = string
  description = "The client secret used for authenticating with the OIDC provider."
  default     = null
  validation {
    condition     = var.auth_method != null && contains(["Okta", "OpenIdConnect"], var.auth_method) ? var.oidc_client_secret != null : var.oidc_client_secret == null
    error_message = "An OIDC client secret must be provided for Okta and OpenIdConnect authentication methods."
  }
}

variable "oidc_signin_redirect" {
  type        = string
  description = "The sign-in redirect URL for the OIDC provider."
  default     = null
  validation {
    condition     = var.auth_method != null && contains(["Okta", "OpenIdConnect"], var.auth_method) ? var.oidc_signin_redirect != null : var.oidc_signin_redirect == null
    error_message = "An OIDC sign-in redirect URL must be provided for Okta and OpenIdConnect authentication methods."
  }
}

variable "admin_claim_type" {
  type        = string
  description = "The claim type for administrators."
  default     = null
}

variable "admin_claim_value" {
  type        = string
  description = "The claim value for administrators."
  default     = null
}

######################
# DOCUMENTDB CONFIG
######################

variable "database_connection_string" {
  type        = string
  description = "The database connection string that Horde should use."
  default     = null
}

variable "docdb_instance_count" {
  type        = number
  description = "The number of instances to provision for the Horde DocumentDB cluster."
  default     = 2
}

variable "docdb_instance_class" {
  type        = string
  description = "The instance class for the Horde DocumentDB cluster."
  default     = "db.t4g.medium"
}

variable "docdb_master_username" {
  type        = string
  description = "Master username created for DocumentDB cluster."
  default     = "horde"
}

variable "docdb_master_password" {
  type        = string
  description = "Master password created for DocumentDB cluster."
  default     = "mustbeeightchars"
}

variable "docdb_backup_retention_period" {
  type        = number
  description = "Number of days to retain backups for DocumentDB cluster."
  default     = 7
}

variable "docdb_preferred_backup_window" {
  type        = string
  description = "The preferred window for DocumentDB backups to be created."
  default     = "07:00-09:00"
}

variable "docdb_skip_final_snapshot" {
  type        = bool
  description = "Flag for whether a final snapshot should be created when the cluster is destroyed."
  default     = true
}

variable "docdb_storage_encrypted" {
  type        = bool
  description = "Configure DocumentDB storage at rest."
  default     = true
}

######################
# ELASTICACHE CONFIG
######################

variable "elasticache_engine" {
  description = "The engine to use for ElastiCache (redis or valkey)"
  type        = string
  default     = "redis"
  validation {
    condition     = contains(["redis", "valkey"], var.elasticache_engine)
    error_message = "Invalid engine. Must be one of: redis, valkey"
  }
}

variable "elasticache_redis_engine_version" {
  type        = string
  description = "The version of the Redis engine to use."
  default     = "7.0"
}
variable "elasticache_valkey_engine_version" {
  type        = string
  description = "The version of the ElastiCache engine to use."
  default     = "7.2"
}

variable "elasticache_redis_parameter_group_name" {
  type        = string
  description = "The name of the Redis parameter group to use."
  default     = "default.redis7"
}
variable "elasticache_valkey_parameter_group_name" {
  type        = string
  description = "The name of the Valkey parameter group to use."
  default     = "default.valkey7"
}
variable "elasticache_port" {
  type        = number
  description = "The port for the ElastiCache cluster."
  default     = 6379
}
variable "elasticache_cluster_count" {
  type        = number
  description = "Number of cache cluster to provision in the Elasticache cluster."
  default     = 2
}

variable "custom_cache_connection_config" {
  type        = string
  description = "The redis-compatible connection configuration that Horde should use."
  default     = null
}

variable "elasticache_node_count" {
  type        = number
  description = "Number of cache nodes to provision in the Elasticache cluster."
  default     = 1
}

variable "elasticache_node_type" {
  type        = string
  description = "The type of nodes provisioned in the Elasticache cluster."
  default     = "cache.t4g.micro"
}

variable "elasticache_snapshot_retention_limit" {
  type        = number
  description = "The number of Elasticache snapshots to retain."
  default     = 5
}

######################
# BUILD AGENT CONFIG
######################
variable "agents" {
  type = map(object({
    ami           = string
    instance_type = string
    block_device_mappings = list(
      object({
        device_name = string
        ebs = object({
          volume_size = number
        })
      })
    )
    min_size = optional(number, 0)
    max_size = optional(number, 1)
  }))
  description = "Configures autoscaling groups to be used as build agents by Unreal Engine Horde."
  default     = {}
}

variable "agent_dotnet_runtime_version" {
  type        = string
  description = "The dotnet-runtime-{} package to install (see your engine version's release notes for supported version)"
  default     = "6.0"
}

variable "fully_qualified_domain_name" {
  type        = string
  description = "The fully qualified domain name where your Unreal Engine Horde server will be available. This agents will use this to enroll."
}

variable "enable_new_agents_by_default" {
  type        = bool
  description = "Set this flag to automatically enable new agents that enroll with the Horde Server."
  default     = false
}
