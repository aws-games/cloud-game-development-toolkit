# Multi-region DDC deployment with both regions in single terraform apply

# Primary Region (us-east-1)
module "unreal_cloud_ddc_primary" {
  source = "../../"
  
  # CRITICAL: Pass region-specific providers (AWS auto-inherited)
  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
    # AWS provider auto-inherited - no need to pass!
  }
  
  project_prefix = local.project_prefix
  vpc_id = aws_vpc.primary.id
  existing_security_groups = [aws_security_group.allow_my_ip_primary.id]
  
  # Infrastructure Configuration
  ddc_infra_config = {
    name              = "unreal-cloud-ddc"
    project_prefix    = local.project_prefix
    environment       = local.environment
    region            = local.primary_region
    
    # Multi-region coordination
    create_seed_node = true
    
    # EKS Configuration
    kubernetes_version     = local.kubernetes_version
    eks_node_group_subnets = aws_subnet.primary_private[*].id
    eks_api_access_cidrs   = [local.my_ip_cidr]
    
    # ScyllaDB Configuration
    scylla_replication_factor = 3
    scylla_subnets           = aws_subnet.primary_private[*].id
    scylla_instance_type     = local.scylla_instance_type
    
    # Kubernetes Configuration
    unreal_cloud_ddc_namespace = "unreal-cloud-ddc"
  }
  
  # Monitoring Configuration (primary region only)
  ddc_monitoring_config = {
    name           = "unreal-cloud-ddc"
    project_prefix = local.project_prefix
    environment    = local.environment
    
    create_scylla_monitoring_stack = true
    scylla_monitoring_instance_type = local.scylla_monitoring_instance_type
    
    create_application_load_balancer = true
    alb_certificate_arn = aws_acm_certificate_validation.ddc.certificate_arn
    monitoring_application_load_balancer_subnets = aws_subnet.primary_public[*].id
  }
  
  # Services Configuration
  ddc_services_config = {
    name           = "unreal-cloud-ddc"
    project_prefix = local.project_prefix
    
    unreal_cloud_ddc_version = local.unreal_cloud_ddc_version
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}

# Secondary Region (us-east-2)
module "unreal_cloud_ddc_secondary" {
  source = "../../"
  
  # CRITICAL: Pass region-specific providers (AWS auto-inherited)
  providers = {
    kubernetes = kubernetes.secondary
    helm       = helm.secondary
    # AWS provider auto-inherited - no need to pass!
  }
  
  region = local.secondary_region  # REQUIRED: Must be different from primary region to avoid conflicts
  project_prefix = local.project_prefix
  vpc_id = aws_vpc.secondary.id
  existing_security_groups = [aws_security_group.allow_my_ip_secondary.id]
  
  # Infrastructure Configuration
  ddc_infra_config = {
    name              = "unreal-cloud-ddc"
    project_prefix    = local.project_prefix
    environment       = local.environment
    region            = local.secondary_region
    
    # Multi-region coordination
    create_seed_node     = false
    existing_scylla_seed = module.unreal_cloud_ddc_primary.ddc_infra.scylla_seed
    scylla_source_region = local.primary_region
    
    # EKS Configuration - MUST match primary region
    kubernetes_version     = module.unreal_cloud_ddc_primary.version_info.kubernetes_version
    eks_node_group_subnets = aws_subnet.secondary_private[*].id
    eks_api_access_cidrs   = [local.my_ip_cidr]
    
    # ScyllaDB Configuration
    scylla_replication_factor = 2
    scylla_subnets           = aws_subnet.secondary_private[*].id
    scylla_instance_type     = local.scylla_instance_type
    
    # Kubernetes Configuration - MUST match primary region
    unreal_cloud_ddc_namespace = module.unreal_cloud_ddc_primary.ddc_connection.namespace
  }
  
  # No monitoring in secondary region
  ddc_monitoring_config = null
  
  # Services Configuration
  ddc_services_config = {
    name           = "unreal-cloud-ddc"
    project_prefix = local.project_prefix
    
    unreal_cloud_ddc_version = module.unreal_cloud_ddc_primary.version_info.ddc_version  # MUST match primary region
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
    
    # Replication URL
    ddc_replication_region_url = module.unreal_cloud_ddc_primary.ddc_connection.endpoint_nlb
  }
  
  depends_on = [module.unreal_cloud_ddc_primary]
}