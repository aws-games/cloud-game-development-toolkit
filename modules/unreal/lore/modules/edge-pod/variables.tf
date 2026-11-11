# =============================================================================
# Required
# =============================================================================

variable "vpc_id" {
  description = "VPC ID where the edge pod will be deployed"
  type        = string
  nullable    = false
}

variable "subnet_id" {
  description = "Subnet ID for the edge pod instance"
  type        = string
  nullable    = false
}

variable "server_security_group_id" {
  description = "Security group of the Lore tier this pod forwards to, when it is in the same VPC: the pod is granted ingress to it. Null when the tier is reached across inter-region peering; allow the pod's CIDR on the tier instead (root module replication_ingress_cidrs)."
  type        = string
  default     = null
}

variable "container_image" {
  description = "ECR image URI for the Lore server. The strict format keeps userdata shell interpolation non-executable."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}\\.dkr\\.ecr(-fips)?\\.[a-z0-9-]+\\.amazonaws\\.com(\\.cn)?/[A-Za-z0-9._/-]+(:[A-Za-z0-9._-]+|@sha256:[a-f0-9]{64})$", var.container_image))
    error_message = "container_image must be a complete Amazon ECR image URI with a tag or sha256 digest."
  }
}

variable "write_tier_dns" {
  description = "DNS name of the write tier (Cloud Map). Used for both gRPC branch resolution (:41337) and mTLS QUIC replication (:41340)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$", var.write_tier_dns))
    error_message = "write_tier_dns must be a DNS name without a scheme, port, path, or shell metacharacters."
  }
}

variable "ca_certificate_pem" {
  description = "PEM-encoded CA certificate bundle for validating the write tier and completing the mTLS client chain"
  type        = string
  nullable    = false
  sensitive   = true

  validation {
    condition = (
      length(regexall("-----BEGIN CERTIFICATE-----", var.ca_certificate_pem)) > 0 &&
      !strcontains(var.ca_certificate_pem, "PRIVATE KEY")
    )
    error_message = "ca_certificate_pem must contain one or more PEM certificates and no private key."
  }
}

variable "replication_client_certificate_secret_arn" {
  description = "Optional Secrets Manager ARN for this edge pod's clientAuth certificate chain. Set with the matching key ARN and dedicated CA PEM; null generates an edge-specific identity."
  type        = string
  default     = null

  validation {
    condition = var.replication_client_certificate_secret_arn == null ? true : can(regex(
      "^arn:(aws|aws-us-gov|aws-cn):secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:[A-Za-z0-9/_+=.@-]+$",
      var.replication_client_certificate_secret_arn
    ))
    error_message = "replication_client_certificate_secret_arn must be null or a Secrets Manager secret ARN."
  }

  validation {
    condition = (
      var.replication_client_certificate_secret_arn == null &&
      var.replication_client_private_key_secret_arn == null &&
      var.replication_client_ca_certificate_pem == null
      ) || (
      var.replication_client_certificate_secret_arn != null &&
      var.replication_client_private_key_secret_arn != null &&
      var.replication_client_ca_certificate_pem != null
    )
    error_message = "Set the replication client certificate ARN, key ARN, and dedicated CA PEM together, or leave all three null for a generated edge identity."
  }
}

variable "replication_client_private_key_secret_arn" {
  description = "Optional Secrets Manager ARN for this edge pod's mTLS client private key."
  type        = string
  default     = null

  validation {
    condition = var.replication_client_private_key_secret_arn == null ? true : can(regex(
      "^arn:(aws|aws-us-gov|aws-cn):secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:[A-Za-z0-9/_+=.@-]+$",
      var.replication_client_private_key_secret_arn
    ))
    error_message = "replication_client_private_key_secret_arn must be null or a Secrets Manager secret ARN."
  }
}

variable "replication_client_ca_certificate_pem" {
  description = "Optional dedicated CA PEM that issued the custom replication-client certificate. Give the effective output to the write tier as trusted_ca_pem. Do not use a shared enterprise CA."
  type        = string
  default     = null

  validation {
    condition = var.replication_client_ca_certificate_pem == null ? true : (
      length(regexall("-----BEGIN CERTIFICATE-----", var.replication_client_ca_certificate_pem)) > 0 &&
      !strcontains(var.replication_client_ca_certificate_pem, "PRIVATE KEY")
    )
    error_message = "replication_client_ca_certificate_pem must be null or contain one or more PEM certificates and no private key."
  }
}

variable "replication_client_material_version" {
  description = "Rollout token for custom replication identity secrets. Change it whenever certificate, key, or CA contents rotate under unchanged inputs so the edge instance is replaced. Generated identities derive this automatically."
  type        = string
  default     = "1"
  nullable    = false

  validation {
    condition     = trimspace(var.replication_client_material_version) != ""
    error_message = "replication_client_material_version must not be empty."
  }
}

# =============================================================================
# Optional
# =============================================================================

variable "instance_type" {
  description = "EC2 instance type. c8gd.8xlarge minimum for full bandwidth (32 vCPU exempts internet egress cap)."
  type        = string
  default     = "c8gd.8xlarge"
  nullable    = false
}

variable "name_prefix" {
  description = "Name prefix for all resources created by this module"
  type        = string
  default     = "edge"
  nullable    = false
}

variable "hmac_key" {
  description = "64-character hexadecimal HMAC key for presigned URLs. Generated if null."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.hmac_key == null ? true : can(regex("^[0-9A-Fa-f]{64}$", var.hmac_key))
    error_message = "hmac_key must be null or exactly 64 hexadecimal characters."
  }
}

variable "allowed_ingress_cidrs" {
  description = "Specific CIDRs allowed to reach the edge pod (QUIC:41337, gRPC:41337, HTTP:41339). Public catch-all ranges are rejected."
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      length(var.allowed_ingress_cidrs) > 0 &&
      alltrue([for cidr in var.allowed_ingress_cidrs : can(cidrhost(cidr, 0))]) &&
      !contains(var.allowed_ingress_cidrs, "0.0.0.0/0") &&
      !contains(var.allowed_ingress_cidrs, "::/0")
    )
    error_message = "allowed_ingress_cidrs must contain specific valid CIDRs and must not include 0.0.0.0/0 or ::/0."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "replication_expected_rtt_ms" {
  description = "Expected round-trip time to the tier in milliseconds, used to size the QUIC congestion window (Lore default 100). Set to the measured RTT for a pod in another region; leave null in-region."
  type        = number
  default     = null
}

variable "replication_max_bandwidth_bytes_per_second" {
  description = "Cap on the pod-to-tier replication link in bytes per second. Null leaves Lore's default."
  type        = number
  default     = null
}
