provider "aws" {
  region = "us-west-2"
}

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

  enable_otel_sidecar = true

  auth_mode         = "external"
  auth_jwk_endpoint = var.auth_jwk_endpoint
  auth_jwt_issuer   = var.auth_jwt_issuer
  auth_jwt_audience = var.auth_jwt_audience
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
