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
  description = "Docker image URI for the Lore server (must match instance architecture)"
  type        = string
  nullable    = false
}

variable "write_tier_dns" {
  description = "DNS name of the write tier (Cloud Map). Used for both gRPC branch resolution (:41337) and QUIC replication (:41340)."
  type        = string
  nullable    = false
}

variable "ca_certificate_pem" {
  description = "PEM-encoded CA certificate of the write tier (for TLS verification)"
  type        = string
  nullable    = false
  sensitive   = true
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
  description = "64-char hex HMAC key for presigned URLs. Generated if null."
  type        = string
  default     = null
  sensitive   = true
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the edge pod (QUIC:41337, gRPC:41337, HTTP:41339)"
  type        = list(string)
  default     = []
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
