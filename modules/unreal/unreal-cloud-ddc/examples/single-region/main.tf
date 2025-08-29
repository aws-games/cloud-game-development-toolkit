# Single-region example using unified module with config objects
module "unreal_cloud_ddc" {
  source = "../../"
  
  providers = {
    aws.primary        = aws
    aws.secondary      = aws
    awscc.primary      = awscc
    awscc.secondary    = awscc
    kubernetes.primary = kubernetes
    kubernetes.secondary = kubernetes
    helm.primary       = helm
    helm.secondary     = helm
  }
  
  # Single region configuration - Deploy DDC infrastructure to one region only
  regions = {
    primary = { region = local.region.name }  # Primary region for DDC cluster (no secondary region)
  }
  
  # VPC Configuration
  vpc_ids = {
    primary = aws_vpc.unreal_cloud_ddc_vpc.id
  }
  
  # Security Groups
  existing_security_groups = [aws_security_group.allow_my_ip.id]
  
  # Module-level configuration (following Perforce pattern)
  project_prefix = local.project_prefix
  
  # Infrastructure Configuration
  infrastructure_config = {
    name        = "unreal-cloud-ddc"  # Hardcoded like Perforce
    environment = local.environment
    region      = local.region.name  # Matches regions.primary
    
    # EKS Configuration
    kubernetes_version      = "1.33"
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    
    # ScyllaDB Configuration
    scylla_subnets       = aws_subnet.private_subnets[*].id
    scylla_instance_type = "i4i.large"
    
    # Load Balancer Configuration
    monitoring_application_load_balancer_subnets = aws_subnet.public_subnets[*].id
    alb_certificate_arn = aws_acm_certificate_validation.scylla_monitoring.certificate_arn
  }
  
  # Application Configuration
  application_config = {
    name = "unreal-cloud-ddc"  # Hardcoded like Perforce
    
    # Credentials
    ghcr_credentials_secret_manager_arn = var.github_credential_arn
    
    # Application Settings
    unreal_cloud_ddc_namespace = local.ddc_namespace
  }
  
  # DNS Configuration (optional)
  route53_public_hosted_zone_name = var.route53_public_hosted_zone_name
  create_route53_private_hosted_zone = true
  ddc_subdomain = local.ddc_subdomain
  
  tags = local.tags
}