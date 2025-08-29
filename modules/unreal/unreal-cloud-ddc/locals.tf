########################################
# Local Variables
########################################
locals {
  # Multi-region detection
  is_multi_region = var.regions != null && contains(keys(var.regions), "secondary")
  primary_region  = var.regions != null ? var.regions.primary.region : var.infrastructure_config.region
  secondary_region = local.is_multi_region ? var.regions.secondary.region : null
  
  # Naming
  name_prefix = "${var.project_prefix}-${var.infrastructure_config.name}"
  
  # DNS configuration
  private_hosted_zone_name = var.route53_private_hosted_zone_name != null ? var.route53_private_hosted_zone_name : (
    var.route53_public_hosted_zone_name != null ? "${var.ddc_subdomain}.${var.route53_public_hosted_zone_name}" : null
  )
  
  # Determine if we should create DNS resources
  create_dns_resources = var.create_route53_private_hosted_zone && local.private_hosted_zone_name != null
  
  # ECR secret naming
  ecr_secret_suffix = var.ecr_secret_suffix != null ? var.ecr_secret_suffix : "${local.name_prefix}-github-credentials"
  
  # Default helm chart paths
  default_single_region_chart = "${path.module}/assets/unreal_cloud_ddc_single_region.yaml"
  default_multi_region_chart  = "${path.module}/assets/unreal_cloud_ddc_multi_region.yaml"
}