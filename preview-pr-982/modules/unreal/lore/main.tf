# =============================================================================
# Availability Zones — dynamic lookup when not explicitly provided
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = var.availability_zones != null ? var.availability_zones : (
    length(data.aws_availability_zones.available.names) >= 2
    ? slice(data.aws_availability_zones.available.names, 0, 2)
    : []
  )
}

# =============================================================================
# VPC — create or use existing (Decision 12)
# =============================================================================

module "vpc" {
  count  = var.vpc_id == null ? 1 : 0
  source = "./modules/vpc"

  vpc_cidr           = var.vpc_cidr
  name_prefix        = local.name_prefix
  availability_zones = local.availability_zones
  tags               = local.tags
  enable_flow_logs   = var.enable_vpc_flow_logs
}

locals {
  vpc_id             = var.vpc_id != null ? var.vpc_id : module.vpc[0].vpc_id
  private_subnet_ids = var.private_subnet_ids != null ? var.private_subnet_ids : module.vpc[0].private_subnet_ids
  public_subnet_ids  = var.public_subnet_ids != null ? var.public_subnet_ids : module.vpc[0].public_subnet_ids
}

# =============================================================================
# Data Layer — S3 + DynamoDB (Phase 1A)
# =============================================================================

module "data" {
  source = "./modules/storage"

  name_prefix                           = local.name_prefix
  tags                                  = local.tags
  enable_force_destroy                  = var.enable_force_destroy
  enable_deletion_protection            = var.enable_deletion_protection
  intelligent_tiering_archive_days      = var.intelligent_tiering_archive_days
  intelligent_tiering_deep_archive_days = var.intelligent_tiering_deep_archive_days
}

# =============================================================================
# Networking — Security Groups + VPC Endpoints
# =============================================================================

resource "aws_security_group" "server" {
  name_prefix = "${local.name_prefix}-server-"
  vpc_id      = local.vpc_id
  description = "Lore server access"

  tags = merge(local.tags, { Name = "${local.name_prefix}-server-sg" })

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "quic" {
  for_each          = toset(var.allowed_ingress_cidrs)
  security_group_id = aws_security_group.server.id
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "udp"
  cidr_ipv4         = each.value
  description       = "QUIC bulk transfer from ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "grpc" {
  for_each          = toset(var.allowed_ingress_cidrs)
  security_group_id = aws_security_group.server.id
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "gRPC RPCs from ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each          = toset(var.allowed_ingress_cidrs)
  security_group_id = aws_security_group.server.id
  from_port         = 41339
  to_port           = 41339
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "HTTP health checks and presigned URLs from ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "replication" {
  security_group_id            = aws_security_group.server.id
  from_port                    = 41340
  to_port                      = 41340
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.server.id
  description                  = "Replication gRPC from peer Lore servers"
}

resource "aws_vpc_security_group_ingress_rule" "replication_quic" {
  security_group_id            = aws_security_group.server.id
  from_port                    = 41340
  to_port                      = 41340
  ip_protocol                  = "udp"
  referenced_security_group_id = aws_security_group.server.id
  description                  = "Replication QUIC from peer Lore servers"
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.server.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "HTTPS to AWS services via NAT"
}

resource "aws_vpc_security_group_egress_rule" "replication_egress" {
  security_group_id            = aws_security_group.server.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.server.id
  description                  = "All traffic to peer Lore servers"
}

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  count             = var.vpc_id == null ? 1 : 0
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.vpc[0].private_route_table_id]

  tags = merge(local.tags, { Name = "${local.name_prefix}-s3-endpoint" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count             = var.vpc_id == null ? 1 : 0
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.vpc[0].private_route_table_id]

  tags = merge(local.tags, { Name = "${local.name_prefix}-dynamodb-endpoint" })
}

# =============================================================================
# Auth — Cognito (conditional on auth_mode == "cognito")
# =============================================================================

module "auth" {
  count  = var.auth_mode == "cognito" ? 1 : 0
  source = "./modules/auth"

  name_prefix = local.name_prefix
  environment = var.environment
  tags        = local.tags
}

# =============================================================================
# Compute — ECS Cluster, ASG, Task Definition, Service, IAM
# =============================================================================

module "compute" {
  source = "./modules/compute"

  name_prefix         = local.name_prefix
  tags                = local.tags
  environment         = var.environment
  fragment_bucket_arn = module.data.fragment_bucket_arn
  dynamodb_table_arns = [
    module.data.fragments_table_arn,
    module.data.fragment_metadata_table_arn,
    module.data.mutable_store_table_arn,
    module.data.locks_table_arn,
  ]
  locks_table_arn              = module.data.locks_table_arn
  private_subnet_ids           = local.private_subnet_ids
  server_security_group_id     = aws_security_group.server.id
  instance_type                = var.instance_type
  container_memory_reservation = var.container_memory_reservation
  cache_max_size_bytes         = var.cache_max_size_bytes
  ami_id                       = var.ami_id
  container_user               = var.container_user
  asg_min_size                 = var.asg_min_size
  asg_max_size                 = var.asg_max_size
  asg_desired_size             = var.asg_desired_size

  # Phase 5B: ECS service
  container_image              = var.container_image
  fragment_bucket_name         = module.data.fragment_bucket_name
  fragments_table_name         = module.data.fragments_table_name
  fragment_metadata_table_name = module.data.fragment_metadata_table_name
  mutable_store_table_name     = module.data.mutable_store_table_name
  locks_table_name             = module.data.locks_table_name

  # Phase 6: Security & Observability
  tls_certificate_secret_arn         = var.tls_certificate_secret_arn
  tls_private_key_secret_arn         = var.tls_private_key_secret_arn
  tls_san_dns_names                  = var.tls_san_dns_names
  hmac_key_secret_arn                = var.hmac_key_secret_arn
  write_tier_dns_name                = "write-tier.${local.name_prefix}.internal"
  enable_otel_sidecar                = var.enable_otel_sidecar
  otel_collector_image               = var.otel_collector_image
  auth_mode                          = var.auth_mode
  auth_jwk_endpoint                  = var.auth_mode == "cognito" ? module.auth[0].jwk_endpoint : var.auth_jwk_endpoint
  auth_jwt_issuer                    = var.auth_mode == "cognito" ? module.auth[0].issuer : var.auth_jwt_issuer
  auth_jwt_audience                  = var.auth_jwt_audience
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  log_retention_days                 = var.log_retention_days
  enable_xray_smoke_test             = var.enable_xray_smoke_test
  enable_replication                 = true
  service_discovery_registry_arn     = aws_service_discovery_service.write_tier.arn
}

# =============================================================================
# Service Discovery — Cloud Map (edge pod → write tier DNS)
# =============================================================================

resource "aws_service_discovery_private_dns_namespace" "lore" {
  name        = "${local.name_prefix}.internal"
  description = "Lore write tier service discovery for edge pods"
  vpc         = local.vpc_id
  tags        = local.tags
}

resource "aws_service_discovery_service" "write_tier" {
  name = "write-tier"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.lore.id

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


