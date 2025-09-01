# Single-region DDC deployment
module "unreal_cloud_ddc" {
  source = "../../"
  
  providers = {
    kubernetes = kubernetes
    helm       = helm
  }
  
  ########################################
  # Global Parent-Level Configuration
  ########################################
  
  # Region configuration (optional - uses provider default if not specified)
  region = local.primary_region
  
  # Route53 configuration for certificate management
  route53_public_hosted_zone_name = var.route53_public_hosted_zone_name
  
  # SSL Certificate for HTTPS
  certificate_arn = aws_acm_certificate.ddc.arn
  
  # Networking configuration
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
  public_subnets = aws_subnet.public_subnets[*].id   # Required for external NLB
  private_subnets = aws_subnet.private_subnets[*].id # Required for services
  existing_security_groups = [aws_security_group.allow_my_ip.id]  # Global access to all components
  
  # Centralized Logging Configuration (customizable)
  enable_centralized_logging = true
  log_retention_by_category = {
    infrastructure = 7   # NLB, ALB, EKS logs - short for example
    application    = 7   # DDC app logs - short for example  
    service        = 7   # ScyllaDB logs - short for example
  }
  
  ########################################
  # Submodule-Specific Configuration
  ########################################
  
  # Infrastructure Configuration (ddc-infra submodule)
  ddc_infra_config = {
    name           = "unreal-cloud-ddc"
    project_prefix = local.project_prefix
    environment    = local.environment
    region         = local.primary_region
    
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
  
  # Services Configuration (ddc-services submodule)
  ddc_services_config = {
    name           = "unreal-cloud-ddc"
    project_prefix = local.project_prefix
    
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}