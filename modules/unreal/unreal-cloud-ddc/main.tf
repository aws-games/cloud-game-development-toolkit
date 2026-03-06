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
  name           = var.name
  project_prefix = var.project_prefix
  environment    = var.environment
  region         = local.region
  debug          = var.debug_mode == "enabled"
  vpc_id         = var.vpc_id


  # Security groups now embedded in load_balancers_config and direct EKS variables

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



  # EKS Access Configuration (direct AWS provider mapping)
  endpoint_public_access  = var.ddc_infra_config.endpoint_public_access
  endpoint_private_access = var.ddc_infra_config.endpoint_private_access
  public_access_cidrs     = var.ddc_infra_config.public_access_cidrs

  # EKS Auto Mode - Node groups managed automatically

  # Kubernetes Configuration
  unreal_cloud_ddc_namespace            = var.ddc_infra_config.kubernetes_namespace
  unreal_cloud_ddc_service_account_name = var.ddc_infra_config.kubernetes_service_account_name

  # Certificate Management
  certificate_manager_hosted_zone_arn = var.ddc_infra_config.certificate_manager_hosted_zone_arn
  enable_certificate_manager          = var.ddc_infra_config.enable_certificate_manager

  # Additional Security Groups


  # Multi-region monitoring (empty for single region)
  scylla_ips_by_region = {}

  # OIDC Credentials (from services config)
  oidc_credentials_secret_manager_arn = null

  # Logging configuration
  enable_centralized_logging = var.enable_centralized_logging
  log_group_prefix          = local.log_prefix
  log_retention_days        = var.log_retention_days


  # Multi-region configuration
  is_primary_region = var.is_primary_region

  # EKS access entries
  eks_access_entries = var.eks_access_entries

  # Route53 configuration for External-DNS
  route53_hosted_zone_name = var.route53_hosted_zone_name
  private_zone_id          = aws_route53_zone.private.zone_id

  # EKS VPC endpoint configuration
  eks_uses_vpc_endpoint = false  # Not using VPC endpoints

  tags = local.default_tags
}


########################################
# DDC Services (Conditional - only when application config provided)
########################################
module "ddc_app" {
  count  = var.ddc_application_config != null ? 1 : 0
  source = "./modules/ddc-app"

  # No providers needed - using local-exec with Helm CLI
  # Pass through services config
  name           = var.name
  project_prefix = var.project_prefix
  environment    = var.environment
  region         = local.region

  # Use outputs from ddc_infra
  cluster_name        = module.ddc_infra.cluster_name
  kubernetes_version  = var.ddc_infra_config.kubernetes_version
  nlb_dns_name        = local.nlb_dns_name
  namespace           = var.ddc_infra_config.kubernetes_namespace
  service_account_arn = module.ddc_infra.service_account_arn
  s3_bucket_id        = module.ddc_infra.s3_bucket_id

  # Database connection abstraction (from ddc_infra)
  database_connection = module.ddc_infra.database_connection

  # Legacy Scylla parameters (for backward compatibility during transition)
  scylla_ips             = module.ddc_infra.scylla_ips
  scylla_dns_name        = local.database_type == "scylla" ? "scylla.${local.service_domain}" : null
  scylla_datacenter_name = module.ddc_infra.scylla_datacenter_name
  scylla_keyspace_suffix = module.ddc_infra.scylla_keyspace_suffix

  # EKS addons are handled in ddc-infra module

  # DDC endpoint pattern for replication
  ddc_endpoint_pattern = local.ddc_hostname

  # Bearer token (always read from Secrets Manager - either created or existing)
  ddc_bearer_token = var.create_bearer_token == true ? aws_secretsmanager_secret_version.unreal_cloud_ddc_token[0].secret_string : (
    var.ddc_application_config != null && var.ddc_application_config.bearer_token_secret_arn != null ? data.aws_secretsmanager_secret_version.existing_token[0].secret_string : "generated-token"
  )

  # Bearer token secret ARN for CodeBuild testing
  bearer_token_secret_arn = var.create_bearer_token == true ? aws_secretsmanager_secret.unreal_cloud_ddc_token[0].arn : (
    var.ddc_application_config != null ? var.ddc_application_config.bearer_token_secret_arn : null
  )

  # Credentials
  ghcr_credentials_secret_arn = var.ghcr_credentials_secret_arn

  # ScyllaDB Configuration
  replication_factor = var.ddc_infra_config != null && var.ddc_infra_config.scylla_config != null ? var.ddc_infra_config.scylla_config.current_region.replication_factor : 3

  # Multi-region SSM coordination (Scylla only)
  ssm_document_name       = local.database_type == "scylla" ? module.ddc_infra.ssm_document_name : null
  scylla_seed_instance_id = local.database_type == "scylla" ? module.ddc_infra.scylla_seed_instance_id : null

  # Logging configuration
  enable_centralized_logging = var.enable_centralized_logging
  log_group_prefix          = local.log_prefix
  log_retention_days        = var.log_retention_days

  # Application configuration
  ddc_application_config          = var.ddc_application_config
  kubernetes_service_account_name = var.ddc_infra_config.kubernetes_service_account_name


  # Debug configuration
  force_codebuild_run = var.force_codebuild_run

  # VPC configuration
  vpc_id = var.vpc_id
  subnets = var.ddc_infra_config.eks_node_group_subnets
  eks_node_group_subnets = var.ddc_infra_config.eks_node_group_subnets
  cluster_security_group_id = module.ddc_infra.cluster_security_group_id

  # DNS endpoint for testing
  ddc_dns_endpoint = local.ddc_endpoint

  # Certificate configuration
  certificate_arn = var.certificate_arn

  # Load balancer configuration
  load_balancers_config = var.load_balancers_config

  # Security group for explicit lifecycle management
  nlb_security_group_id = var.ddc_infra_config != null ? aws_security_group.nlb[0].id : null

  # DNS zone IDs for External-DNS configuration
  private_zone_id = aws_route53_zone.private.zone_id
  public_zone_id  = var.route53_hosted_zone_name != null ? data.aws_route53_zone.public[0].zone_id : null

  tags       = local.default_tags
  depends_on = [module.ddc_infra]
}




