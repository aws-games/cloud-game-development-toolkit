########################################
# Local Variables
########################################
locals {
  # Access method logic
  is_external_access = contains(["external", "public"], var.access_method)
  
  # Naming
  name_prefix = var.ddc_infra_config != null ? "${var.project_prefix}-${var.ddc_infra_config.name}" : "${var.project_prefix}-unreal-cloud-ddc"
  
  # Dynamic private zone naming based on access method (following design standards)
  private_zone_name = local.is_external_access ? "ddc.${var.route53_public_hosted_zone_name != null ? var.route53_public_hosted_zone_name : "example.com"}" : "ddc.internal"

  # ECR secret naming
  ecr_secret_suffix = var.ecr_secret_suffix != null ? var.ecr_secret_suffix : "${local.name_prefix}-github-credentials"
  
  # Load balancer resources (always created)
  nlb_arn = aws_lb.shared_nlb.arn
  nlb_dns_name = aws_lb.shared_nlb.dns_name
  nlb_zone_id = aws_lb.shared_nlb.zone_id
  target_group_arn = aws_lb_target_group.shared_nlb_tg.arn
  
  # Centralized logging bucket (always create our own)
  logs_bucket_id = var.enable_centralized_logging ? aws_s3_bucket.ddc_logs[0].id : null
  
  # Default helm chart paths
  default_consolidated_chart = "${path.module}/assets/submodules/ddc-services/unreal_cloud_ddc_consolidated.yaml"
}