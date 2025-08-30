################################################################################
# DDC Infrastructure Outputs
################################################################################

output "ddc_infra" {
  description = "DDC infrastructure outputs"
  value = var.ddc_infra_config != null ? {
    region                = module.ddc_infra[0].region
    cluster_name          = module.ddc_infra[0].cluster_name
    cluster_endpoint      = module.ddc_infra[0].cluster_endpoint
    cluster_arn           = module.ddc_infra[0].cluster_arn
    s3_bucket_id          = module.ddc_infra[0].s3_bucket_id
    scylla_ips           = module.ddc_infra[0].scylla_ips
    scylla_seed          = module.ddc_infra[0].scylla_seed
    nlb_arn              = module.ddc_infra[0].nlb_arn
    nlb_dns_name         = module.ddc_infra[0].nlb_dns_name
    nlb_zone_id          = module.ddc_infra[0].nlb_zone_id
    nlb_target_group_arn = module.ddc_infra[0].nlb_target_group_arn
    namespace            = var.ddc_services_config != null ? module.ddc_services[0].namespace : null
    service_account      = var.ddc_services_config != null ? module.ddc_services[0].service_account : null
  } : null
}

################################################################################
# DDC Monitoring Outputs
################################################################################

output "ddc_monitoring" {
  description = "DDC monitoring outputs"
  value = var.ddc_monitoring_config != null ? {
    monitoring_instance_id       = module.ddc_monitoring[0].scylla_monitoring_instance_id
    monitoring_alb_dns_name     = module.ddc_monitoring[0].scylla_monitoring_alb_dns_name
    monitoring_alb_arn          = module.ddc_monitoring[0].scylla_monitoring_alb_arn
    monitoring_alb_zone_id      = module.ddc_monitoring[0].scylla_monitoring_alb_zone_id
    monitoring_security_group_id = module.ddc_monitoring[0].scylla_monitoring_security_group_id
  } : null
}

################################################################################
# DDC Services Outputs
################################################################################

output "ddc_services" {
  description = "DDC services outputs"
  value = var.ddc_services_config != null ? {
    helm_release_name      = module.ddc_services[0].helm_release_name
    helm_release_namespace = module.ddc_services[0].helm_release_namespace
    helm_release_version   = module.ddc_services[0].helm_release_version
    ecr_repository_url     = module.ddc_services[0].ecr_repository_url
  } : null
}

################################################################################
# DNS Outputs
################################################################################

output "private_hosted_zone" {
  description = "Private Route53 hosted zone information for DDC"
  value = var.create_route53_private_hosted_zone && var.shared_private_zone_id == null ? {
    zone_id = aws_route53_zone.ddc_private_hosted_zone[0].zone_id
    name    = aws_route53_zone.ddc_private_hosted_zone[0].name
    fqdn    = local.private_hosted_zone_name
  } : null
}

################################################################################
# Connection Information
################################################################################

output "kubectl_command" {
  description = "kubectl command to connect to EKS cluster"
  value = var.ddc_infra_config != null ? "aws eks update-kubeconfig --region ${module.ddc_infra[0].region} --name ${module.ddc_infra[0].cluster_name}" : null
}

output "scylla_connection_info" {
  description = "ScyllaDB connection information"
  value = var.ddc_infra_config != null ? {
    region = module.ddc_infra[0].region
    ips    = module.ddc_infra[0].scylla_ips
    seed   = module.ddc_infra[0].scylla_seed
  } : null
}

################################################################################
# Bearer Token Secret ARN
################################################################################

output "bearer_token_secret_arn" {
  description = "ARN of the DDC bearer token secret"
  value = var.ddc_bearer_token_secret_arn != null ? var.ddc_bearer_token_secret_arn : (var.ddc_infra_config != null ? aws_secretsmanager_secret.unreal_cloud_ddc_token[0].arn : null)
}

################################################################################
# DDC Connection Information
################################################################################

################################################################################
# DDC Connection Information
################################################################################

output "ddc_connection" {
  description = "DDC connection information for this region"
  value = var.ddc_infra_config != null ? {
    region = module.ddc_infra[0].region
    bucket = module.ddc_infra[0].s3_bucket_id
    endpoint = var.create_route53_private_hosted_zone ? "http://${local.private_hosted_zone_name}" : null
    endpoint_nlb = "http://${module.ddc_infra[0].nlb_dns_name}"
    bearer_token_secret_arn = var.ddc_bearer_token_secret_arn != null ? var.ddc_bearer_token_secret_arn : aws_secretsmanager_secret.unreal_cloud_ddc_token[0].arn
    kubectl_command = "aws eks update-kubeconfig --region ${module.ddc_infra[0].region} --name ${module.ddc_infra[0].cluster_name}"
    cluster_name = module.ddc_infra[0].cluster_name
    namespace = var.ddc_services_config != null ? module.ddc_services[0].namespace : null
    scylla_ips = module.ddc_infra[0].scylla_ips
    scylla_seed = module.ddc_infra[0].scylla_seed
    monitoring_endpoint = var.ddc_monitoring_config != null ? module.ddc_monitoring[0].scylla_monitoring_alb_dns_name : null
  } : null
}



################################################################################
# Version Information for Multi-Region Consistency
################################################################################

output "version_info" {
  description = "Version information for multi-region consistency checks"
  value = {
    kubernetes_version = var.ddc_infra_config != null ? var.ddc_infra_config.kubernetes_version : null
    ddc_version = var.ddc_services_config != null ? var.ddc_services_config.unreal_cloud_ddc_version : null
  }
}