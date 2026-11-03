# =============================================================================
# Two offices, one repository.
#
# The write region runs the normal Lore module and is the single source of truth: one S3
# bucket, one set of DynamoDB tables. The other region runs a regional cache: a Lore server with
# an NVMe cache and no storage of its own. The write tier attempts to push each stored fragment
# into that cache. A missed push loads from the write tier on the first cache miss. The second
# office's uploads and cache misses go to the write tier. See ../../README.md, "Multi-region".
# =============================================================================

provider "aws" {
  region = var.write_region
}

provider "aws" {
  alias  = "replica"
  region = var.replica_region
}

locals {
  write_vpc_cidr   = "10.10.0.0/16"
  replica_vpc_cidr = "10.20.0.0/16"
}

# =============================================================================
# Write region — the Lore module as usual, plus what the other region needs
# =============================================================================

module "lore" {
  source = "../../"

  project_prefix        = "lore"
  environment           = "dev"
  container_image       = var.container_image
  allowed_ingress_cidrs = var.write_office_cidrs
  vpc_cidr              = local.write_vpc_cidr
  instance_type         = "c8gd.large"

  enable_deletion_protection = false
  enable_force_destroy       = true
  asg_desired_size           = 1
  auth_mode                  = "external"
  auth_jwk_endpoint          = var.auth_jwk_endpoint
  auth_jwt_issuer            = var.auth_jwt_issuer
  auth_jwt_audience          = var.auth_jwt_audience

  # Let the regional cache's private subnets reach the write tier, and the write tier push to
  # them (security-group references do not cross inter-region peering, so this is by CIDR).
  # Port 41340 has no JWT or client-certificate check: these CIDRs are its only protection.
  replication_ingress_cidrs = module.regional_cache.private_subnet_cidrs
  vpc_peering_routes = [{
    cidr_block                = local.replica_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.regions.id
  }]

  # Attempt to prefill the other office's cache after storing each fragment.
  replication_peers = [{
    address  = module.regional_cache.cache_dns_name
    locality = "OtherRegion"
  }]
  trusted_ca_pem = module.regional_cache.ca_certificate_pem
}

# =============================================================================
# Replica region — regional cache
# =============================================================================

module "regional_cache" {
  source = "../../modules/regional-cache"
  providers = {
    aws = aws.replica
  }

  name_prefix           = "lore-dev-replica"
  environment           = "dev"
  container_image       = var.replica_container_image
  allowed_ingress_cidrs = var.replica_office_cidrs
  vpc_cidr              = local.replica_vpc_cidr
  instance_type         = "c8gd.large"
  asg_desired_size      = 1
  auth_mode             = "external"
  auth_jwk_endpoint     = var.auth_jwk_endpoint
  auth_jwt_issuer       = var.auth_jwt_issuer
  auth_jwt_audience     = var.auth_jwt_audience

  # The write region it belongs to
  write_region                  = var.write_region
  write_region_vpc_cidr         = local.write_vpc_cidr
  write_tier_replication_cidrs  = module.lore.private_subnet_cidrs
  write_tier_dns_name           = module.lore.write_tier_dns_name
  write_tier_ca_certificate_pem = module.lore.ca_certificate_pem
  mutable_store_table_name      = module.lore.mutable_store_table_name
  mutable_store_table_arn       = module.lore.mutable_store_table_arn
  locks_table_name              = module.lore.locks_table_name
  locks_table_arn               = module.lore.locks_table_arn
  vpc_peering_routes = [{
    cidr_block                = local.write_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection_accepter.regions.id
  }]
}

# =============================================================================
# Inter-region VPC peering
# =============================================================================

resource "aws_vpc_peering_connection" "regions" {
  vpc_id      = module.lore.vpc_id
  peer_vpc_id = module.regional_cache.vpc_id
  peer_region = var.replica_region
  auto_accept = false

  tags = { Name = "lore-dev-regions" }
}

resource "aws_vpc_peering_connection_accepter" "regions" {
  provider                  = aws.replica
  vpc_peering_connection_id = aws_vpc_peering_connection.regions.id
  auto_accept               = true

  tags = { Name = "lore-dev-regions" }
}

# =============================================================================
# DNS — each side's Cloud Map zone resolves in the other VPC
# =============================================================================

resource "aws_route53_zone_association" "write_zone_in_replica_vpc" {
  zone_id    = module.lore.service_discovery_hosted_zone_id
  vpc_id     = module.regional_cache.vpc_id
  vpc_region = var.replica_region
}

resource "aws_route53_zone_association" "replica_zone_in_write_vpc" {
  provider   = aws.replica
  zone_id    = module.regional_cache.service_discovery_hosted_zone_id
  vpc_id     = module.lore.vpc_id
  vpc_region = var.write_region
}
