# Single-region DDC deployment
module "unreal_cloud_ddc" {
  source = "../../"
  
  # Region configuration (optional - uses provider default if not specified)
  region = local.region
  
  # General/shared configuration
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
  existing_security_groups = [aws_security_group.allow_my_ip.id]  # Global access to all components
  ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  
  # Infrastructure Configuration
  ddc_infra_config = {
    name           = "unreal-cloud-ddc"
    project_prefix = local.project_prefix
    environment    = local.environment
    region         = local.region
    
    # EKS Configuration
    kubernetes_version     = local.kubernetes_version
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    eks_api_access_cidrs = ["${chomp(data.http.my_ip.response_body)}/32"]
    
    # ScyllaDB Configuration
    scylla_replication_factor = 3
    scylla_subnets           = aws_subnet.private_subnets[*].id
    scylla_instance_type     = "i4i.xlarge"
    
    # Kubernetes Configuration
    unreal_cloud_ddc_namespace = "unreal-cloud-ddc"
  }
  
  # Monitoring Configuration
  ddc_monitoring_config = {
    name           = "unreal-cloud-ddc"
    project_prefix = local.project_prefix
    environment    = local.environment
    
    create_scylla_monitoring_stack = true
    scylla_monitoring_instance_type = "t3.xlarge"
    
    create_application_load_balancer = true
    monitoring_application_load_balancer_subnets = aws_subnet.public_subnets[*].id
  }
  
  # Services Configuration
  ddc_services_config = {
    name           = "unreal-cloud-ddc"
    project_prefix = local.project_prefix
    
    unreal_cloud_ddc_version = "1.2.0"
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}