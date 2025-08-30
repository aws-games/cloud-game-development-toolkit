################################################################################
# Local Variables
################################################################################

locals {
  # Naming consistency with other modules
  name_prefix = "${var.project_prefix}-${var.name}"

  helm_config = {
    bucket_name      = var.s3_bucket_id
    scylla_ips       = join(",", var.scylla_ips)
    region           = var.region
    aws_region       = var.region
    token            = var.ddc_bearer_token
    nlb_arn          = var.nlb_arn
    target_group_arn = var.nlb_target_group_arn
  }

  base_values = var.unreal_cloud_ddc_helm_base_infra_chart != null ? [templatefile(var.unreal_cloud_ddc_helm_base_infra_chart, local.helm_config)] : []

  replication_values = var.unreal_cloud_ddc_helm_replication_chart != null ? [
    templatefile(var.unreal_cloud_ddc_helm_replication_chart, merge(local.helm_config, {
      ddc_replication_region_url = var.ddc_replication_region_url
    }))
  ] : null
}
