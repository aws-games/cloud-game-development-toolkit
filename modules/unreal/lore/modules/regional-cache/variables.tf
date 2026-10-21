# =============================================================================
# Identity
# =============================================================================

variable "name_prefix" {
  description = "Prefix for all resource names in this region (e.g. 'lore-dev-london'). Must differ from the write region's prefix."
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

variable "write_region_rtt_ms" {
  description = "Measured round-trip time to the write region in ms, used to size the QUIC congestion window for uploads and cache misses (Lore default 100). Null keeps Lore's default."
  type        = number
  default     = null
}

variable "write_region_vpc_cidr" {
  description = "CIDR of the write region's VPC. Allowed to reach this tier on 41337/41340 so the write tier can replicate to it; this tier is allowed out to it on the same ports."
  type        = string
}

variable "write_tier_dns_name" {
  description = "Write tier Cloud Map name (root module output write_tier_dns_name). Must resolve in this VPC: associate the write region's hosted zone (output service_discovery_hosted_zone_id) with this VPC. Used for uploads, cache misses (41340) and nothing else."
  type        = string
}

variable "write_tier_ca_certificate_pem" {
  description = "Write tier CA certificate (root module output ca_certificate_pem) so this cache trusts it over TLS"
  type        = string
}

variable "mutable_store_table_name" {
  description = "Write region's DynamoDB mutable-store table (branch pointers). Used cross-region: Lore's remote mutable store cannot list repositories (v0.10.1), so the cache talks to the write region's table directly."
  type        = string
}

variable "mutable_store_table_arn" {
  description = "Write region's mutable-store table ARN, for this tier's IAM policy"
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

# =============================================================================
# VPC
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR for this region's VPC. Must not overlap the write region's VPC (peering)."
  type        = string
}

variable "vpc_peering_routes" {
  description = "Routes to peered VPCs (the write region) for this cache's private route table. Use this rather than aws_route resources, which the route table's inline routes remove on the next apply."
  type = list(object({
    cidr_block                = string
    vpc_peering_connection_id = string
  }))
  default = []
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
  description = "CIDR blocks of this office's clients allowed to reach the cache on 41337 and 41339"
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

