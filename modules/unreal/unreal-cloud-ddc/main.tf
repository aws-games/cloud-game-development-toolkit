########################################
# Conditional Submodule Architecture
# Multiple parent module instances pattern - one per region
########################################

########################################
# Deployment Messages (Conditional)
########################################
resource "null_resource" "deployment_info" {
  count = var.enable_deployment_messages ? 1 : 0
  
  triggers = {
    always_run = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "🚀 UNREAL CLOUD DDC DEPLOYMENT"
      echo "📍 Region: ${var.ddc_infra_config != null ? var.ddc_infra_config.region : "N/A"}"
      echo "🗄️  ScyllaDB Nodes: ${var.ddc_infra_config != null ? var.ddc_infra_config.scylla_replication_factor : "N/A"}"
      echo "⚠️  IMPORTANT: Ensure your IP is in EKS allowlist for destroy operations!"
      echo "💡 Current IP: $(curl -s https://checkip.amazonaws.com/ || echo 'Unable to detect')"
      echo "📚 Docs: https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc"
    EOT
  }
}

resource "null_resource" "deployment_success" {
  count = var.enable_deployment_messages ? 1 : 0
  
  triggers = {
    infra_complete = var.ddc_infra_config != null ? module.ddc_infra[0].cluster_name : "none"
    services_complete = var.ddc_services_config != null ? "services-deployed" : "none"
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "✅ DEPLOYMENT COMPLETE!"
      echo "🌐 DDC URL: ${var.ddc_infra_config != null ? module.ddc_infra[0].nlb_dns_name : "N/A"}"
      echo "📊 Monitoring: ${var.ddc_monitoring_config != null ? module.ddc_monitoring[0].scylla_monitoring_alb_dns_name : "N/A"}"
      echo "🔑 Bearer Token: Check AWS Secrets Manager"
      echo ""
      echo "🧪 Test your deployment:"
      echo "   cd examples/single-region/assets/scripts && ./sanity_check.sh"
    EOT
  }
  
  depends_on = [module.ddc_infra, module.ddc_monitoring, module.ddc_services]
}

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
  debug                    = var.ddc_infra_config.debug
  vpc_id                   = var.vpc_id
  existing_security_groups = var.existing_security_groups
  is_primary_region        = var.ddc_infra_config.is_primary_region
  existing_scylla_seed     = var.ddc_infra_config.existing_scylla_seed
  scylla_source_region     = var.ddc_infra_config.scylla_source_region
  
  # ScyllaDB Configuration
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
  
  # OIDC Credentials (from services config)
  oidc_credentials_secret_manager_arn = var.ddc_services_config != null ? var.ddc_services_config.oidc_credentials_secret_manager_arn : null
  
  tags = var.tags
}

########################################
# DDC Monitoring (Conditional)
########################################
module "ddc_monitoring" {
  source = "./modules/ddc-monitoring"
  count  = var.ddc_monitoring_config != null ? 1 : 0
  
  # Pass through monitoring config
  name                     = var.ddc_monitoring_config.name
  project_prefix           = var.ddc_monitoring_config.project_prefix
  environment              = var.ddc_monitoring_config.environment
  region                   = var.ddc_infra_config != null ? module.ddc_infra[0].region : var.ddc_monitoring_config.region
  vpc_id                   = var.vpc_id
  existing_security_groups = var.existing_security_groups
  
  # ScyllaDB Configuration
  create_scylla_monitoring_stack     = var.ddc_monitoring_config.create_scylla_monitoring_stack
  scylla_monitoring_instance_type    = var.ddc_monitoring_config.scylla_monitoring_instance_type
  scylla_monitoring_instance_storage = var.ddc_monitoring_config.scylla_monitoring_instance_storage
  
  # Load Balancer Configuration
  create_application_load_balancer                    = var.ddc_monitoring_config.create_application_load_balancer
  internal_facing_application_load_balancer           = var.ddc_monitoring_config.internal_facing_application_load_balancer
  monitoring_application_load_balancer_subnets        = var.ddc_monitoring_config.monitoring_application_load_balancer_subnets
  alb_certificate_arn                                 = var.ddc_monitoring_config.alb_certificate_arn
  enable_scylla_monitoring_lb_deletion_protection     = var.ddc_monitoring_config.enable_scylla_monitoring_lb_deletion_protection
  enable_scylla_monitoring_lb_access_logs             = var.ddc_monitoring_config.enable_scylla_monitoring_lb_access_logs
  scylla_monitoring_lb_access_logs_bucket             = var.ddc_monitoring_config.scylla_monitoring_lb_access_logs_bucket
  scylla_monitoring_lb_access_logs_prefix             = var.ddc_monitoring_config.scylla_monitoring_lb_access_logs_prefix
  
  # ScyllaDB Configuration
  scylla_subnets  = var.ddc_infra_config != null ? var.ddc_infra_config.scylla_subnets : []
  scylla_node_ips = var.ddc_infra_config != null ? module.ddc_infra[0].scylla_ips : []
  
  # Additional Security Groups
  additional_alb_security_groups = var.ddc_monitoring_config.additional_alb_security_groups
  
  tags = var.tags
  depends_on = [module.ddc_infra]
}

########################################
# DDC Services (Conditional)
########################################
module "ddc_services" {
  source = "./modules/ddc-services"
  count  = var.ddc_services_config != null ? 1 : 0
  
  # Pass through services config
  name           = var.ddc_services_config.name
  project_prefix = var.ddc_services_config.project_prefix
  region         = var.ddc_infra_config != null ? module.ddc_infra[0].region : var.ddc_services_config.region
  
  # Use outputs from ddc_infra (if infra exists)
  cluster_endpoint     = var.ddc_infra_config != null ? module.ddc_infra[0].cluster_endpoint : null
  cluster_name         = var.ddc_infra_config != null ? module.ddc_infra[0].cluster_name : null
  nlb_arn              = var.ddc_infra_config != null ? module.ddc_infra[0].nlb_arn : null
  nlb_target_group_arn = var.ddc_infra_config != null ? module.ddc_infra[0].nlb_target_group_arn : null
  nlb_dns_name         = var.ddc_infra_config != null ? module.ddc_infra[0].nlb_dns_name : null
  namespace            = var.ddc_infra_config != null ? module.ddc_infra[0].namespace : null
  service_account      = var.ddc_infra_config != null ? module.ddc_infra[0].service_account : null
  s3_bucket_id         = var.ddc_infra_config != null ? module.ddc_infra[0].s3_bucket_id : null
  scylla_ips           = var.ddc_infra_config != null ? module.ddc_infra[0].scylla_ips : []
  
  # Service Configuration
  unreal_cloud_ddc_version                = var.ddc_services_config.unreal_cloud_ddc_version
  unreal_cloud_ddc_helm_base_infra_chart  = local.default_consolidated_chart
  unreal_cloud_ddc_helm_replication_chart = var.ddc_services_config.ddc_replication_region_url != null ? local.default_consolidated_chart : null
  ddc_replication_region_url              = var.ddc_services_config.ddc_replication_region_url
  
  # Bearer token
  ddc_bearer_token = data.aws_secretsmanager_secret_version.unreal_cloud_ddc_token.secret_string
  
  # Credentials
  ghcr_credentials_secret_manager_arn = var.ddc_services_config.ghcr_credentials_secret_manager_arn
  oidc_credentials_secret_manager_arn = var.ddc_services_config.oidc_credentials_secret_manager_arn
  
  # Multi-region SSM coordination
  ssm_document_name       = var.ddc_infra_config != null ? module.ddc_infra[0].ssm_document_name : null
  scylla_seed_instance_id = var.ddc_infra_config != null ? module.ddc_infra[0].scylla_seed_instance_id : null
  
  # Cleanup configuration
  helm_cleanup_timeout = var.helm_cleanup_timeout
  auto_helm_cleanup    = var.ddc_services_config.auto_cleanup
  
  tags = var.tags
  depends_on = [module.ddc_infra]
}