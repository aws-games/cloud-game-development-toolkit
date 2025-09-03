# Multi-region DDC deployment with both regions in single terraform apply

# Primary Region (us-east-1)
module "unreal_cloud_ddc_primary" {
  source = "../../"
  
  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
  }
  
  # Basic Configuration
  vpc_id = aws_vpc.primary.id
  public_subnets = aws_subnet.primary_public[*].id
  private_subnets = aws_subnet.primary_private[*].id
  existing_security_groups = [aws_security_group.allow_my_ip_primary.id]
  
  # Bearer Token - Primary creates and replicates
  bearer_token_replica_regions = [local.secondary_region]
  
  # DNS Configuration
  route53_public_hosted_zone_name = var.route53_public_hosted_zone_name
  certificate_arn = aws_acm_certificate_validation.ddc.certificate_arn
  
  # Infrastructure Configuration
  ddc_infra_config = {
    eks_node_group_subnets = aws_subnet.primary_private[*].id
    eks_api_access_cidrs   = [local.my_ip_cidr]
    scylla_subnets = aws_subnet.primary_private[*].id
  }
  
  # Services Configuration
  ddc_services_config = {
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}

# Secondary Region (us-west-1)
module "unreal_cloud_ddc_secondary" {
  source = "../../"
  
  providers = {
    kubernetes = kubernetes.secondary
    helm       = helm.secondary
  }
  
  # Basic Configuration
  region = local.secondary_region
  vpc_id = aws_vpc.secondary.id
  public_subnets = aws_subnet.secondary_public[*].id
  private_subnets = aws_subnet.secondary_private[*].id
  existing_security_groups = [aws_security_group.allow_my_ip_secondary.id]
  
  # Bearer Token - Secondary uses replicated token
  create_bearer_token = false
  ddc_application_config = {
    bearer_token_secret_arn = module.unreal_cloud_ddc_primary.bearer_token_secret_arn
  }
  
  # DNS Configuration
  route53_public_hosted_zone_name = var.route53_public_hosted_zone_name
  certificate_arn = aws_acm_certificate_validation.ddc.certificate_arn
  create_private_dns_records = false
  
  # Infrastructure Configuration
  ddc_infra_config = {
    create_seed_node = false
    existing_scylla_seed = module.unreal_cloud_ddc_primary.ddc_infra.scylla_seed
    eks_node_group_subnets = aws_subnet.secondary_private[*].id
    eks_api_access_cidrs = [local.my_ip_cidr]
    scylla_subnets = aws_subnet.secondary_private[*].id
    scylla_replication_factor = 2
  }
  
  # Services Configuration
  ddc_services_config = {
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
    ddc_replication_region_url = module.unreal_cloud_ddc_primary.ddc_connection.endpoint_nlb
  }
  
  depends_on = [module.unreal_cloud_ddc_primary]
}