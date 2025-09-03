########################################
# Conditional Submodule Architecture
# Multiple parent module instances pattern - one per region
########################################



########################################
# DDC Infrastructure (Always Created)
########################################
module "ddc_infra" {
  source = "./modules/ddc-infra"

  # Database Configuration (Mutual Exclusivity)
  scylla_config = var.scylla_config
  amazon_keyspaces_config = var.amazon_keyspaces_config
  
  # Pass through infrastructure config
  name                     = var.ddc_infra_config.name
  project_prefix           = var.ddc_infra_config.project_prefix
  environment              = var.ddc_infra_config.environment
  region                   = var.ddc_infra_config.region
  debug                    = var.debug_mode == "enabled"
  vpc_id                   = var.existing_vpc_id
  existing_security_groups = var.existing_security_groups

  # ScyllaDB Configuration (when scylla_config provided)
  create_seed_node         = var.ddc_infra_config.create_seed_node
  existing_scylla_seed     = var.ddc_infra_config.existing_scylla_seed
  scylla_source_region     = var.ddc_infra_config.scylla_source_region

  scylla_replication_factor = var.ddc_infra_config.scylla_replication_factor
  scylla_subnets           = var.ddc_infra_config.scylla_subnets
  scylla_ami_name          = var.ddc_infra_config.scylla_ami_name
  scylla_instance_type     = var.ddc_infra_config.scylla_instance_type
  scylla_architecture      = var.ddc_infra_config.scylla_architecture
  scylla_db_storage        = var.ddc_infra_config.scylla_db_storage
  scylla_db_throughput     = var.ddc_infra_config.scylla_db_throughput

  # EKS Configuration
  kubernetes_version                      = var.ddc_infra_config.kubernetes_version
  eks_node_group_subnets                  = var.ddc_infra_config.eks_node_group_subnets
  eks_cluster_public_endpoint_access_cidr = var.ddc_infra_config.eks_api_access_cidrs
  eks_cluster_public_access               = var.ddc_infra_config.eks_cluster_public_access
  eks_cluster_private_access              = var.ddc_infra_config.eks_cluster_private_access

  # Node Groups
  nvme_managed_node_instance_type   = var.ddc_infra_config.nvme_managed_node_instance_type
  nvme_managed_node_desired_size    = var.ddc_infra_config.nvme_managed_node_desired_size
  nvme_managed_node_max_size        = var.ddc_infra_config.nvme_managed_node_max_size
  nvme_managed_node_min_size        = var.ddc_infra_config.nvme_managed_node_min_size

  worker_managed_node_instance_type = var.ddc_infra_config.worker_managed_node_instance_type
  worker_managed_node_desired_size  = var.ddc_infra_config.worker_managed_node_desired_size
  worker_managed_node_max_size      = var.ddc_infra_config.worker_managed_node_max_size
  worker_managed_node_min_size      = var.ddc_infra_config.worker_managed_node_min_size

  system_managed_node_instance_type = var.ddc_infra_config.system_managed_node_instance_type
  system_managed_node_desired_size  = var.ddc_infra_config.system_managed_node_desired_size
  system_managed_node_max_size      = var.ddc_infra_config.system_managed_node_max_size
  system_managed_node_min_size      = var.ddc_infra_config.system_managed_node_min_size

  # Kubernetes Configuration
  unreal_cloud_ddc_namespace            = var.ddc_infra_config.unreal_cloud_ddc_namespace
  unreal_cloud_ddc_service_account_name = var.ddc_infra_config.unreal_cloud_ddc_service_account_name

  # Certificate Management
  certificate_manager_hosted_zone_arn = var.ddc_infra_config.certificate_manager_hosted_zone_arn
  enable_certificate_manager          = var.ddc_infra_config.enable_certificate_manager

  # Additional Security Groups
  additional_nlb_security_groups = var.ddc_infra_config.additional_nlb_security_groups
  additional_eks_security_groups = var.ddc_infra_config.additional_eks_security_groups

  # Multi-region monitoring (empty for single region)
  scylla_ips_by_region = {}

  # OIDC Credentials (from services config)
  oidc_credentials_secret_manager_arn = var.ddc_services_config != null ? var.ddc_services_config.oidc_credentials_secret_manager_arn : null
  
  # Logging configuration
  log_base_prefix = local.log_base_prefix
  scylla_logging_enabled = local.scylla_logging_enabled


  tags = var.tags
}



########################################
# DDC Services (Always Created)
########################################
module "ddc_services" {
  source = "./modules/ddc-services"

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  # Pass through services config
  name           = var.ddc_services_config.name
  project_prefix = var.ddc_services_config.project_prefix
  region         = var.ddc_infra_config != null ? module.ddc_infra.region : var.ddc_services_config.region

  # Use outputs from ddc_infra and parent module NLB
  cluster_endpoint     = module.ddc_infra.cluster_endpoint
  cluster_name         = module.ddc_infra.cluster_name
  nlb_arn              = null  # Not used in services module
  nlb_target_group_arn = local.target_group_arn  # Connect to parent NLB target group
  nlb_dns_name         = null  # Not used in services module
  namespace            = var.ddc_infra_config.unreal_cloud_ddc_namespace
  service_account      = var.ddc_infra_config.unreal_cloud_ddc_service_account_name
  service_account_arn  = module.ddc_infra.service_account_arn
  s3_bucket_id         = module.ddc_infra.s3_bucket_id
  
  # Database connection abstraction (from ddc_infra)
  database_connection = module.ddc_infra.database_connection
  
  # Legacy Scylla parameters (for backward compatibility during transition)
  scylla_ips           = module.ddc_infra.scylla_ips
  scylla_dns_name      = local.database_type == "scylla" ? "scylla.${local.private_zone_name}" : null
  scylla_datacenter_name = module.ddc_infra.scylla_datacenter_name
  scylla_keyspace_suffix = module.ddc_infra.scylla_keyspace_suffix

  # EKS Addons Configuration (from ddc-infra)
  oidc_provider_arn                   = module.ddc_infra.oidc_provider_arn
  ebs_csi_role_arn                    = module.ddc_infra.ebs_csi_role_arn
  enable_certificate_manager          = var.ddc_infra_config.enable_certificate_manager
  certificate_manager_hosted_zone_arn = var.ddc_infra_config.certificate_manager_hosted_zone_arn

  # Service Configuration
  unreal_cloud_ddc_version   = var.ddc_services_config.unreal_cloud_ddc_version
  ddc_replication_region_url = var.ddc_services_config.ddc_replication_region_url

  # Bearer token (always read from Secrets Manager - either created or existing)
  ddc_bearer_token = var.create_bearer_token == true ? aws_secretsmanager_secret_version.unreal_cloud_ddc_token[0].secret_string : (
    var.ddc_application_config.bearer_token_secret_arn != null ? data.aws_secretsmanager_secret_version.existing_token[0].secret_string : "generated-token"
  )

  # Credentials
  ghcr_credentials_secret_manager_arn = var.ddc_services_config.ghcr_credentials_secret_manager_arn
  oidc_credentials_secret_manager_arn = var.ddc_services_config.oidc_credentials_secret_manager_arn

  # ScyllaDB Configuration
  replication_factor = var.ddc_infra_config != null ? var.ddc_infra_config.scylla_replication_factor : 3

  # Multi-region SSM coordination (Scylla only)
  ssm_document_name       = local.database_type == "scylla" ? module.ddc_infra.ssm_document_name : null
  scylla_seed_instance_id = local.database_type == "scylla" ? module.ddc_infra.scylla_seed_instance_id : null

  # Cleanup configuration
  helm_cleanup_timeout = var.auto_cleanup_timeout
  auto_helm_cleanup    = var.enable_auto_cleanup
  remove_tgb_finalizers = var.enable_auto_cleanup
  auto_cleanup_status_messages = var.auto_cleanup_status_messages
  
  # Logging configuration
  log_base_prefix = local.log_base_prefix
  ddc_logging_enabled = local.ddc_logging_enabled

  tags = var.tags
  depends_on = [module.ddc_infra]
}
