# Multi-region DDC deployment with both regions in single terraform apply

# Primary Region (us-east-1)
module "unreal_cloud_ddc_primary" {
  source = "../../"
  
  project_prefix = local.project_prefix
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc_primary.id
  existing_security_groups = [aws_security_group.allow_my_ip_primary.id]
  
  # Infrastructure Configuration
  ddc_infra_config = {
    name              = "unreal-cloud-ddc"
    project_prefix    = local.project_prefix
    environment       = local.environment
    region            = local.primary_region
    
    # EKS Configuration
    kubernetes_version     = local.kubernetes_version
    eks_node_group_subnets = aws_subnet.private_subnets_primary[*].id
    eks_api_access_cidrs   = [local.my_ip_cidr]
    
    # ScyllaDB Configuration
    scylla_replication_factor = 3
    scylla_subnets           = aws_subnet.private_subnets_primary[*].id
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
    monitoring_application_load_balancer_subnets = aws_subnet.public_subnets_primary[*].id
  }
  
  # Services Configuration
  ddc_services_config = {
    name           = "unreal-cloud-ddc"
    project_prefix = local.project_prefix
    
    unreal_cloud_ddc_version = local.unreal_cloud_ddc_version
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}

# Secondary Region (us-west-2)
module "unreal_cloud_ddc_secondary" {
  source = "../../"
  
  region = local.secondary_region  # REQUIRED: Must be different from primary region to avoid conflicts
  project_prefix = local.project_prefix
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc_secondary.id
  existing_security_groups = [aws_security_group.allow_my_ip_secondary.id]
  
  # Infrastructure Configuration
  ddc_infra_config = {
    name              = "unreal-cloud-ddc"
    project_prefix    = local.project_prefix
    environment       = local.environment
    region            = local.secondary_region
    
    # Multi-region coordination
    existing_scylla_seed = module.unreal_cloud_ddc_primary.ddc_infra.scylla_seed
    scylla_source_region = local.primary_region
    
    # EKS Configuration - MUST match primary region
    kubernetes_version     = module.unreal_cloud_ddc_primary.version_info.kubernetes_version
    eks_node_group_subnets = aws_subnet.private_subnets_secondary[*].id
    eks_api_access_cidrs   = [local.my_ip_cidr]
    
    # ScyllaDB Configuration
    scylla_replication_factor = 2
    scylla_subnets           = aws_subnet.private_subnets_secondary[*].id
    scylla_instance_type     = local.scylla_instance_type
    
    # Kubernetes Configuration
    unreal_cloud_ddc_namespace = "unreal-cloud-ddc"
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
    ddc_replication_region_url = module.unreal_cloud_ddc_primary.ddc_connection.endpoint_route53
  }
  
  depends_on = [module.unreal_cloud_ddc_primary]
}