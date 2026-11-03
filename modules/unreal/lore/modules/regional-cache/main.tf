# =============================================================================
# Regional cache — a Lore server in a second region with an NVMe cache and no storage of its own.
#
# The write region stays the single source of truth: its S3 bucket and DynamoDB tables are the
# only copies. This node's cache sits over the write tier (durable mode "replicated"). The
# write tier attempts to push each stored fragment into this cache (topology peer, OtherRegion);
# a missed fragment loads from the write tier on the first cache miss. Branch pointers and locks
# are the write region's DynamoDB tables, used cross-region. See the root README, "Multi-region".
#
# Pass `providers = { aws = aws.<region> }` when calling this module.
# =============================================================================

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394: Dynamic lookup is the default; pin with var.availability_zones
  state = "available"
}

locals {
  # The write region's CIDR gets its own rules below; drop it from the client list to avoid duplicates.
  client_cidrs = setsubtract(toset(var.allowed_ingress_cidrs), toset([var.write_region_vpc_cidr]))
  # 41340 has no JWT or client-certificate check: these CIDRs are its only access control.
  write_tier_replication_cidrs = sort(distinct(coalesce(var.write_tier_replication_cidrs, [var.write_region_vpc_cidr])))
  availability_zones = var.availability_zones != null ? var.availability_zones : (
    length(data.aws_availability_zones.available.names) >= 2
    ? slice(data.aws_availability_zones.available.names, 0, 2)
    : []
  )
  tags          = merge(var.tags, { ManagedBy = "terraform", LoreRole = "regional-cache" })
  tier_dns_name = "regional-cache.${var.name_prefix}.internal"
}

# Preserve the first 41340 rule when upgrading from the former single-CIDR resources.
# Extra private-subnet CIDRs create only additional indexed rules.
moved {
  from = aws_vpc_security_group_ingress_rule.write_region_replication_tcp
  to   = aws_vpc_security_group_ingress_rule.write_region_replication_tcp[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.write_region_replication_udp
  to   = aws_vpc_security_group_ingress_rule.write_region_replication_udp[0]
}

moved {
  from = aws_vpc_security_group_egress_rule.write_region_replication_tcp
  to   = aws_vpc_security_group_egress_rule.write_region_replication_tcp[0]
}

moved {
  from = aws_vpc_security_group_egress_rule.write_region_replication_udp
  to   = aws_vpc_security_group_egress_rule.write_region_replication_udp[0]
}

# =============================================================================
# VPC
# =============================================================================

module "vpc" {
  source = "../vpc"

  vpc_cidr           = var.vpc_cidr
  name_prefix        = var.name_prefix
  availability_zones = local.availability_zones
  tags               = local.tags
  enable_flow_logs   = var.enable_vpc_flow_logs
  peering_routes     = var.vpc_peering_routes
}

# S3 gateway endpoint: ECR image layers are served from S3 in this region.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.vpc.private_route_table_id]

  tags = merge(local.tags, { Name = "${var.name_prefix}-s3-endpoint" })
}

# =============================================================================
# Security group
# =============================================================================

resource "aws_security_group" "tier" {
  #checkov:skip=CKV2_AWS_5: Attached by the ECS service in modules/compute (network_configuration)
  name_prefix = "${var.name_prefix}-tier-"
  vpc_id      = module.vpc.vpc_id
  description = "Lore regional cache access"

  tags = merge(local.tags, { Name = "${var.name_prefix}-tier-sg" })

  lifecycle { create_before_destroy = true }
}

# Office clients
resource "aws_vpc_security_group_ingress_rule" "client_tcp" {
  for_each          = local.client_cidrs
  security_group_id = aws_security_group.tier.id
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "gRPC from ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "client_udp" {
  for_each          = local.client_cidrs
  security_group_id = aws_security_group.tier.id
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "udp"
  cidr_ipv4         = each.value
  description       = "QUIC from ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "client_http" {
  for_each          = toset(var.allowed_ingress_cidrs)
  security_group_id = aws_security_group.tier.id
  from_port         = 41339
  to_port           = 41339
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "HTTP health checks and presigned URLs from ${each.value}"
}

# The write tier, across inter-region peering (security-group references do not cross regions)
resource "aws_vpc_security_group_ingress_rule" "write_region_grpc" {
  security_group_id = aws_security_group.tier.id
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "tcp"
  cidr_ipv4         = var.write_region_vpc_cidr
  description       = "gRPC from the write region"
}

resource "aws_vpc_security_group_ingress_rule" "write_region_quic" {
  security_group_id = aws_security_group.tier.id
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "udp"
  cidr_ipv4         = var.write_region_vpc_cidr
  description       = "QUIC from the write region"
}

resource "aws_vpc_security_group_ingress_rule" "write_region_replication_tcp" {
  count             = length(local.write_tier_replication_cidrs)
  security_group_id = aws_security_group.tier.id
  from_port         = 41340
  to_port           = 41340
  ip_protocol       = "tcp"
  cidr_ipv4         = local.write_tier_replication_cidrs[count.index]
  description       = "Replication from the write region (${local.write_tier_replication_cidrs[count.index]})"
}

resource "aws_vpc_security_group_ingress_rule" "write_region_replication_udp" {
  count             = length(local.write_tier_replication_cidrs)
  security_group_id = aws_security_group.tier.id
  from_port         = 41340
  to_port           = 41340
  ip_protocol       = "udp"
  cidr_ipv4         = local.write_tier_replication_cidrs[count.index]
  description       = "Replication QUIC from the write region (${local.write_tier_replication_cidrs[count.index]})"
}

# Same-region peers (several tasks in this tier)
resource "aws_vpc_security_group_ingress_rule" "peer_replication" {
  security_group_id            = aws_security_group.tier.id
  from_port                    = 41340
  to_port                      = 41340
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.tier.id
  description                  = "Replication gRPC from peer tasks"
}

resource "aws_vpc_security_group_ingress_rule" "peer_replication_udp" {
  security_group_id            = aws_security_group.tier.id
  from_port                    = 41340
  to_port                      = 41340
  ip_protocol                  = "udp"
  referenced_security_group_id = aws_security_group.tier.id
  description                  = "Replication QUIC from peer tasks"
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.tier.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "HTTPS to AWS services including the write region DynamoDB via NAT"
}

resource "aws_vpc_security_group_egress_rule" "write_region_grpc" {
  security_group_id = aws_security_group.tier.id
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "tcp"
  cidr_ipv4         = var.write_region_vpc_cidr
  description       = "Mutable store forwarding to the write tier"
}

resource "aws_vpc_security_group_egress_rule" "write_region_quic" {
  security_group_id = aws_security_group.tier.id
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "udp"
  cidr_ipv4         = var.write_region_vpc_cidr
  description       = "Remote mutable store over QUIC (lores://) to the write tier"
}

resource "aws_vpc_security_group_egress_rule" "write_region_replication_tcp" {
  count             = length(local.write_tier_replication_cidrs)
  security_group_id = aws_security_group.tier.id
  from_port         = 41340
  to_port           = 41340
  ip_protocol       = "tcp"
  cidr_ipv4         = local.write_tier_replication_cidrs[count.index]
  description       = "Replication to the write tier (${local.write_tier_replication_cidrs[count.index]})"
}

resource "aws_vpc_security_group_egress_rule" "write_region_replication_udp" {
  count             = length(local.write_tier_replication_cidrs)
  security_group_id = aws_security_group.tier.id
  from_port         = 41340
  to_port           = 41340
  ip_protocol       = "udp"
  cidr_ipv4         = local.write_tier_replication_cidrs[count.index]
  description       = "Replication QUIC to the write tier (${local.write_tier_replication_cidrs[count.index]})"
}

resource "aws_vpc_security_group_egress_rule" "peers" {
  security_group_id            = aws_security_group.tier.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.tier.id
  description                  = "All traffic to peer tasks"
}

# =============================================================================
# Service discovery — so the write tier can push to this cache by name
# =============================================================================

resource "aws_service_discovery_private_dns_namespace" "tier" {
  name        = "${var.name_prefix}.internal"
  description = "Lore regional cache service discovery"
  vpc         = module.vpc.vpc_id
  tags        = local.tags
}

resource "aws_service_discovery_service" "tier" {
  name = "regional-cache"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.tier.id

    dns_records {
      type = "A"
      ttl  = 10
    }

    routing_policy = "MULTIVALUE"
  }

  # Kept deliberately despite the AWS provider v6 deprecation warning. Existing services were
  # created with 1 (the only value AWS uses). health_check_custom_config forces replacement, and
  # a replaced service deregisters every task and breaks name resolution, so do not remove it.
  health_check_custom_config {
    failure_threshold = 1
  }

  tags = local.tags
}

# =============================================================================
# Compute — same submodule as the write tier, different store wiring
# =============================================================================

module "compute" {
  source = "../compute"

  name_prefix = var.name_prefix
  tags        = local.tags
  environment = var.environment
  # No bucket and no immutable tables here: only the write region's branch-pointer and lock
  # tables, used cross-region.
  dynamodb_table_arns          = [var.mutable_store_table_arn, var.locks_table_arn]
  locks_table_arn              = var.locks_table_arn
  private_subnet_ids           = module.vpc.private_subnet_ids
  server_security_group_id     = aws_security_group.tier.id
  instance_type                = var.instance_type
  container_memory_reservation = var.container_memory_reservation
  cache_max_size_bytes         = var.cache_max_size_bytes
  ami_id                       = var.ami_id
  container_user               = var.container_user
  asg_min_size                 = var.asg_min_size
  asg_max_size                 = var.asg_max_size
  asg_desired_size             = var.asg_desired_size

  container_image              = var.container_image
  fragment_bucket_name         = null
  fragments_table_name         = null
  fragment_metadata_table_name = null
  mutable_store_table_name     = var.mutable_store_table_name
  locks_table_name             = var.locks_table_name

  # The cache's durable tier is the write tier. Uploads and cache misses go there. The write tier
  # attempts to push each stored fragment back into this cache because it lists this node as a peer.
  # A missed push loads through durable_remote_url on the first cache miss.
  durable_store_mode      = "replicated"
  durable_remote_url      = "lore://${var.write_tier_dns_name}:41340"
  durable_expected_rtt_ms = var.write_region_rtt_ms

  # Branch pointers: the write region's DynamoDB table used directly (default), or forwarded to
  # the write tier. Locks: the write region's DynamoDB table (Lore has no remote lock store).
  mutable_store_mode       = var.branch_pointer_access == "write_tier" ? "remote" : "aws"
  mutable_store_remote_url = "lores://${var.write_tier_dns_name}:41337"
  mutable_store_region     = var.write_region
  lock_store_mode          = "aws"
  lock_store_region        = var.write_region
  trusted_ca_pem           = var.write_tier_ca_certificate_pem

  # quic_internal on, so the write tier can push fragments into this cache
  enable_replication = true

  tls_certificate_secret_arn         = var.tls_certificate_secret_arn
  tls_private_key_secret_arn         = var.tls_private_key_secret_arn
  tls_san_dns_names                  = var.tls_san_dns_names
  hmac_key_secret_arn                = var.hmac_key_secret_arn
  write_tier_dns_name                = local.tier_dns_name
  enable_otel_sidecar                = var.enable_otel_sidecar
  otel_collector_image               = var.otel_collector_image
  auth_mode                          = var.auth_mode
  auth_jwk_endpoint                  = var.auth_jwk_endpoint
  auth_jwt_issuer                    = var.auth_jwt_issuer
  auth_jwt_audience                  = var.auth_jwt_audience
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  log_retention_days                 = var.log_retention_days
  enable_xray_smoke_test             = var.enable_xray_smoke_test
  service_discovery_registry_arn     = aws_service_discovery_service.tier.arn
}
