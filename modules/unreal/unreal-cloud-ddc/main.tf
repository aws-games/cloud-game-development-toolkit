########################################
# Primary Region Infrastructure
########################################
module "infrastructure_primary" {
  source = "./modules/infrastructure"
  

  
  providers = {
    aws   = aws.primary
    awscc = awscc.primary
  }
  
  # General
  name                     = var.infrastructure_config.name
  project_prefix           = var.infrastructure_config.project_prefix
  environment              = var.infrastructure_config.environment
  region                   = local.primary_region
  debug                    = var.infrastructure_config.debug
  vpc_id                   = var.vpc_ids.primary
  existing_security_groups = var.existing_security_groups
  is_primary_region        = true
  
  # ScyllaDB Configuration
  scylla_replication_factor             = 3
  scylla_subnets                        = var.infrastructure_config.scylla_subnets
  scylla_ami_name                       = var.infrastructure_config.scylla_ami_name
  scylla_instance_type                  = var.infrastructure_config.scylla_instance_type
  scylla_architecture                   = var.infrastructure_config.scylla_architecture
  scylla_db_storage                     = var.infrastructure_config.scylla_db_storage
  scylla_db_throughput                  = var.infrastructure_config.scylla_db_throughput
  create_scylla_monitoring_stack        = var.infrastructure_config.create_scylla_monitoring_stack
  scylla_monitoring_instance_type       = var.infrastructure_config.scylla_monitoring_instance_type
  scylla_monitoring_instance_storage    = var.infrastructure_config.scylla_monitoring_instance_storage
  
  # EKS Configuration
  kubernetes_version                      = var.infrastructure_config.kubernetes_version
  eks_node_group_subnets                  = var.infrastructure_config.eks_node_group_subnets
  eks_cluster_public_endpoint_access_cidr = var.infrastructure_config.eks_cluster_public_endpoint_access_cidr
  eks_cluster_public_access               = var.infrastructure_config.eks_cluster_public_access
  eks_cluster_private_access              = var.infrastructure_config.eks_cluster_private_access
  
  # Node Groups
  nvme_managed_node_instance_type   = var.infrastructure_config.nvme_managed_node_instance_type
  nvme_managed_node_desired_size    = var.infrastructure_config.nvme_managed_node_desired_size
  nvme_managed_node_max_size        = var.infrastructure_config.nvme_managed_node_max_size
  nvme_managed_node_min_size        = var.infrastructure_config.nvme_managed_node_min_size
  
  worker_managed_node_instance_type = var.infrastructure_config.worker_managed_node_instance_type
  worker_managed_node_desired_size  = var.infrastructure_config.worker_managed_node_desired_size
  worker_managed_node_max_size      = var.infrastructure_config.worker_managed_node_max_size
  worker_managed_node_min_size      = var.infrastructure_config.worker_managed_node_min_size
  
  system_managed_node_instance_type = var.infrastructure_config.system_managed_node_instance_type
  system_managed_node_desired_size  = var.infrastructure_config.system_managed_node_desired_size
  system_managed_node_max_size      = var.infrastructure_config.system_managed_node_max_size
  system_managed_node_min_size      = var.infrastructure_config.system_managed_node_min_size
  
  # Load Balancer Configuration
  create_application_load_balancer                    = var.infrastructure_config.create_application_load_balancer
  internal_facing_application_load_balancer           = var.infrastructure_config.internal_facing_application_load_balancer
  monitoring_application_load_balancer_subnets        = var.infrastructure_config.monitoring_application_load_balancer_subnets
  alb_certificate_arn                                 = var.infrastructure_config.alb_certificate_arn
  enable_scylla_monitoring_lb_deletion_protection     = var.infrastructure_config.enable_scylla_monitoring_lb_deletion_protection
  enable_scylla_monitoring_lb_access_logs             = var.infrastructure_config.enable_scylla_monitoring_lb_access_logs
  scylla_monitoring_lb_access_logs_bucket             = var.infrastructure_config.scylla_monitoring_lb_access_logs_bucket
  scylla_monitoring_lb_access_logs_prefix             = var.infrastructure_config.scylla_monitoring_lb_access_logs_prefix
  
  tags = var.tags
}

########################################
# Primary Region Applications
########################################
module "applications_primary" {
  source = "./modules/applications"
  
  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
    aws        = aws.primary
  }
  
  # General
  name           = var.application_config.name
  project_prefix = var.application_config.project_prefix
  region         = local.primary_region
  
  # Multi-region configuration
  is_multi_region_deployment = local.is_multi_region
  
  # EKS Configuration from infrastructure output
  cluster_name              = module.infrastructure_primary.cluster_name
  cluster_oidc_provider_arn = module.infrastructure_primary.oidc_provider_arn
  
  # S3 Configuration from infrastructure output
  s3_bucket_id = module.infrastructure_primary.s3_bucket_id
  
  # Application Configuration
  unreal_cloud_ddc_namespace            = var.application_config.unreal_cloud_ddc_namespace
  unreal_cloud_ddc_version              = var.application_config.unreal_cloud_ddc_version
  unreal_cloud_ddc_service_account_name = var.application_config.unreal_cloud_ddc_service_account_name
  unreal_cloud_ddc_helm_config = {
    bucket_name        = module.infrastructure_primary.s3_bucket_id
    scylla_ips        = join(",", module.infrastructure_primary.scylla_ips)
    region            = local.primary_region
    aws_region        = local.primary_region
    token             = data.aws_secretsmanager_secret_version.unreal_cloud_ddc_token.secret_string
    security_group_ids = join(",", var.existing_security_groups)
  }
  unreal_cloud_ddc_helm_base_infra_chart = local.default_single_region_chart
  
  # Credentials
  ghcr_credentials_secret_manager_arn = var.application_config.ghcr_credentials_secret_manager_arn
  oidc_credentials_secret_manager_arn = var.application_config.oidc_credentials_secret_manager_arn
  
  # Certificate Management
  certificate_manager_hosted_zone_arn = var.application_config.certificate_manager_hosted_zone_arn
  enable_certificate_manager          = var.application_config.enable_certificate_manager
  
  tags = var.tags
  
  depends_on = [module.infrastructure_primary]
}

########################################
# Secondary Region Infrastructure (Conditional)
########################################
module "infrastructure_secondary" {
  count  = local.is_multi_region ? 1 : 0
  source = "./modules/infrastructure"
  
  providers = {
    aws   = aws.secondary
    awscc = awscc.secondary
  }
  
  # General
  name                     = var.infrastructure_config.name
  project_prefix           = var.infrastructure_config.project_prefix
  environment              = var.infrastructure_config.environment
  region                   = local.secondary_region
  debug                    = var.infrastructure_config.debug
  vpc_id                   = var.vpc_ids.secondary
  existing_security_groups = var.existing_security_groups
  is_primary_region        = false
  
  # ScyllaDB seed from primary region
  existing_scylla_seed = module.infrastructure_primary.scylla_seed
  
  # ScyllaDB Configuration
  scylla_replication_factor             = 2
  scylla_subnets                        = var.infrastructure_config.scylla_subnets
  scylla_ami_name                       = var.infrastructure_config.scylla_ami_name
  scylla_instance_type                  = var.infrastructure_config.scylla_instance_type
  scylla_architecture                   = var.infrastructure_config.scylla_architecture
  scylla_db_storage                     = var.infrastructure_config.scylla_db_storage
  scylla_db_throughput                  = var.infrastructure_config.scylla_db_throughput
  create_scylla_monitoring_stack        = var.infrastructure_config.create_scylla_monitoring_stack
  scylla_monitoring_instance_type       = var.infrastructure_config.scylla_monitoring_instance_type
  scylla_monitoring_instance_storage    = var.infrastructure_config.scylla_monitoring_instance_storage
  
  # EKS Configuration
  kubernetes_version                      = var.infrastructure_config.kubernetes_version
  eks_node_group_subnets                  = var.infrastructure_config.eks_node_group_subnets
  eks_cluster_public_endpoint_access_cidr = var.infrastructure_config.eks_cluster_public_endpoint_access_cidr
  eks_cluster_public_access               = var.infrastructure_config.eks_cluster_public_access
  eks_cluster_private_access              = var.infrastructure_config.eks_cluster_private_access
  
  # Node Groups
  nvme_managed_node_instance_type   = var.infrastructure_config.nvme_managed_node_instance_type
  nvme_managed_node_desired_size    = var.infrastructure_config.nvme_managed_node_desired_size
  nvme_managed_node_max_size        = var.infrastructure_config.nvme_managed_node_max_size
  nvme_managed_node_min_size        = var.infrastructure_config.nvme_managed_node_min_size
  
  worker_managed_node_instance_type = var.infrastructure_config.worker_managed_node_instance_type
  worker_managed_node_desired_size  = var.infrastructure_config.worker_managed_node_desired_size
  worker_managed_node_max_size      = var.infrastructure_config.worker_managed_node_max_size
  worker_managed_node_min_size      = var.infrastructure_config.worker_managed_node_min_size
  
  system_managed_node_instance_type = var.infrastructure_config.system_managed_node_instance_type
  system_managed_node_desired_size  = var.infrastructure_config.system_managed_node_desired_size
  system_managed_node_max_size      = var.infrastructure_config.system_managed_node_max_size
  system_managed_node_min_size      = var.infrastructure_config.system_managed_node_min_size
  
  # Load Balancer Configuration
  create_application_load_balancer                    = var.infrastructure_config.create_application_load_balancer
  internal_facing_application_load_balancer           = var.infrastructure_config.internal_facing_application_load_balancer
  monitoring_application_load_balancer_subnets        = var.infrastructure_config.monitoring_application_load_balancer_subnets
  alb_certificate_arn                                 = var.infrastructure_config.alb_certificate_arn
  enable_scylla_monitoring_lb_deletion_protection     = var.infrastructure_config.enable_scylla_monitoring_lb_deletion_protection
  enable_scylla_monitoring_lb_access_logs             = var.infrastructure_config.enable_scylla_monitoring_lb_access_logs
  scylla_monitoring_lb_access_logs_bucket             = var.infrastructure_config.scylla_monitoring_lb_access_logs_bucket
  scylla_monitoring_lb_access_logs_prefix             = var.infrastructure_config.scylla_monitoring_lb_access_logs_prefix
  
  tags = var.tags
  
  depends_on = [module.infrastructure_primary]
}

########################################
# Secondary Region Applications (Conditional)
########################################
module "applications_secondary" {
  count  = local.is_multi_region ? 1 : 0
  source = "./modules/applications"
  
  providers = {
    kubernetes = kubernetes.secondary
    helm       = helm.secondary
    aws        = aws.secondary
  }
  
  # General
  name           = var.application_config.name
  project_prefix = var.application_config.project_prefix
  region         = local.secondary_region
  
  # Multi-region configuration
  is_multi_region_deployment = local.is_multi_region
  
  # EKS Configuration from infrastructure output
  cluster_name              = module.infrastructure_secondary[0].cluster_name
  cluster_oidc_provider_arn = module.infrastructure_secondary[0].oidc_provider_arn
  
  # S3 Configuration from infrastructure output
  s3_bucket_id = module.infrastructure_secondary[0].s3_bucket_id
  
  # Application Configuration
  unreal_cloud_ddc_namespace              = var.application_config.unreal_cloud_ddc_namespace
  unreal_cloud_ddc_version                = var.application_config.unreal_cloud_ddc_version
  unreal_cloud_ddc_service_account_name   = var.application_config.unreal_cloud_ddc_service_account_name
  unreal_cloud_ddc_helm_config            = {}
  unreal_cloud_ddc_helm_base_infra_chart  = local.default_single_region_chart
  unreal_cloud_ddc_helm_replication_chart = local.default_multi_region_chart
  
  # Credentials
  ghcr_credentials_secret_manager_arn = var.application_config.ghcr_credentials_secret_manager_arn
  oidc_credentials_secret_manager_arn = var.application_config.oidc_credentials_secret_manager_arn
  
  # Certificate Management
  certificate_manager_hosted_zone_arn = var.application_config.certificate_manager_hosted_zone_arn
  enable_certificate_manager          = var.application_config.enable_certificate_manager
  
  tags = var.tags
  
  depends_on = [module.infrastructure_secondary, module.applications_primary]
}