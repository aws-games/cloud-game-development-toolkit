########################################
# Conditional Submodule Architecture
# Multiple parent module instances pattern - one per region
########################################



########################################
# DDC Infrastructure (Always Created)
########################################
module "ddc_infra" {
  source = "./modules/ddc-infra"

  # Database Configuration (ScyllaDB only)
  scylla_config = var.ddc_infra_config != null ? var.ddc_infra_config.scylla_config : null
  keyspace_name = local.scylla_config != null ? local.scylla_config.local_keyspace_name : null

  # Pass through infrastructure config
  name           = var.ddc_infra_config != null ? var.ddc_infra_config.name : "unreal-cloud-ddc"
  project_prefix = var.project_prefix
  environment    = var.environment
  region         = local.region
  debug          = var.debug_mode == "enabled"
  vpc_id         = var.vpc_id
  # Security groups now embedded in load_balancers_config and eks_access_config

  # ScyllaDB Configuration (when scylla_config provided)
  create_seed_node     = var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.create_seed_node : true
  existing_scylla_seed = var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.existing_scylla_seed : null
  scylla_source_region = var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.scylla_source_region : null

  scylla_replication_factor = var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.current_region.replication_factor : 3
  scylla_subnets            = var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.subnets : []
  scylla_ami_name           = var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.scylla_ami_name : "ScyllaDB 6.0.1"
  scylla_instance_type      = var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.scylla_instance_type : "i4i.2xlarge"
  scylla_architecture       = var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.scylla_architecture : "x86_64"
  scylla_db_storage         = var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.scylla_db_storage : 100
  scylla_db_throughput      = var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.scylla_db_throughput : 200

  # EKS Configuration
  kubernetes_version     = var.ddc_infra_config.kubernetes_version
  eks_node_group_subnets = var.ddc_infra_config.eks_node_group_subnets

  # EKS Access Configuration (new structure)
  eks_access_config = var.ddc_infra_config.eks_access_config != null ? var.ddc_infra_config.eks_access_config : {
    mode    = "hybrid"
    public  = null
    private = null
  }

  # Node Groups
  nvme_managed_node_instance_type = var.ddc_infra_config.nvme_managed_node_instance_type
  nvme_managed_node_desired_size  = var.ddc_infra_config.nvme_managed_node_desired_size
  nvme_managed_node_max_size      = var.ddc_infra_config.nvme_managed_node_max_size
  nvme_managed_node_min_size      = var.ddc_infra_config.nvme_managed_node_min_size

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


  # Multi-region monitoring (empty for single region)
  scylla_ips_by_region = {}

  # OIDC Credentials (from services config)
  oidc_credentials_secret_manager_arn = var.ddc_app_config != null ? var.ddc_app_config.oidc_credentials_secret_manager_arn : null

  # Logging configuration
  log_base_prefix        = local.log_base_prefix
  scylla_logging_enabled = local.scylla_logging_enabled

  # VPC Endpoints configuration
  vpc_endpoints_config   = var.vpc_endpoints
  eks_uses_vpc_endpoint  = local.eks_uses_vpc_endpoint

  tags = var.tags
}



########################################
# DDC Services (Always Created)
########################################
module "ddc_services" {
  source = "./modules/ddc-app"

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  # Pass through services config
  name           = var.ddc_app_config != null ? var.ddc_app_config.name : "unreal-cloud-ddc"
  project_prefix = var.project_prefix
  region         = local.region

  # Use outputs from ddc_infra and parent module NLB
  cluster_endpoint     = module.ddc_infra.cluster_endpoint
  cluster_name         = module.ddc_infra.cluster_name
  nlb_arn              = null                   # Not used in services module
  nlb_target_group_arn = local.target_group_arn # Connect to parent NLB target group
  nlb_dns_name         = null                   # Not used in services module
  namespace            = var.ddc_infra_config.unreal_cloud_ddc_namespace
  service_account      = var.ddc_infra_config.unreal_cloud_ddc_service_account_name
  service_account_arn  = module.ddc_infra.service_account_arn
  s3_bucket_id         = module.ddc_infra.s3_bucket_id

  # Database connection abstraction (from ddc_infra)
  database_connection = module.ddc_infra.database_connection

  # Legacy Scylla parameters (for backward compatibility during transition)
  scylla_ips             = module.ddc_infra.scylla_ips
  scylla_dns_name        = local.database_type == "scylla" ? "scylla.${local.private_zone_name}" : null
  scylla_datacenter_name = module.ddc_infra.scylla_datacenter_name
  scylla_keyspace_suffix = module.ddc_infra.scylla_keyspace_suffix

  # EKS Addons Configuration (from ddc-infra)
  oidc_provider_arn                   = module.ddc_infra.oidc_provider_arn
  ebs_csi_role_arn                    = module.ddc_infra.ebs_csi_role_arn
  enable_certificate_manager          = var.ddc_infra_config.enable_certificate_manager
  certificate_manager_hosted_zone_arn = var.ddc_infra_config.certificate_manager_hosted_zone_arn

  # Service Configuration
  unreal_cloud_ddc_version   = var.ddc_app_config.unreal_cloud_ddc_version
  ddc_replication_region_url = var.ddc_app_config.ddc_replication_region_url

  # Bearer token (always read from Secrets Manager - either created or existing)
  ddc_bearer_token = var.create_bearer_token == true ? aws_secretsmanager_secret_version.unreal_cloud_ddc_token[0].secret_string : (
    var.ddc_application_config.bearer_token_secret_arn != null ? data.aws_secretsmanager_secret_version.existing_token[0].secret_string : "generated-token"
  )

  # Credentials
  ghcr_credentials_secret_manager_arn = var.ddc_app_config.ghcr_credentials_secret_manager_arn
  oidc_credentials_secret_manager_arn = var.ddc_app_config.oidc_credentials_secret_manager_arn

  # ScyllaDB Configuration
  replication_factor = var.ddc_infra_config != null && var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.current_region.replication_factor : 3

  # Multi-region SSM coordination (Scylla only)
  ssm_document_name       = local.database_type == "scylla" ? module.ddc_infra.ssm_document_name : null
  scylla_seed_instance_id = local.database_type == "scylla" ? module.ddc_infra.scylla_seed_instance_id : null

  # Cleanup configuration (hardcoded - always enabled with sensible defaults)
  helm_cleanup_timeout         = 300
  auto_helm_cleanup            = true
  remove_tgb_finalizers        = true
  auto_cleanup_status_messages = true

  # Logging configuration
  log_base_prefix     = local.log_base_prefix
  ddc_logging_enabled = local.ddc_logging_enabled

  tags       = var.tags
  depends_on = [module.ddc_infra]
}
