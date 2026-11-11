variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}

variable "environment" {
  description = "Environment name (dev, staging, prod) — used for ASG defaults"
  type        = string
}

variable "fragment_bucket_arn" {
  description = "ARN of the S3 fragment bucket. Null when durable_store_mode = \"replicated\" (the node has no bucket of its own)."
  type        = string
  default     = null
}

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs for IAM policy"
  type        = list(string)
}

variable "locks_table_arn" {
  description = "ARN of the locks DynamoDB table (for GSI access)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ASG instances"
  type        = list(string)
}

variable "server_security_group_id" {
  description = "Security group ID for Lore server instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for ECS instances. Unknown types fall back to 28 GiB memory reservation and 937 GB cache size."
  type        = string
  default     = "i4i.xlarge"
}

variable "ami_id" {
  description = "AMI ID override. If null, uses latest ECS-optimized AL2023."
  type        = string
  default     = null
}

variable "udp_buffer_max_bytes" {
  description = "Host net.core.rmem_max / wmem_max for Lore's QUIC (UDP) sockets. Lore v0.11.0+ asks Linux to allow at least 524288; the AL2023 default is 212992."
  type        = number
  default     = 4194304

  validation {
    condition     = var.udp_buffer_max_bytes >= 524288
    error_message = "udp_buffer_max_bytes must be at least 524288 (Lore's documented minimum)."
  }
}

variable "container_user" {
  description = "User/group for the container process (e.g., '65534', '1000:1000'). Must be numeric UID or UID:GID."
  type        = string
  default     = "65534"

  validation {
    condition     = can(regex("^[0-9]+(:[0-9]+)?$", var.container_user))
    error_message = "container_user must be a numeric UID (e.g., '65534') or UID:GID (e.g., '1000:1000')."
  }
}

variable "asg_min_size" {
  description = "ASG minimum size. Null = environment-aware default (dev:0, staging:0, prod:1)"
  type        = number
  default     = null
}

variable "asg_max_size" {
  description = "ASG maximum size. Null = environment-aware default (dev:1, staging:1, prod:3)"
  type        = number
  default     = null
}

variable "asg_desired_size" {
  description = "ASG desired capacity. Null = environment-aware default (dev:0, staging:1, prod:1)"
  type        = number
  default     = null
}

# =============================================================================
# ECS Service (Phase 5B)
# =============================================================================

variable "container_image" {
  description = "Loreserver container image URI"
  type        = string
}

variable "fragment_bucket_name" {
  description = "S3 fragment bucket name (for LORE__* env vars)"
  type        = string
}

variable "fragments_table_name" {
  description = "DynamoDB fragments table name"
  type        = string
}

variable "fragment_metadata_table_name" {
  description = "DynamoDB fragment metadata table name"
  type        = string
}

variable "mutable_store_table_name" {
  description = "DynamoDB mutable store table name"
  type        = string
}

variable "locks_table_name" {
  description = "DynamoDB locks table name"
  type        = string
}

# =============================================================================
# Phase 6: Security & Observability
# =============================================================================

variable "tls_certificate_secret_arn" {
  description = "Secrets Manager ARN for the server TLS leaf certificate. Null generates a private CA and server certificate. Custom TLS requires certificate, private-key, and CA secret ARNs together."
  type        = string
  default     = null

  validation {
    condition = (
      var.tls_certificate_secret_arn == null &&
      var.tls_private_key_secret_arn == null &&
      var.tls_ca_certificate_secret_arn == null
      ) || (
      var.tls_certificate_secret_arn != null &&
      var.tls_private_key_secret_arn != null &&
      var.tls_ca_certificate_secret_arn != null
    )
    error_message = "Set tls_certificate_secret_arn, tls_private_key_secret_arn, and tls_ca_certificate_secret_arn together, or leave all three null."
  }
}

variable "tls_private_key_secret_arn" {
  description = "Secrets Manager ARN for the server TLS private key. Custom TLS requires the matching certificate and CA secret ARNs."
  type        = string
  default     = null
}

variable "tls_ca_certificate_secret_arn" {
  description = "Secrets Manager ARN for a dedicated Lore CA bundle containing the complete issuer chain and trust anchors for the custom server and replication-client certificates. Required with custom TLS; do not use a shared enterprise CA."
  type        = string
  default     = null
}

variable "tls_client_certificate_secret_arn" {
  description = "Secrets Manager ARN for a dedicated replication-client certificate. Required with its key when custom TLS protects an enabled port 41340 listener. Null uses a generated client certificate for generated TLS."
  type        = string
  default     = null

  validation {
    condition = (
      var.tls_client_certificate_secret_arn == null &&
      var.tls_client_private_key_secret_arn == null
      ) || (
      var.tls_client_certificate_secret_arn != null &&
      var.tls_client_private_key_secret_arn != null
    )
    error_message = "Set tls_client_certificate_secret_arn and tls_client_private_key_secret_arn together, or leave both null."
  }

  validation {
    condition = var.tls_certificate_secret_arn != null || (
      var.tls_client_certificate_secret_arn == null &&
      var.tls_client_private_key_secret_arn == null
    )
    error_message = "Do not combine generated server TLS with custom replication-client secrets. Leave all TLS ARNs null for one generated PKI, or supply the complete custom set."
  }

  validation {
    condition = !(
      var.durable_store_mode == "replicated" ||
      length(var.replication_peers) > 0
      ) || var.tls_certificate_secret_arn == null || (
      var.tls_client_certificate_secret_arn != null &&
      var.tls_client_private_key_secret_arn != null
    )
    error_message = "An outgoing replication client with custom TLS requires dedicated client certificate and private-key secret ARNs."
  }
}

variable "tls_client_private_key_secret_arn" {
  description = "Secrets Manager ARN for the dedicated replication-client private key. Required with its certificate for custom replication TLS."
  type        = string
  default     = null
}

variable "tls_material_version" {
  description = "Rollout token for custom TLS secrets. Change it whenever a certificate, key, or CA value rotates under an unchanged secret ARN so ECS registers and deploys a new task definition. Generated TLS derives this token automatically."
  type        = string
  default     = "1"
  nullable    = false

  validation {
    condition     = trimspace(var.tls_material_version) != ""
    error_message = "tls_material_version must not be empty."
  }
}

variable "tls_san_dns_names" {
  description = "Additional DNS SANs for the self-signed TLS certificate (e.g., custom domain names)"
  type        = list(string)
  default     = []
}

variable "hmac_key_secret_arn" {
  description = "Secrets Manager ARN for HMAC signing key. If null, a random 32-byte key is generated."
  type        = string
  default     = null
}

variable "write_tier_dns_name" {
  description = "Cloud Map DNS name (included in self-signed cert SAN)"
  type        = string
}

variable "enable_otel_sidecar" {
  description = "Deploy ADOT sidecar for OpenTelemetry collection (CloudWatch + X-Ray)"
  type        = bool
  default     = true
}

variable "otel_collector_image" {
  description = "ADOT collector image URI. Override to use a private ECR mirror."
  type        = string
  default     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
}

variable "auth_mode" {
  description = "Authentication mode: 'none' (open access), 'cognito' (AWS-native M2M), 'external' (bring your own IdP)"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "cognito", "external"], var.auth_mode)
    error_message = "auth_mode must be 'none', 'cognito', or 'external'."
  }
}

variable "auth_jwk_endpoint" {
  description = "JWK endpoint URL (required when auth_mode = 'external')"
  type        = string
  default     = null

  validation {
    condition     = var.auth_mode != "external" || var.auth_jwk_endpoint != null
    error_message = "auth_jwk_endpoint is required when auth_mode = 'external'."
  }
}

variable "auth_jwt_issuer" {
  description = "JWT issuer string (required when auth_mode = 'external')"
  type        = string
  default     = null

  validation {
    condition     = var.auth_mode != "external" || var.auth_jwt_issuer != null
    error_message = "auth_jwt_issuer is required when auth_mode = 'external'."
  }
}

variable "auth_jwt_audience" {
  description = "JWT audience values the server accepts"
  type        = list(string)
  default     = []
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower limit on running tasks during deployment (% of desired_count). Default 66 allows single-task services to deploy without ENI deadlock."
  type        = number
  default     = 66
}

variable "deployment_maximum_percent" {
  description = "Upper limit on running tasks during deployment (% of desired_count)."
  type        = number
  default     = 200
}

variable "container_memory_reservation" {
  description = "Soft memory reservation (MiB) for the loreserver container. If null, auto-sizes based on instance type."
  type        = number
  default     = null
}

variable "cache_max_size_bytes" {
  description = "NVMe cache maximum size in bytes. 0 = auto-size to 80% of instance store capacity."
  type        = number
  default     = 0
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days. Valid values: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653."
  type        = number
  default     = 30
}

variable "enable_xray_smoke_test" {
  description = "Deploy X-Ray pipeline smoke test Lambda (validates trace delivery + IAM)"
  type        = bool
  default     = true
}

variable "enable_replication" {
  description = "Enable the fail-closed mTLS QUIC internal replication endpoint on UDP port 41340. Required for edge pods and multi-server cache topologies."
  type        = bool
  default     = false
}

variable "replication_peers" {
  description = <<-EOT
    Peer Lore servers for Lore's fixed topology ([topology.fixed] in the server config).
    locality is relative to this server: "SameRegion" peers are read + write replicas tuned for
    in-region links; "OtherRegion" peers are push targets for each put over QUIC (BBR), which can
    prefill a tier in another region. A missed push is handled by that tier's durable-store path.
    Rendered into a TOML overlay because Lore cannot take arrays from environment variables.
  EOT
  type = list(object({
    address  = string
    port     = optional(number, 41340)
    locality = string
  }))
  default = []

  validation {
    condition     = alltrue([for p in var.replication_peers : contains(["SameRegion", "OtherRegion"], p.locality)])
    error_message = "replication_peers[*].locality must be \"SameRegion\" or \"OtherRegion\" (Lore's exact variant names)."
  }

  validation {
    condition     = var.enable_replication || length(var.replication_peers) == 0
    error_message = "enable_replication must be true when replication_peers is nonempty so the mTLS identity files are provisioned."
  }
}

variable "enable_same_region_write" {
  description = "Whether SameRegion peers also receive writes (Lore default true). Set false to use a SameRegion peer as a read-only replica, e.g. the other region's tier as a fallback for content that has not replicated yet."
  type        = bool
  default     = true
}

variable "mutable_store_mode" {
  description = "Lore mutable store backend. \"aws\" uses the DynamoDB tables (the write region). \"remote\" forwards branch pointers and tree state to another Lore server (a regional cache whose mutable_store_remote_url points at the write tier)."
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "remote"], var.mutable_store_mode)
    error_message = "mutable_store_mode must be \"aws\" or \"remote\"."
  }
}

variable "mutable_store_remote_url" {
  description = "Lore server URL for the remote mutable store (e.g. lores://write-tier.lore-dev.internal:41337). Required when mutable_store_mode = \"remote\"."
  type        = string
  default     = null

  validation {
    condition     = var.mutable_store_mode != "remote" || var.mutable_store_remote_url != null
    error_message = "mutable_store_remote_url is required when mutable_store_mode = \"remote\"."
  }
}

variable "lock_store_mode" {
  description = "Lore lock store backend: \"aws\" (DynamoDB locks table, the write region), \"local\" (in-process, advisory only), or \"none\"."
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "local", "none"], var.lock_store_mode)
    error_message = "lock_store_mode must be \"aws\", \"local\", or \"none\"."
  }
}

variable "service_discovery_registry_arn" {
  description = "Cloud Map service ARN for ECS service registration. Null when service discovery is disabled."
  type        = string
  default     = null
}

variable "lock_store_region" {
  description = "Region of the DynamoDB locks table when lock_store_mode = \"aws\" and the table lives in another region (a regional tier sharing the write region's locks so that exclusive checkouts are seen by both offices). Null uses the task's own region."
  type        = string
  default     = null
}

variable "trusted_ca_pem" {
  description = "PEM bundle of dedicated Lore CAs for other tiers this server must trust. Any clientAuth certificate chaining to this bundle receives blanket port 41340 storage access, so do not use a shared enterprise CA. Combined with this tier's CA for mTLS and, when needed, with the system store for secure upstream calls."
  type        = string
  default     = null

  validation {
    condition = var.trusted_ca_pem == null ? true : (
      length(regexall("-----BEGIN CERTIFICATE-----", var.trusted_ca_pem)) > 0 &&
      !strcontains(var.trusted_ca_pem, "PRIVATE KEY")
    )
    error_message = "trusted_ca_pem must contain one or more PEM certificates and no private key."
  }
}

variable "replication_peer_refresh_seconds" {
  description = "How often replication peers are re-created and their DNS names re-resolved (Lore rotating_id_fixed topology). Connections to peers are re-established at each interval."
  type        = number
  default     = 300
}

variable "mutable_store_region" {
  description = "Region of the DynamoDB mutable-store table when mutable_store_mode = \"aws\" and the table lives in another region (a regional tier using the write region's branch pointers). Null uses the task's own region."
  type        = string
  default     = null
}

variable "dynamodb_endpoint_url" {
  description = "Optional endpoint-specific HTTPS URL for DynamoDB. Sets Lore's native DynamoDB endpoint URL for mutable-store and lock-store clients."
  type        = string
  default     = null

  validation {
    condition     = var.dynamodb_endpoint_url == null ? true : startswith(var.dynamodb_endpoint_url, "https://")
    error_message = "dynamodb_endpoint_url must be null or an https:// URL."
  }
}

variable "durable_store_mode" {
  description = <<-EOT
    Where the NVMe cache's durable tier lives. "aws": this node's own S3 bucket and DynamoDB
    tables (the write tier). "replicated": another Lore server, reached over QUIC on its
    replication port (a regional cache in another region whose single source of truth is the
    write tier). Reads that miss the cache and every upload go to that server.
  EOT
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "replicated"], var.durable_store_mode)
    error_message = "durable_store_mode must be \"aws\" or \"replicated\"."
  }
}

variable "durable_remote_url" {
  description = "Secure Lore replication URL for durable_store_mode = \"replicated\", e.g. lores://write-tier.lore-dev.internal:41340. The lores scheme is required so the server certificate is validated."
  type        = string
  default     = null

  validation {
    condition     = var.durable_store_mode != "replicated" || (var.durable_remote_url != null && startswith(coalesce(var.durable_remote_url, "-"), "lores://"))
    error_message = "durable_remote_url must be a lores:// URL when durable_store_mode = \"replicated\"."
  }
}

variable "durable_expected_rtt_ms" {
  description = "Round-trip time to the durable_remote_url server, used to size the QUIC congestion window (Lore default 100). Null keeps Lore's default."
  type        = number
  default     = null
}
