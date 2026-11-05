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
  description = "CIDR of the write region's VPC. Allowed to and from this tier on 41337. Also used for 41340 when write_tier_replication_cidrs is null; set that to the write tier's private subnet CIDRs instead."
  type        = string

  validation {
    condition     = can(cidrhost(var.write_region_vpc_cidr, 0)) && !contains(["0.0.0.0/0", "::/0"], var.write_region_vpc_cidr)
    error_message = "write_region_vpc_cidr must be a specific valid CIDR, not 0.0.0.0/0 or ::/0."
  }
}

variable "write_tier_replication_cidrs" {
  description = <<-EOT
    CIDRs allowed to and from this cache on replication port 41340. Port 41340 has no JWT or
    client-certificate check, so this list is its only access control. Give the write tier's
    private subnet CIDRs (root module output private_subnet_cidrs). Null falls back to
    write_region_vpc_cidr, which is broader than needed.
  EOT
  type        = list(string)
  default     = null

  validation {
    condition     = var.write_tier_replication_cidrs == null ? true : (length(var.write_tier_replication_cidrs) > 0 && !contains(var.write_tier_replication_cidrs, "0.0.0.0/0") && !contains(var.write_tier_replication_cidrs, "::/0"))
    error_message = "write_tier_replication_cidrs must be null or a nonempty list of specific CIDRs, never 0.0.0.0/0 or ::/0."
  }
}

variable "write_tier_dns_name" {
  description = "Write tier Cloud Map name (root module output write_tier_dns_name). Must resolve in this VPC: associate the write region's hosted zone (output service_discovery_hosted_zone_id) with this VPC. Used for uploads, cache misses (41340) and nothing else."
  type        = string
}

variable "write_tier_ca_certificate_pem" {
  description = "Write tier CA certificate (root module output ca_certificate_pem) so this cache trusts it over TLS"
  type        = string
}

variable "dynamodb_endpoint_url" {
  description = "Write Region DynamoDB interface endpoint URL (root output dynamodb_interface_endpoint_url). Sets Lore's native endpoint URL for branch-pointer and lock clients, so calls cross VPC peering instead of the cache VPC's NAT. Null keeps the public regional endpoint."
  type        = string
  default     = null

  validation {
    condition = var.dynamodb_endpoint_url == null ? true : can(regex(
      "^https://vpce-[a-z0-9-]+\\.dynamodb\\.${var.write_region}\\.vpce\\.[a-z0-9.-]+$",
      var.dynamodb_endpoint_url
    ))
    error_message = "dynamodb_endpoint_url must be null or an endpoint-specific HTTPS DynamoDB URL in write_region."
  }
}

variable "branch_pointer_access" {
  description = <<-EOT
    How this cache reaches the write region's branch pointers. "dynamodb" (default): the write
    region's DynamoDB table used directly. "write_tier": Lore's remote mutable store, each
    operation forwarded to the write tier over QUIC; measured slightly slower for push and
    status, and `lore repository list` fails through it at Lore v0.10.1. Locks always use the
    write region's DynamoDB table, since Lore has no remote lock store.
    "write_tier" is rejected when auth_mode is not "none": this module does not forward client
    tokens to the write tier, so an authenticated write tier would refuse the forwarded calls.
  EOT
  type        = string
  default     = "dynamodb"
  nullable    = false

  validation {
    condition     = contains(["write_tier", "dynamodb"], var.branch_pointer_access)
    error_message = "branch_pointer_access must be \"write_tier\" or \"dynamodb\"."
  }

  validation {
    condition     = !(var.branch_pointer_access == "write_tier" && var.auth_mode != "none")
    error_message = "branch_pointer_access = \"write_tier\" is not supported with auth_mode = \"external\": token forwarding to the write tier is not implemented. Use \"dynamodb\"."
  }
}

variable "mutable_store_table_name" {
  description = "Write region's DynamoDB mutable-store table (branch pointers), used cross-region when branch_pointer_access = \"dynamodb\"."
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
  description = "Specific CIDR blocks of this office's clients allowed to reach the cache on 41337 and 41339. Public catch-all ranges are rejected."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.allowed_ingress_cidrs) > 0 && !contains(var.allowed_ingress_cidrs, "0.0.0.0/0") && !contains(var.allowed_ingress_cidrs, "::/0")
    error_message = "allowed_ingress_cidrs must contain at least one specific CIDR and must not include 0.0.0.0/0 or ::/0."
  }
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
  description = <<-EOT
    "none" or "external". JWT validation applies to client port 41337 only; port 41340 has no
    JWT or mTLS check. "external" requires an HTTPS auth_jwk_endpoint, an HTTPS auth_jwt_issuer
    and a nonempty auth_jwt_audience. If the write region uses Cognito, pass "external" with the
    root module's auth_jwk_endpoint and auth_jwt_issuer outputs.
  EOT
  type        = string
  default     = "none"
  nullable    = false

  validation {
    condition     = contains(["none", "external"], var.auth_mode)
    error_message = "regional-cache auth_mode must be \"none\" or \"external\". For a Cognito write region, use \"external\" with the root module's auth_jwk_endpoint and auth_jwt_issuer outputs."
  }
}

variable "auth_jwk_endpoint" {
  description = "HTTPS JWKS endpoint. Required when auth_mode = \"external\"."
  type        = string
  default     = null

  validation {
    condition     = var.auth_mode == "none" || (var.auth_jwk_endpoint != null && startswith(coalesce(var.auth_jwk_endpoint, "-"), "https://"))
    error_message = "auth_jwk_endpoint must be an https:// URL when auth_mode = \"external\"."
  }
}

variable "auth_jwt_issuer" {
  description = "HTTPS JWT issuer. Required when auth_mode = \"external\"."
  type        = string
  default     = null

  validation {
    condition     = var.auth_mode == "none" || (var.auth_jwt_issuer != null && startswith(coalesce(var.auth_jwt_issuer, "-"), "https://"))
    error_message = "auth_jwt_issuer must be an https:// URL when auth_mode = \"external\"."
  }
}

variable "auth_jwt_audience" {
  description = "JWT audience values accepted. Must contain at least one nonempty value when auth_mode = \"external\"."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = var.auth_mode == "none" || (length(var.auth_jwt_audience) > 0 && alltrue([for a in var.auth_jwt_audience : trimspace(a == null ? "" : a) != ""]))
    error_message = "auth_jwt_audience must contain at least one nonempty value when auth_mode = \"external\"."
  }
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

