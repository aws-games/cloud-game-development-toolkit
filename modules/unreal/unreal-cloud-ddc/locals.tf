########################################
# Local Variables
########################################
locals {
  # Naming
  name_prefix = var.ddc_infra_config != null ? "${var.project_prefix}-${var.ddc_infra_config.name}" : "${var.project_prefix}-unreal-cloud-ddc"
  

  
  # Private hosted zone name
  private_hosted_zone_name = var.route53_private_hosted_zone_name != null ? var.route53_private_hosted_zone_name : "ddc.internal"
  
  # ECR secret naming
  ecr_secret_suffix = var.ecr_secret_suffix != null ? var.ecr_secret_suffix : "${local.name_prefix}-github-credentials"
  
  # Default helm chart paths
  default_consolidated_chart = "${path.module}/assets/submodules/ddc-services/unreal_cloud_ddc_consolidated.yaml"
}