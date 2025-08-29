# Multi-region example using unified module with config objects
module "unreal_cloud_ddc" {
  source = "../../"
  
  providers = {
    aws.primary        = aws.primary
    aws.secondary      = aws.secondary
    awscc.primary      = awscc.primary
    awscc.secondary    = awscc.secondary
    kubernetes.primary = kubernetes.primary
    kubernetes.secondary = kubernetes.secondary
    helm.primary       = helm.primary
    helm.secondary     = helm.secondary
  }
  
  # Multi-region Configuration - Deploy DDC infrastructure to both regions with cross-region replication
  regions = {
    primary   = { region = local.regions.primary.name }   # Primary region for main DDC cluster
    secondary = { region = local.regions.secondary.name } # Secondary region for replicated DDC cluster
  }
  
  # VPC Configuration
  vpc_ids = {
    primary   = aws_vpc.primary.id
    secondary = aws_vpc.secondary.id
  }
  
  # Security Groups
  existing_security_groups = [
    aws_security_group.allow_my_ip_primary.id,
    aws_security_group.allow_my_ip_secondary.id,
    aws_security_group.scylla_cross_region_primary.id,
    aws_security_group.scylla_cross_region_secondary.id
  ]
  
  # Module-level configuration (following Perforce pattern)
  project_prefix = local.project_prefix
  
  # Infrastructure Configuration
  infrastructure_config = {
    name        = "unreal-cloud-ddc"  # Hardcoded like Perforce
    environment = local.environment
    region      = local.regions.primary.name  # Matches regions.primary
    
    # EKS Configuration
    kubernetes_version      = "1.31"
    eks_node_group_subnets = aws_subnet.primary_private[*].id
    
    # ScyllaDB Configuration
    scylla_subnets       = aws_subnet.primary_private[*].id
    scylla_instance_type = "i4i.xlarge"
    
    # Load Balancer Configuration
    monitoring_application_load_balancer_subnets = aws_subnet.primary_public[*].id
  }
  
  # Application Configuration
  application_config = {
    name = "unreal-cloud-ddc"  # Hardcoded like Perforce
    
    # Credentials
    ghcr_credentials_secret_manager_arn = var.github_credential_arn_region_1
    
    # Application Settings
    unreal_cloud_ddc_namespace = local.ddc_namespace
  }
  
  # DNS Configuration (optional)
  route53_public_hosted_zone_name = var.route53_public_hosted_zone_name
  create_route53_private_hosted_zone = true
  ddc_subdomain = local.ddc_subdomain
  
  tags = local.tags
}

