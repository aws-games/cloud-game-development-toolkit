provider "aws" {
  region = "us-west-2"
}

# This example extends the default topology (write tier + edge pods) with:
# - Cognito authentication (client_credentials grant)
# - X-Ray tracing via ADOT sidecar
# - Deletion protection enabled (production-safe)
#
# Start with examples/default/ if you don't need auth yet.

# =============================================================================
# Write Tier
# =============================================================================

module "lore" {
  source = "../../"

  project_prefix        = "lore"
  environment           = "prod"
  container_image       = var.container_image
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
  instance_type         = "c8gd.8xlarge"

  auth_mode           = "cognito"
  enable_otel_sidecar = true

  enable_deletion_protection = var.enable_deletion_protection
  enable_force_destroy       = var.enable_force_destroy
}

# =============================================================================
# Edge Pods
# =============================================================================

module "edge_1" {
  source = "../../modules/edge-pod"

  vpc_id                   = module.lore.vpc_id
  subnet_id                = module.lore.private_subnet_ids[0]
  server_security_group_id = module.lore.server_security_group_id
  container_image          = var.container_image
  write_tier_dns           = module.lore.write_tier_discovery_dns
  ca_certificate_pem       = module.lore.ca_certificate_pem
  allowed_ingress_cidrs    = var.allowed_ingress_cidrs
  name_prefix              = "edge-1"
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
}
