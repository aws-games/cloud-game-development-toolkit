################################################################################
# Direct Load Balancer Outputs (for DNS records)
################################################################################

output "nlb_dns_name" {
  description = "NLB DNS name"
  value = var.ddc_infra_config != null ? aws_lb.nlb.dns_name : null
}

output "nlb_zone_id" {
  description = "NLB zone ID"
  value = var.ddc_infra_config != null ? aws_lb.nlb.zone_id : null
}

################################################################################
# DDC Infrastructure Outputs
################################################################################

output "ddc_infra" {
  description = "DDC infrastructure outputs"
  value = var.ddc_infra_config != null ? {
    region                = module.ddc_infra.region
    cluster_name          = module.ddc_infra.cluster_name
    cluster_endpoint      = module.ddc_infra.cluster_endpoint
    cluster_arn           = module.ddc_infra.cluster_arn
    cluster_certificate_authority_data = module.ddc_infra.cluster_certificate_authority_data
    s3_bucket_id          = module.ddc_infra.s3_bucket_id
    scylla_ips           = module.ddc_infra.scylla_ips
    scylla_instance_ids  = module.ddc_infra.scylla_instance_ids
    scylla_seed          = module.ddc_infra.scylla_seed
    scylla_datacenter_name = module.ddc_infra.scylla_datacenter_name
    scylla_keyspace_suffix = module.ddc_infra.scylla_keyspace_suffix
    nlb_arn              = aws_lb.nlb.arn
    nlb_dns_name         = aws_lb.nlb.dns_name
    nlb_zone_id          = aws_lb.nlb.zone_id
    nlb_target_group_arn = aws_lb_target_group.nlb_target_group.arn
  } : null
}

################################################################################
# DDC Services Outputs
################################################################################

output "ddc_services" {
  description = "DDC services outputs"
  value = var.ddc_services_config != null ? {
    helm_release_name      = module.ddc_services.helm_release_name
    helm_release_namespace = module.ddc_services.helm_release_namespace
    helm_release_version   = module.ddc_services.helm_release_version
    ecr_repository_url     = module.ddc_services.ecr_repository_url
  } : null
}

################################################################################
# DNS Outputs
################################################################################

output "dns_endpoints" {
  description = "DNS endpoints for DDC services"
  value = {
    # Private DNS (always available) - regional pattern
    private = var.ddc_infra_config != null ? {
      zone_id = aws_route53_zone.private.zone_id
      zone_name = local.private_zone_name
      regional_endpoint = "${local.region}.${local.service_name}.${local.private_zone_name}"
      scylla_cluster = "scylla.${local.private_zone_name}"
    } : null
    
    # Public DNS (when public hosted zone provided)
    public = local.public_dns_name != null ? {
      regional_endpoint = local.public_dns_name
    } : null
  }
}

# Multi-region support - shared private zone ID
output "shared_private_zone_id" {
  description = "Private hosted zone ID for cross-region DNS sharing"
  value = var.ddc_infra_config != null ? aws_route53_zone.private.zone_id : null
}

output "private_zone_name" {
  description = "Private hosted zone name"
  value = var.ddc_infra_config != null ? local.private_zone_name : null
}

################################################################################
# Connection Information
################################################################################

output "kubectl_command" {
  description = "kubectl command to connect to EKS cluster"
  value = var.ddc_infra_config != null ? "aws eks update-kubeconfig --region ${module.ddc_infra.region} --name ${module.ddc_infra.cluster_name}" : null
}

output "scylla_connection_info" {
  description = "ScyllaDB connection information"
  value = var.ddc_infra_config != null ? {
    region = module.ddc_infra.region
    ips    = module.ddc_infra.scylla_ips
    seed   = module.ddc_infra.scylla_seed
  } : null
}

################################################################################
# Bearer Token Secret ARN
################################################################################

output "bearer_token_secret_arn" {
  description = "ARN of the DDC bearer token secret"
  value = var.create_bearer_token == true ? aws_secretsmanager_secret.unreal_cloud_ddc_token[0].arn : var.ddc_application_config.bearer_token_secret_arn
}

################################################################################
# DDC Connection Information
################################################################################

output "ddc_connection" {
  description = "DDC connection information for this region"
  value = var.ddc_infra_config != null ? {
    region = module.ddc_infra.region
    bucket = module.ddc_infra.s3_bucket_id
    internet_facing = var.internet_facing

    # Private endpoints (always available) - regional pattern
    endpoint_private_dns = "${var.debug_mode == "enabled" ? "http" : "https"}://${local.region}.${local.service_name}.${local.private_zone_name}"
    
    # Public endpoint (when public hosted zone provided)
    endpoint_public_dns = local.public_dns_name != null ? "${var.existing_certificate_arn != null ? "https" : "http"}://${local.public_dns_name}" : null

    # Direct load balancer endpoints
    endpoint_nlb = "${var.debug_mode == "enabled" ? "http" : "https"}://${aws_lb.nlb.dns_name}"
    
    # Security warnings
    security_warning = local.security_warning

    # Infrastructure details
    bearer_token_secret_arn = var.create_bearer_token == true ? aws_secretsmanager_secret.unreal_cloud_ddc_token[0].arn : var.ddc_application_config.bearer_token_secret_arn
    kubectl_command = "aws eks update-kubeconfig --region ${module.ddc_infra.region} --name ${module.ddc_infra.cluster_name}"
    cluster_name = module.ddc_infra.cluster_name
    namespace = var.ddc_services_config != null ? module.ddc_services.namespace : null
    scylla_ips = module.ddc_infra.scylla_ips
    scylla_instance_ids = module.ddc_infra.scylla_instance_ids
    scylla_seed = module.ddc_infra.scylla_seed
    scylla_datacenter_name = module.ddc_infra.scylla_datacenter_name
    scylla_keyspace_suffix = module.ddc_infra.scylla_keyspace_suffix

    # DNS zone information
    private_zone_id = aws_route53_zone.private.zone_id
    private_zone_name = local.private_zone_name
  } : null
}

################################################################################
# Standardized Module Outputs
################################################################################

output "internet_facing" {
  description = "Whether load balancers are internet-facing or internal"
  value = var.internet_facing
}

output "security_groups" {
  description = "Security group IDs created by this module"
  value = {
    nlb      = var.ddc_infra_config != null ? aws_security_group.nlb[0].id : null
    internal = var.ddc_infra_config != null ? aws_security_group.internal[0].id : null
  }
}

output "load_balancers" {
  description = "Load balancer information"
  value = {
    nlb = var.ddc_infra_config != null ? {
      arn = aws_lb.nlb.arn
      dns_name = aws_lb.nlb.dns_name
      zone_id = aws_lb.nlb.zone_id
      internet_facing = var.internet_facing
      https_enabled = var.existing_certificate_arn != null
      security_warning = local.security_warning
    } : null
  }
}

output "access_logs" {
  description = "Access logs configuration"
  value = {
    centralized_logging_enabled = var.centralized_logging != null
    logs_bucket = local.any_logging_enabled ? aws_s3_bucket.logs[0].id : null
  }
}

output "module_info" {
  description = "Module metadata and configuration summary"
  value = {
    module_version = "2.0.0-standardized"
    internet_facing = var.internet_facing
    region = var.region
    vpc_id = var.existing_vpc_id
    components_enabled = {
      infrastructure = var.ddc_infra_config != null
      services = var.ddc_services_config != null
    }
    networking = {
      load_balancer_subnets = var.existing_load_balancer_subnets
      service_subnets = var.existing_service_subnets
      allowed_external_cidrs = var.allowed_external_cidrs
      external_prefix_list_id = var.external_prefix_list_id
    }
    dns = {
      route53_public_hosted_zone_name = var.existing_route53_public_hosted_zone_name
      private_zone_name = var.ddc_infra_config != null ? local.private_zone_name : null
    }
  }
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

output "scylla_configuration" {
  description = "ScyllaDB configuration details for debugging and validation"
  value = var.scylla_config != null ? {
    datacenter_name = local.scylla_config.current_datacenter
    keyspace_name   = local.scylla_config.keyspace_name
    keyspace_suffix = local.scylla_config.keyspace_suffix
    replication_factor = local.scylla_config.current_rf
    node_count = local.scylla_config.current_nodes
    is_multi_region = local.scylla_config.is_multi_region
    replication_map = local.scylla_config.replication_map
    naming_strategy = var.scylla_config.keyspace_naming_strategy
  } : null
}

output "ssm_automation" {
  description = "SSM automation configuration for keyspace fixes"
  value = {
    document_arn = var.ddc_infra_config != null ? module.ddc_infra.ssm_document_name : null
    retry_config = var.ssm_retry_config
    total_timeout_seconds = var.ssm_retry_config.initial_delay_seconds + (var.ssm_retry_config.max_attempts * var.ssm_retry_config.retry_interval_seconds)
  }
}

output "ddc_namespaces" {
  description = "DDC namespace configuration"
  value = var.ddc_application_config.namespaces
}
