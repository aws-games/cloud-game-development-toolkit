# =============================================================================
# Regional tier — a Lore server fleet in a second region.
#
# Fragments are durable here (own S3 bucket + own immutable DynamoDB tables) so this office
# reads and uploads at local speed. Branch pointers are not: the mutable store is forwarded to the
# write tier, and locks use the write region's DynamoDB table, because Lore's branch advance is a
# compare-and-swap that only one region may own. See the root README, "Multi-region".
#
# Pass `providers = { aws = aws.<region> }` when calling this module.
# =============================================================================

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394: Dynamic lookup is the default; pin with var.availability_zones
  state = "available"
}

locals {
  availability_zones = var.availability_zones != null ? var.availability_zones : (
    length(data.aws_availability_zones.available.names) >= 2
    ? slice(data.aws_availability_zones.available.names, 0, 2)
    : []
  )
  tags          = merge(var.tags, { ManagedBy = "terraform", LoreRole = "regional-tier" })
  tier_dns_name = "regional-tier.${var.name_prefix}.internal"
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
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.vpc.private_route_table_id]

  tags = merge(local.tags, { Name = "${var.name_prefix}-s3-endpoint" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.vpc.private_route_table_id]

  tags = merge(local.tags, { Name = "${var.name_prefix}-dynamodb-endpoint" })
}

# =============================================================================
# Storage — fragments bucket + immutable tables only. No mutable store, no locks.
# =============================================================================

module "data" {
  source = "../storage"

  name_prefix                           = var.name_prefix
  tags                                  = local.tags
  enable_force_destroy                  = var.enable_force_destroy
  enable_deletion_protection            = var.enable_deletion_protection
  intelligent_tiering_archive_days      = var.intelligent_tiering_archive_days
  intelligent_tiering_deep_archive_days = var.intelligent_tiering_deep_archive_days

  create_immutable_tables = var.immutable_tables.mode == "create"
  create_mutable_tables   = false

  enable_replication                 = var.enable_replication
  replication_destination_bucket_arn = var.replication_destination_bucket_arn
  replication_time_control           = var.replication_time_control
}

data "aws_dynamodb_table" "fragments_replica" {
  count = var.immutable_tables.mode == "global_table" ? 1 : 0
  name  = var.immutable_tables.fragments_table_name
}

data "aws_dynamodb_table" "fragment_metadata_replica" {
  count = var.immutable_tables.mode == "global_table" ? 1 : 0
  name  = var.immutable_tables.fragment_metadata_table_name
}

locals {
  fragments_table_name         = var.immutable_tables.mode == "create" ? module.data.fragments_table_name : data.aws_dynamodb_table.fragments_replica[0].name
  fragments_table_arn          = var.immutable_tables.mode == "create" ? module.data.fragments_table_arn : data.aws_dynamodb_table.fragments_replica[0].arn
  fragment_metadata_table_name = var.immutable_tables.mode == "create" ? module.data.fragment_metadata_table_name : data.aws_dynamodb_table.fragment_metadata_replica[0].name
  fragment_metadata_table_arn  = var.immutable_tables.mode == "create" ? module.data.fragment_metadata_table_arn : data.aws_dynamodb_table.fragment_metadata_replica[0].arn
}

# =============================================================================
# Security group
# =============================================================================

resource "aws_security_group" "tier" {
  #checkov:skip=CKV2_AWS_5: Attached by the ECS service in modules/compute (network_configuration)
  name_prefix = "${var.name_prefix}-tier-"
  vpc_id      = module.vpc.vpc_id
  description = "Lore regional tier access"

  tags = merge(local.tags, { Name = "${var.name_prefix}-tier-sg" })

  lifecycle { create_before_destroy = true }
}

# Office clients
resource "aws_vpc_security_group_ingress_rule" "client_tcp" {
  for_each          = toset(var.allowed_ingress_cidrs)
  security_group_id = aws_security_group.tier.id
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "gRPC from ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "client_udp" {
  for_each          = toset(var.allowed_ingress_cidrs)
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

resource "aws_vpc_security_group_ingress_rule" "write_region_replication_tcp" {
  security_group_id = aws_security_group.tier.id
  from_port         = 41340
  to_port           = 41340
  ip_protocol       = "tcp"
  cidr_ipv4         = var.write_region_vpc_cidr
  description       = "Replication from the write region"
}

resource "aws_vpc_security_group_ingress_rule" "write_region_replication_udp" {
  security_group_id = aws_security_group.tier.id
  from_port         = 41340
  to_port           = 41340
  ip_protocol       = "udp"
  cidr_ipv4         = var.write_region_vpc_cidr
  description       = "Replication QUIC from the write region"
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
  description       = "HTTPS to AWS services (incl. the write region's DynamoDB) via NAT"
}

resource "aws_vpc_security_group_egress_rule" "write_region_grpc" {
  security_group_id = aws_security_group.tier.id
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "tcp"
  cidr_ipv4         = var.write_region_vpc_cidr
  description       = "Mutable store forwarding to the write tier"
}

resource "aws_vpc_security_group_egress_rule" "write_region_replication_tcp" {
  security_group_id = aws_security_group.tier.id
  from_port         = 41340
  to_port           = 41340
  ip_protocol       = "tcp"
  cidr_ipv4         = var.write_region_vpc_cidr
  description       = "Replication to the write tier"
}

resource "aws_vpc_security_group_egress_rule" "write_region_replication_udp" {
  security_group_id = aws_security_group.tier.id
  from_port         = 41340
  to_port           = 41340
  ip_protocol       = "udp"
  cidr_ipv4         = var.write_region_vpc_cidr
  description       = "Replication QUIC to the write tier"
}

resource "aws_vpc_security_group_egress_rule" "peers" {
  security_group_id            = aws_security_group.tier.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.tier.id
  description                  = "All traffic to peer tasks"
}

# =============================================================================
# Service discovery — so the write tier can address this tier by name
# =============================================================================

resource "aws_service_discovery_private_dns_namespace" "tier" {
  name        = "${var.name_prefix}.internal"
  description = "Lore regional tier service discovery"
  vpc         = module.vpc.vpc_id
  tags        = local.tags
}

resource "aws_service_discovery_service" "tier" {
  name = "regional-tier"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.tier.id

    dns_records {
      type = "A"
      ttl  = 10
    }

    routing_policy = "MULTIVALUE"
  }

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

  name_prefix         = var.name_prefix
  tags                = local.tags
  environment         = var.environment
  fragment_bucket_arn = module.data.fragment_bucket_arn
  dynamodb_table_arns = [
    local.fragments_table_arn,
    local.fragment_metadata_table_arn,
    var.locks_table_arn,
  ]
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
  fragment_bucket_name         = module.data.fragment_bucket_name
  fragments_table_name         = local.fragments_table_name
  fragment_metadata_table_name = local.fragment_metadata_table_name
  mutable_store_table_name     = "unused-mutable-store-is-remote"
  locks_table_name             = var.locks_table_name

  # The two things that make this a regional tier rather than a second write tier
  mutable_store_mode       = "remote"
  mutable_store_remote_url = "lores://${var.write_tier_dns_name}:41337"
  lock_store_mode          = "aws"
  lock_store_region        = var.write_region
  trusted_ca_pem           = var.write_tier_ca_certificate_pem

  enable_replication       = true
  replication_peers        = var.replication_peers
  enable_same_region_write = var.enable_same_region_write

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
