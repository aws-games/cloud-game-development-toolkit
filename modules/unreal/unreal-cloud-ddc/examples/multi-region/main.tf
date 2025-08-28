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
  
  # Multi-region Configuration
  regions = {
    primary   = { region = var.regions[0] }
    secondary = { region = var.regions[1] }
  }
  
  # VPC Configuration
  vpc_ids = {
    primary   = module.vpc_primary.vpc_id
    secondary = module.vpc_secondary.vpc_id
  }
  
  # Infrastructure Configuration
  infrastructure_config = {
    name           = var.project_prefix
    project_prefix = var.project_prefix
    environment    = var.environment
    
    # EKS Configuration
    kubernetes_version      = var.eks_cluster_version
    eks_node_group_subnets = module.vpc_primary.private_subnet_ids
    
    # ScyllaDB Configuration
    scylla_subnets       = module.vpc_primary.private_subnet_ids
    scylla_instance_type = var.scylla_instance_type
    
    # Load Balancer Configuration
    monitoring_application_load_balancer_subnets = module.vpc_primary.public_subnet_ids
  }
  
  # Application Configuration
  application_config = {
    name           = var.project_prefix
    project_prefix = var.project_prefix
    
    # Credentials
    ghcr_credentials_secret_manager_arn = var.github_credential_arn_region_1
    
    # Application Settings
    unreal_cloud_ddc_namespace = "unreal-cloud-ddc"
  }
  
  tags = var.additional_tags
}

# VPC for primary region
module "vpc_primary" {
  source = "../single-region/vpc"
  
  providers = {
    aws = aws.primary
  }
  
  vpc_cidr               = var.vpc_cidr_region_1
  availability_zones     = local.azs_region_1
  public_subnets_cidrs   = [cidrsubnet(var.vpc_cidr_region_1, 8, 1), cidrsubnet(var.vpc_cidr_region_1, 8, 2)]
  private_subnets_cidrs  = [cidrsubnet(var.vpc_cidr_region_1, 8, 3), cidrsubnet(var.vpc_cidr_region_1, 8, 4)]
  additional_tags        = var.additional_tags
}

# VPC for secondary region
module "vpc_secondary" {
  source = "../single-region/vpc"
  
  providers = {
    aws = aws.secondary
  }
  
  vpc_cidr               = var.vpc_cidr_region_2
  availability_zones     = local.azs_region_2
  public_subnets_cidrs   = [cidrsubnet(var.vpc_cidr_region_2, 8, 1), cidrsubnet(var.vpc_cidr_region_2, 8, 2)]
  private_subnets_cidrs  = [cidrsubnet(var.vpc_cidr_region_2, 8, 3), cidrsubnet(var.vpc_cidr_region_2, 8, 4)]
  additional_tags        = var.additional_tags
}