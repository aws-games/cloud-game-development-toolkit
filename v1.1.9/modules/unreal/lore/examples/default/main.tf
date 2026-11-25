provider "aws" {
  region = "us-west-2"
}

# =============================================================================
# Write Tier
# =============================================================================

module "lore" {
  source = "../../"

  project_prefix        = "lore"
  environment           = "dev"
  container_image       = var.container_image
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
  instance_type         = "c8gd.8xlarge"

  enable_deletion_protection = false
  enable_force_destroy       = true
  asg_desired_size           = 1
  auth_mode                  = "none"
}

# =============================================================================
# Edge Pods
# =============================================================================

module "edge_1" {
  source = "../../modules/edge-pod"

  # Where to place this edge pod (can be any VPC with connectivity to write tier)
  vpc_id    = module.lore.vpc_id
  subnet_id = module.lore.private_subnet_ids[0]

  # Allow edge pod to reach the write tier's network
  server_security_group_id = module.lore.server_security_group_id

  # Same container image as the write tier
  container_image = var.container_image

  # Write tier Cloud Map DNS (gRPC:41337 + QUIC replication:41340)
  write_tier_dns = module.lore.write_tier_discovery_dns

  # Trust the write tier's TLS certificate
  ca_certificate_pem = module.lore.ca_certificate_pem

  # Who can connect to this edge pod
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
  name_prefix           = "edge-1"
  tags                  = { Role = "edge-pod", Index = "1" }
}

module "edge_2" {
  source = "../../modules/edge-pod"

  vpc_id                   = module.lore.vpc_id
  subnet_id                = module.lore.private_subnet_ids[1]
  server_security_group_id = module.lore.server_security_group_id
  container_image          = var.container_image
  write_tier_dns           = module.lore.write_tier_discovery_dns
  ca_certificate_pem       = module.lore.ca_certificate_pem
  allowed_ingress_cidrs    = var.allowed_ingress_cidrs
  name_prefix              = "edge-2"
  tags                     = { Role = "edge-pod", Index = "2" }
}
