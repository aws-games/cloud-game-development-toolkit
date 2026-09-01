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
  description = "ARN of the S3 fragment bucket"
  type        = string
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
  description = "Secrets Manager ARN for server TLS certificate. If null, a self-signed cert is generated."
  type        = string
  default     = null
}

variable "tls_private_key_secret_arn" {
  description = "Secrets Manager ARN for server TLS private key. If null, generated with self-signed cert."
  type        = string
  default     = null
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
  description = "Enable the QUIC internal replication endpoint (port 41340). Required for multi-server cache topologies."
  type        = bool
  default     = false
}

variable "replication_peers" {
  description = "List of peer addresses for fixed topology replication. Each entry is a host:port string (e.g., '10.0.1.50:41340')."
  type        = list(string)
  default     = []
}

variable "service_discovery_registry_arn" {
  description = "Cloud Map service ARN for ECS service registration. Null when service discovery is disabled."
  type        = string
  default     = null
}
