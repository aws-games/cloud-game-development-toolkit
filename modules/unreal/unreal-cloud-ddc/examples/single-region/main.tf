# Single-region example using unified module with config objects
module "unreal_cloud_ddc" {
  source = "../../"
  
  providers = {
    aws.primary        = aws
    awscc.primary      = awscc
    kubernetes.primary = kubernetes
    helm.primary       = helm
  }
  
  # VPC Configuration
  vpc_ids = {
    primary = aws_vpc.unreal_cloud_ddc_vpc.id
  }
  
  # Infrastructure Configuration
  infrastructure_config = {
    name           = "unreal-cloud-ddc"
    project_prefix = local.project_prefix
    environment    = "dev"
    region         = data.aws_region.current.name
    
    # EKS Configuration
    kubernetes_version      = "1.31"
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    
    # ScyllaDB Configuration
    scylla_subnets       = aws_subnet.private_subnets[*].id
    scylla_instance_type = "i4i.large"
    
    # Load Balancer Configuration
    monitoring_application_load_balancer_subnets = aws_subnet.public_subnets[*].id
  }
  
  # Application Configuration
  application_config = {
    name           = "unreal-cloud-ddc"
    project_prefix = "cgd"
    
    # Credentials
    ghcr_credentials_secret_manager_arn = var.github_credential_arn
    
    # Application Settings
    unreal_cloud_ddc_namespace = "unreal-cloud-ddc"
  }
  
  tags = local.tags
}