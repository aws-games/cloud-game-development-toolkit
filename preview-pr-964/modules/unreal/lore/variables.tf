# =============================================================================
# Identity
# =============================================================================

variable "project_prefix" {
  description = "Prefix for all resource names (e.g., 'lore', 'mystudio-lore'). Max 12 chars to fit AWS resource name limits."
  type        = string
  default     = "lore"
  nullable    = false

  validation {
    condition     = length(var.project_prefix) >= 2 && length(var.project_prefix) <= 12
    error_message = "project_prefix must be 2-12 characters (prefix + env + resource must fit AWS name limits)."
  }
}

variable "environment" {
  description = "Environment name — controls resource sizing defaults via locals.tf ternary chains. Only dev/staging/prod are supported because environment-aware defaults depend on these exact values."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod (module defaults depend on these values)."
  }
}

# =============================================================================
# VPC (Decision 12, 14)
# =============================================================================

variable "vpc_id" {
  description = "Existing VPC ID. If null, a new VPC is created."
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "Existing private subnet IDs. Required when vpc_id is set."
  type        = list(string)
  default     = null
}

variable "public_subnet_ids" {
  description = "Existing public subnet IDs. Required when vpc_id is set."
  type        = list(string)
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (only used when vpc_id is null)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones (only used when vpc_id is null). If null, uses first 2 AZs in the current region."
  type        = list(string)
  default     = null
}

# =============================================================================
# Networking
# =============================================================================

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to access Lore server ports. No default — must be explicitly provided."
  type        = list(string)
}

# =============================================================================
# Compute (Decisions 3, 4, 7)
# =============================================================================

variable "container_image" {
  description = "Loreserver container image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/loreserver:latest)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for ECS capacity provider"
  type        = string
  default     = "i4i.xlarge"
}

variable "container_memory_reservation" {
  description = "Soft memory reservation (MiB) for the loreserver container. If null, auto-sizes based on instance_type."
  type        = number
  default     = null
}

variable "cache_max_size_bytes" {
  description = "NVMe cache maximum size in bytes. 0 = auto-size to 80% of instance store capacity based on instance_type."
  type        = number
  default     = 0
}

variable "ami_id" {
  description = "AMI ID override. If null, uses latest ECS-optimized AL2023. Pin in production for stability."
  type        = string
  default     = null
}

variable "container_user" {
  description = "User/group for the container process (e.g., '65534', '1000:1000'). Default 65534 (nobody) for non-root."
  type        = string
  default     = "65534"
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

variable "require_instance_store" {
  description = "Validate that instance_type has NVMe instance store. Set false for dev/test on cheaper instances."
  type        = bool
  default     = true
  nullable    = false
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower limit on running tasks during deployment (% of desired_count). Default 66 allows single-task services to deploy without ENI deadlock on small instances."
  type        = number
  default     = 66
  nullable    = false
}

variable "deployment_maximum_percent" {
  description = "Upper limit on running tasks during deployment (% of desired_count)."
  type        = number
  default     = 200
  nullable    = false
}

# =============================================================================
# Authentication (Decision 10, ADR-0003)
# =============================================================================

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
    error_message = "Set auth_jwk_endpoint when using auth_mode = 'external'."
  }
}

variable "auth_jwt_issuer" {
  description = "JWT issuer string (required when auth_mode = 'external')"
  type        = string
  default     = null

  validation {
    condition     = var.auth_mode != "external" || var.auth_jwt_issuer != null
    error_message = "Set auth_jwt_issuer when using auth_mode = 'external'."
  }
}

variable "auth_jwt_audience" {
  description = "JWT audience values the server accepts"
  type        = list(string)
  default     = []
}

# =============================================================================
# TLS (Decision 11)
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
  description = "Additional DNS SANs for the self-signed TLS certificate"
  type        = list(string)
  default     = []
}

variable "hmac_key_secret_arn" {
  description = "Secrets Manager ARN for HMAC signing key. If null, a random key is generated."
  type        = string
  default     = null
}

# =============================================================================
# Observability (Decision 9)
# =============================================================================

variable "enable_otel_sidecar" {
  description = "Deploy ADOT sidecar for OpenTelemetry collection (CloudWatch + X-Ray)"
  type        = bool
  default     = true
  nullable    = false
}

variable "otel_collector_image" {
  description = "ADOT collector image URI. Override to use a private ECR mirror. Pin to a specific tag in production."
  type        = string
  default     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
}

variable "enable_xray_smoke_test" {
  description = "Deploy X-Ray pipeline smoke test Lambda (validates trace delivery + IAM permissions)"
  type        = bool
  default     = true
  nullable    = false
}

# =============================================================================
# Storage
# =============================================================================

variable "intelligent_tiering_archive_days" {
  description = "Days before fragments move to Archive Access tier. 0 disables Intelligent-Tiering entirely."
  type        = number
  default     = 90

  validation {
    condition     = var.intelligent_tiering_archive_days >= 0
    error_message = "intelligent_tiering_archive_days must be >= 0."
  }
}

variable "intelligent_tiering_deep_archive_days" {
  description = "Days before fragments move to Deep Archive Access tier. Must be > archive_days when both are enabled."
  type        = number
  default     = 180

  validation {
    condition     = var.intelligent_tiering_deep_archive_days >= 0
    error_message = "intelligent_tiering_deep_archive_days must be >= 0."
  }

  validation {
    condition     = var.intelligent_tiering_deep_archive_days == 0 || var.intelligent_tiering_archive_days == 0 || var.intelligent_tiering_deep_archive_days > var.intelligent_tiering_archive_days
    error_message = "intelligent_tiering_deep_archive_days must be greater than intelligent_tiering_archive_days when both are enabled."
  }
}

# =============================================================================
# Safety
# =============================================================================

variable "enable_force_destroy" {
  description = "Allow S3 buckets to be destroyed even when non-empty. Use only in test environments."
  type        = bool
  default     = false
  nullable    = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on DynamoDB tables. Disable for test environments."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch. Adds IAM role and log group."
  type        = bool
  default     = false
  nullable    = false
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days."
  type        = number
  default     = 30
  nullable    = false
}
