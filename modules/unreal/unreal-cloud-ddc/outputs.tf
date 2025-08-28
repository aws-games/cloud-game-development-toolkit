########################################
# Primary Region Outputs
########################################
output "primary_region" {
  description = "Primary region information"
  value = {
    region           = local.primary_region
    eks_cluster_name = module.infrastructure_primary.cluster_name
    eks_cluster_arn  = module.infrastructure_primary.cluster_arn
    eks_endpoint     = module.infrastructure_primary.cluster_endpoint
    scylla_ips       = module.infrastructure_primary.scylla_ips
    s3_bucket_id     = module.infrastructure_primary.s3_bucket_id
    vpc_id           = var.vpc_ids.primary
  }
}

########################################
# Secondary Region Outputs (Conditional)
########################################
output "secondary_region" {
  description = "Secondary region information (if multi-region)"
  value = local.is_multi_region ? {
    region           = local.secondary_region
    eks_cluster_name = module.infrastructure_secondary[0].cluster_name
    eks_cluster_arn  = module.infrastructure_secondary[0].cluster_arn
    eks_endpoint     = module.infrastructure_secondary[0].cluster_endpoint
    scylla_ips       = module.infrastructure_secondary[0].scylla_ips
    s3_bucket_id     = module.infrastructure_secondary[0].s3_bucket_id
    vpc_id           = var.vpc_ids.secondary
  } : null
}

########################################
# Application Outputs
########################################
output "ddc_endpoints" {
  description = "DDC service endpoints for each region"
  value = {
    primary = {
      namespace         = var.application_config.unreal_cloud_ddc_namespace
      load_balancer_dns = module.applications_primary.unreal_cloud_ddc_load_balancer_name
    }
    secondary = local.is_multi_region ? {
      namespace         = var.application_config.unreal_cloud_ddc_namespace
      load_balancer_dns = module.applications_secondary[0].unreal_cloud_ddc_load_balancer_name
    } : null
  }
}

########################################
# Connection Information
########################################
output "kubectl_commands" {
  description = "kubectl commands to connect to EKS clusters"
  value = {
    primary = "aws eks update-kubeconfig --region ${local.primary_region} --name ${module.infrastructure_primary.cluster_name}"
    secondary = local.is_multi_region ? "aws eks update-kubeconfig --region ${local.secondary_region} --name ${module.infrastructure_secondary[0].cluster_name}" : null
  }
}

output "scylla_connection_info" {
  description = "ScyllaDB connection information"
  value = {
    primary = {
      region = local.primary_region
      ips    = module.infrastructure_primary.scylla_ips
    }
    secondary = local.is_multi_region ? {
      region = local.secondary_region
      ips    = module.infrastructure_secondary[0].scylla_ips
    } : null
  }
}

########################################
# Multi-Region Status
########################################
output "deployment_info" {
  description = "Deployment configuration summary"
  value = {
    is_multi_region = local.is_multi_region
    regions = local.is_multi_region ? [
      local.primary_region,
      local.secondary_region
    ] : [local.primary_region]
    project_prefix = var.infrastructure_config.project_prefix
    environment    = var.infrastructure_config.environment
  }
}