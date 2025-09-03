########################################
# Conditional Submodule Architecture
# Multiple parent module instances pattern - one per region
########################################



########################################
# DDC Infrastructure (Conditional)
########################################
module "ddc_infra" {
  source = "./modules/ddc-infra"
  count  = var.ddc_infra_config != null ? 1 : 0

  # Pass through infrastructure config
  name                     = var.ddc_infra_config.name
  project_prefix           = var.ddc_infra_config.project_prefix
  environment              = var.ddc_infra_config.environment
  region                   = var.ddc_infra_config.region
  debug                    = var.debug_mode == "enabled"
  vpc_id                   = var.existing_vpc_id
  existing_security_groups = var.existing_security_groups

  # ScyllaDB Configuration
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
# DDC Services (Conditional)
########################################
module "ddc_services" {
  source = "./modules/ddc-services"
  count  = var.ddc_services_config != null ? 1 : 0

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  # Pass through services config
  name           = var.ddc_services_config.name
  project_prefix = var.ddc_services_config.project_prefix
  region         = var.ddc_infra_config != null ? module.ddc_infra[0].region : var.ddc_services_config.region

  # Use outputs from ddc_infra and parent module NLB
  cluster_endpoint     = var.ddc_infra_config != null ? module.ddc_infra[0].cluster_endpoint : null
  cluster_name         = var.ddc_infra_config != null ? module.ddc_infra[0].cluster_name : null
  nlb_arn              = null  # Not used in services module
  nlb_target_group_arn = local.target_group_arn  # Connect to parent NLB target group
  nlb_dns_name         = null  # Not used in services module
  namespace            = var.ddc_infra_config != null ? var.ddc_infra_config.unreal_cloud_ddc_namespace : null
  service_account      = var.ddc_infra_config != null ? var.ddc_infra_config.unreal_cloud_ddc_service_account_name : null
  service_account_arn  = var.ddc_infra_config != null ? module.ddc_infra[0].service_account_arn : null
  s3_bucket_id         = var.ddc_infra_config != null ? module.ddc_infra[0].s3_bucket_id : null
  scylla_ips           = var.ddc_infra_config != null ? module.ddc_infra[0].scylla_ips : []
  scylla_dns_name      = var.ddc_infra_config != null ? "scylla.${local.private_zone_name}" : null
  scylla_datacenter_name = var.ddc_infra_config != null ? module.ddc_infra[0].scylla_datacenter_name : null
  scylla_keyspace_suffix = var.ddc_infra_config != null ? module.ddc_infra[0].scylla_keyspace_suffix : null

  # EKS Addons Configuration (from ddc-infra)
  oidc_provider_arn                   = var.ddc_infra_config != null ? module.ddc_infra[0].oidc_provider_arn : null
  ebs_csi_role_arn                    = var.ddc_infra_config != null ? module.ddc_infra[0].ebs_csi_role_arn : null
  enable_certificate_manager          = var.ddc_infra_config != null ? var.ddc_infra_config.enable_certificate_manager : false
  certificate_manager_hosted_zone_arn = var.ddc_infra_config != null ? var.ddc_infra_config.certificate_manager_hosted_zone_arn : []

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

  # Multi-region SSM coordination
  ssm_document_name       = var.ddc_infra_config != null ? module.ddc_infra[0].ssm_document_name : null
  scylla_seed_instance_id = var.ddc_infra_config != null ? module.ddc_infra[0].scylla_seed_instance_id : null

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
