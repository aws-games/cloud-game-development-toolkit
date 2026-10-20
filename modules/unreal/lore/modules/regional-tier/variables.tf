# =============================================================================
# Identity
# =============================================================================

variable "name_prefix" {
  description = "Prefix for all resource names in this region (e.g. 'lore-dev-west'). Must differ from the write region's prefix."
  type        = string

  validation {
    condition     = length(var.name_prefix) >= 4 && length(var.name_prefix) <= 20
    error_message = "name_prefix must be 4-20 characters."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod), passed to the compute submodule for sizing defaults"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}

# =============================================================================
# The write region this tier belongs to
# =============================================================================

variable "write_region" {
  description = "AWS region of the write tier (e.g. us-east-2). Used to reach its DynamoDB locks table."
  type        = string
}

variable "write_region_vpc_cidr" {
  description = "CIDR of the write region's VPC. Allowed to reach this tier on 41337/41340 so the write tier can replicate to it; this tier is allowed out to it on the same ports."
  type        = string
}

variable "write_tier_dns_name" {
  description = "Write tier Cloud Map name (root module output write_tier_dns_name). Must resolve in this VPC: associate the write region's hosted zone (output service_discovery_hosted_zone_id) with this VPC."
  type        = string
}

variable "write_tier_ca_certificate_pem" {
  description = "Write tier CA certificate (root module output ca_certificate_pem) so this tier trusts it over TLS"
  type        = string
}

variable "locks_table_name" {
  description = "Write region's DynamoDB locks table name (root output). Shared so exclusive checkouts taken in one office are seen in the other."
  type        = string
}

variable "locks_table_arn" {
  description = "Write region's DynamoDB locks table ARN, for this tier's IAM policy"
  type        = string
}

variable "immutable_tables" {
  description = <<-EOT
    How this region gets its two immutable DynamoDB tables (fragments, fragment-metadata).
    "create" makes its own (Lore writes the rows when fragments arrive by replication or local
    commit). "global_table" expects them to already exist in this region as replicas created by
    the write region's fragment_replication.global_tables_region, and looks them up by the names
    given.
  EOT
  type = object({
    mode                         = optional(string, "create")
    fragments_table_name         = optional(string)
    fragment_metadata_table_name = optional(string)
  })
  default = {}

  validation {
    condition     = contains(["create", "global_table"], var.immutable_tables.mode)
    error_message = "immutable_tables.mode must be \"create\" or \"global_table\"."
  }
  validation {
    condition     = var.immutable_tables.mode != "global_table" || (var.immutable_tables.fragments_table_name != null && var.immutable_tables.fragment_metadata_table_name != null)
    error_message = "immutable_tables.mode = \"global_table\" requires both table names."
  }
}

# =============================================================================
# Fragment replication back to the write region
# =============================================================================

variable "enable_replication" {
  description = "Replicate this region's commits back to the write region's bucket (S3 Cross-Region Replication). false for one-way replication."
  type        = bool
  default     = false
}

variable "replication_destination_bucket_arn" {
  description = "Write region's fragments bucket ARN. Required when enable_replication is true."
  type        = string
  default     = null
}

variable "replication_time_control" {
  description = "Enable S3 Replication Time Control on the reverse replication rule"
  type        = bool
  default     = false
}

variable "replication_peers" {
  description = "Lore servers this tier forwards every put to. Normally the write tier as locality = \"OtherRegion\". Use SameRegion with enable_same_region_write = false to use the write tier as a read-only fallback for content that has not replicated yet."
  type = list(object({
    address  = string
    port     = optional(number, 41340)
    locality = string
  }))
  default = []

  validation {
    condition     = alltrue([for p in var.replication_peers : contains(["SameRegion", "OtherRegion"], p.locality)])
    error_message = "replication_peers[*].locality must be \"SameRegion\" or \"OtherRegion\"."
  }
}

variable "enable_same_region_write" {
  description = "Whether SameRegion peers also receive writes (Lore default true)"
  type        = bool
  default     = true
}

# =============================================================================
# VPC
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR for this region's VPC. Must not overlap the write region's VPC (peering)."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for the VPC. Null uses the first two in the region."
  type        = list(string)
  default     = null
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch"
  type        = bool
  default     = false
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks of this office's clients allowed to reach the tier on 41337 and 41339"
  type        = list(string)
}

# =============================================================================
# Compute (same inputs as the root module)
# =============================================================================

variable "container_image" {
  description = "loreserver image URI in THIS region's ECR (pull locally; replicate the repository)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type with NVMe instance store"
  type        = string
  default     = "c8gd.large"
}

variable "ami_id" {
  description = "AMI ID override. Null uses the latest ECS-optimized AL2023."
  type        = string
  default     = null
}

variable "container_user" {
  description = "User/group for the container process"
  type        = string
  default     = "65534"
}

variable "asg_min_size" {
  type    = number
  default = null
}

variable "asg_max_size" {
  type    = number
  default = null
}

variable "asg_desired_size" {
  type    = number
  default = null
}

variable "container_memory_reservation" {
  type    = number
  default = null
}

variable "cache_max_size_bytes" {
  type    = number
  default = 0
}

variable "deployment_minimum_healthy_percent" {
  type    = number
  default = 66
}

variable "deployment_maximum_percent" {
  type    = number
  default = 200
}

# =============================================================================
# Auth / TLS / observability (same semantics as the root module)
# =============================================================================

variable "auth_mode" {
  description = "Must match the write region: none, cognito, or external"
  type        = string
  default     = "none"
}

variable "auth_jwk_endpoint" {
  type    = string
  default = null
}

variable "auth_jwt_issuer" {
  type    = string
  default = null
}

variable "auth_jwt_audience" {
  type    = list(string)
  default = []
}

variable "tls_certificate_secret_arn" {
  type    = string
  default = null
}

variable "tls_private_key_secret_arn" {
  type    = string
  default = null
}

variable "tls_san_dns_names" {
  type    = list(string)
  default = []
}

variable "hmac_key_secret_arn" {
  type    = string
  default = null
}

variable "enable_otel_sidecar" {
  type    = bool
  default = true
}

variable "otel_collector_image" {
  type    = string
  default = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
}

variable "enable_xray_smoke_test" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 30
}

# =============================================================================
# Safety / storage
# =============================================================================

variable "enable_force_destroy" {
  type    = bool
  default = false
}

variable "enable_deletion_protection" {
  type    = bool
  default = true
}

variable "intelligent_tiering_archive_days" {
  type    = number
  default = 90
}

variable "intelligent_tiering_deep_archive_days" {
  type    = number
  default = 180
}
