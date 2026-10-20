# =============================================================================
# Two offices, one repository.
#
# The write region runs the normal Lore module. The replica region runs a regional tier: same
# server, its own fragment store, but branch pointers and locks forwarded to the write region.
# Fragments flow between the two regions in both directions; branch pointers never leave the
# write region. See ../../README.md, "Multi-region", for why.
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
  auth_mode                  = "none"

  # Let the regional tier's VPC reach the write tier (security-group references do not cross
  # inter-region peering, so this is by CIDR).
  replication_ingress_cidrs = [local.replica_vpc_cidr]
  vpc_peering_routes = [{
    cidr_block                = local.replica_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.regions.id
  }]

  # Forward every put to the regional tier so the other office is warm before anyone asks.
  replication_peers = [{
    address  = module.regional_tier.tier_dns_name
    locality = "OtherRegion"
  }]
  trusted_ca_pem = module.regional_tier.ca_certificate_pem

  # Durable copy: S3 replicates the objects, Global Tables replicate the index rows. The peer
  # push above only warms the far cache; without these the other region cannot find content
  # once its cache evicts it.
  fragment_replication = {
    destination_bucket_arn   = module.regional_tier.fragment_bucket_arn
    destination_ready        = module.regional_tier.fragment_bucket_versioning_id
    replication_time_control = var.replication_time_control
    global_tables_region     = var.replica_region
  }
}

# =============================================================================
# Replica region — regional tier
# =============================================================================

module "regional_tier" {
  source = "../../modules/regional-tier"
  providers = {
    aws = aws.replica
  }

  name_prefix           = "lore-dev-replica"
  environment           = "dev"
  container_image       = var.replica_container_image
  allowed_ingress_cidrs = var.replica_office_cidrs
  vpc_cidr              = local.replica_vpc_cidr
  instance_type         = "c8gd.large"

  enable_deletion_protection = false
  enable_force_destroy       = true
  asg_desired_size           = 1
  auth_mode                  = "none"

  # The write region it belongs to
  write_region          = var.write_region
  write_region_vpc_cidr = local.write_vpc_cidr
  vpc_peering_routes = [{
    cidr_block                = local.write_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection_accepter.regions.id
  }]
  write_tier_dns_name           = module.lore.write_tier_dns_name
  write_tier_ca_certificate_pem = module.lore.ca_certificate_pem
  mutable_store_table_name      = module.lore.mutable_store_table_name
  mutable_store_table_arn       = module.lore.mutable_store_table_arn
  locks_table_name              = module.lore.locks_table_name
  locks_table_arn               = module.lore.locks_table_arn

  immutable_tables = {
    mode                        = "global_table"
    fragments_table_arn         = module.lore.fragments_table_arn
    fragment_metadata_table_arn = module.lore.fragment_metadata_table_arn
  }

  # This office's commits are forwarded to the write tier and replicated back by S3.
  replication_peers = [{
    address  = module.lore.write_tier_dns_name
    locality = "OtherRegion"
  }]
  enable_replication                 = true
  replication_destination_bucket_arn = module.lore.fragment_bucket_arn
  replication_destination_ready      = module.lore.fragment_bucket_versioning_id
  replication_time_control           = var.replication_time_control
}

# =============================================================================
# Inter-region VPC peering
# =============================================================================

resource "aws_vpc_peering_connection" "regions" {
  vpc_id      = module.lore.vpc_id
  peer_vpc_id = module.regional_tier.vpc_id
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

resource "aws_route53_zone_association" "write_zone_in_replica_vpc" {
  zone_id    = module.lore.service_discovery_hosted_zone_id
  vpc_id     = module.regional_tier.vpc_id
  vpc_region = var.replica_region
}

resource "aws_route53_zone_association" "replica_zone_in_write_vpc" {
  provider   = aws.replica
  zone_id    = module.regional_tier.service_discovery_hosted_zone_id
  vpc_id     = module.lore.vpc_id
  vpc_region = var.write_region
}
