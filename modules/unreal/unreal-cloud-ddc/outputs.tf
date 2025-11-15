################################################################################
# Naming Output (for example consistency)
################################################################################

output "name_prefix" {
  description = "Standardized name prefix for consistent resource naming"
  value       = local.name_prefix
}

################################################################################
# Direct Load Balancer Outputs (for DNS records)
################################################################################

# NLB outputs removed - LoadBalancer service creates NLB dynamically
# Use External-DNS for automatic Route53 record creation instead



################################################################################
# DDC Infrastructure Outputs
################################################################################

output "ddc_infra" {
  description = "DDC infrastructure outputs"
  value = var.ddc_infra_config != null ? {
    region                             = module.ddc_infra.region
    cluster_name                       = module.ddc_infra.cluster_name
    cluster_endpoint                   = module.ddc_infra.cluster_endpoint
    cluster_arn                        = module.ddc_infra.cluster_arn
    cluster_certificate_authority_data = module.ddc_infra.cluster_certificate_authority_data
    s3_bucket_id                       = module.ddc_infra.s3_bucket_id
    scylla_ips                         = module.ddc_infra.scylla_ips
    scylla_instance_ids                = module.ddc_infra.scylla_instance_ids
    scylla_seed                        = module.ddc_infra.scylla_seed
    scylla_datacenter_name             = module.ddc_infra.scylla_datacenter_name
    scylla_keyspace_suffix             = module.ddc_infra.scylla_keyspace_suffix
    nlb_arn                            = null  # Created by LoadBalancer service
    nlb_dns_name                       = null  # Created by LoadBalancer service
    nlb_zone_id                        = null  # Created by LoadBalancer service
    nlb_target_group_arn               = null  # Created by LoadBalancer service
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
      zone_id           = aws_route53_zone.private.zone_id
      zone_name         = local.service_domain
      regional_endpoint = local.ddc_hostname
      scylla_cluster    = "scylla.${local.service_domain}"
    } : null

    # Public DNS (when public hosted zone provided)
    public = var.route53_hosted_zone_name != null ? {
      regional_endpoint = local.ddc_hostname
    } : null
  }
}

# Multi-region support - shared private zone ID
output "shared_private_zone_id" {
  description = "Private hosted zone ID for cross-region DNS sharing"
  value       = var.ddc_infra_config != null ? aws_route53_zone.private.zone_id : null
}

output "private_zone_name" {
  description = "Private hosted zone name"
  value       = var.ddc_infra_config != null ? local.service_domain : null
}

################################################################################
# Connection Information
################################################################################

output "kubectl_command" {
  description = "kubectl command to connect to EKS cluster"
  value       = var.ddc_infra_config != null ? "aws eks update-kubeconfig --region ${module.ddc_infra.region} --name ${module.ddc_infra.cluster_name}" : null
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
  value       = var.create_bearer_token == true ? aws_secretsmanager_secret.unreal_cloud_ddc_token[0].arn : (var.ddc_application_config != null ? var.ddc_application_config.bearer_token_secret_arn : null)
}

output "default_ddc_namespace" {
  description = "Default DDC logical namespace for API URLs and test scripts"
  value       = var.ddc_application_config.default_ddc_namespace
}

################################################################################
# DDC Connection Information
################################################################################

output "ddc_connection" {
  description = "DDC connection information for this region"
  value = var.ddc_infra_config != null ? {
    region          = module.ddc_infra.region
    bucket          = module.ddc_infra.s3_bucket_id
    internet_facing = var.load_balancers_config.nlb.internet_facing

    # NEW: Protocol-aware primary endpoint
    endpoint = local.ddc_endpoint
    protocol = local.ddc_protocol
    dns_name = local.ddc_hostname

    # Legacy endpoints (backward compatibility)
    endpoint_private_dns = local.ddc_endpoint
    endpoint_public_dns = var.route53_hosted_zone_name != null ? local.ddc_endpoint : null
    endpoint_nlb = null  # NLB created by LoadBalancer service, DNS available after deployment



    # Infrastructure details
    bearer_token_secret_arn = var.create_bearer_token == true ? aws_secretsmanager_secret.unreal_cloud_ddc_token[0].arn : var.ddc_application_config.bearer_token_secret_arn
    kubectl_command         = "aws eks update-kubeconfig --region ${module.ddc_infra.region} --name ${module.ddc_infra.cluster_name}"
    cluster_name            = module.ddc_infra.cluster_name
    namespace               = var.ddc_infra_config != null ? var.ddc_infra_config.kubernetes_namespace : null
    scylla_ips              = module.ddc_infra.scylla_ips
    scylla_instance_ids     = module.ddc_infra.scylla_instance_ids
    scylla_seed             = module.ddc_infra.scylla_seed
    scylla_datacenter_name  = module.ddc_infra.scylla_datacenter_name
    scylla_keyspace_suffix  = module.ddc_infra.scylla_keyspace_suffix

    # DNS zone information
    private_zone_id   = aws_route53_zone.private.zone_id
    private_zone_name = local.service_domain
  } : null
}

################################################################################
# Standardized Module Outputs
################################################################################

output "internet_facing" {
  description = "Whether load balancers are internet-facing or internal"
  value       = var.load_balancers_config.nlb != null ? var.load_balancers_config.nlb.internet_facing : false
}

output "security_groups" {
  description = "Security group IDs created by this module"
  value = {
    nlb      = var.ddc_infra_config != null ? aws_security_group.nlb[0].id : null
    internal = var.ddc_infra_config != null ? aws_security_group.internal[0].id : null
  }
}

output "load_balancers" {
  description = "Load balancer information (created by LoadBalancer service)"
  value = {
    nlb = var.load_balancers_config.nlb != null ? {
      arn              = null  # Created by LoadBalancer service
      dns_name         = null  # Created by LoadBalancer service
      zone_id          = null  # Created by LoadBalancer service
      internet_facing  = var.load_balancers_config.nlb.internet_facing
      https_enabled    = var.certificate_arn != null
    } : null
  }
}

output "access_logs" {
  description = "Access logs configuration"
  value = {
    centralized_logging_enabled = var.enable_centralized_logging
    logs_bucket                 = var.enable_centralized_logging ? aws_s3_bucket.logs[0].id : null
  }
}

output "module_info" {
  description = "Module metadata and configuration summary"
  value = {
    module_version  = "2.0.0-standardized"
    internet_facing = var.load_balancers_config.nlb.internet_facing
    region          = var.region
    vpc_id          = var.vpc_id
    components_enabled = {
      infrastructure = var.ddc_infra_config != null
      services       = var.ddc_infra_config != null
    }
    networking = {
      load_balancer_subnets   = var.load_balancers_config.nlb != null ? var.load_balancers_config.nlb.subnets : []

      allowed_external_cidrs  = var.allowed_external_cidrs
      external_prefix_list_id = var.external_prefix_list_id
    }
    dns = {
      route53_public_hosted_zone_name = var.route53_hosted_zone_name
      private_zone_name               = var.ddc_infra_config != null ? local.service_domain : null
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
    ddc_version        = "1.2.0"
  }
}



output "scylla_configuration" {
  description = "ScyllaDB configuration details for debugging and validation"
  value = var.ddc_infra_config != null && var.ddc_infra_config.scylla_config != null ? {
    datacenter_name      = local.scylla_config.current_datacenter
    local_keyspace_name  = local.scylla_config.local_keyspace_name
    global_keyspace_name = local.scylla_config.global_keyspace_name
    keyspace_suffix      = local.scylla_config.keyspace_suffix
    replication_factor   = local.scylla_config.current_rf

    is_multi_region      = local.scylla_config.is_multi_region
    replication_map      = local.scylla_config.replication_map
    naming_strategy      = var.ddc_infra_config.scylla_config.keyspace_naming_strategy
  } : null
}

output "ssm_automation" {
  description = "SSM automation configuration for keyspace fixes"
  value = {
    document_arn          = var.ddc_infra_config != null ? module.ddc_infra.ssm_document_name : null
    retry_config          = var.ssm_retry_config
    total_timeout_seconds = var.ssm_retry_config.initial_delay_seconds + (var.ssm_retry_config.max_attempts * var.ssm_retry_config.retry_interval_seconds)
  }
}

output "ddc_namespaces" {
  description = "DDC namespace configuration"
  value       = var.ddc_application_config.ddc_namespaces
}




################################################################################
# Multi-Region IAM Role Sharing
################################################################################

output "iam_roles" {
  description = "IAM role ARNs for sharing across regions"
  value = var.is_primary_region ? {
    eks_cluster_role_arn = module.ddc_infra.eks_cluster_role_arn
    # eks_node_group_role_arns removed - EKS Auto Mode manages node roles automatically
    oidc_provider_arn = module.ddc_infra.oidc_provider_arn
  } : null
}