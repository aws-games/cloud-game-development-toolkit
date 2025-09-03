################################################################################
# Local Variables
################################################################################

locals {
  # Naming consistency with other modules
  name_prefix = "${var.project_prefix}-${var.name}"

  helm_config = {
    bucket_name        = var.s3_bucket_id != null ? var.s3_bucket_id : ""
    scylla_ips         = length(var.scylla_ips) > 0 ? join(",", var.scylla_ips) : ""
    # Use improved datacenter naming from cwwalb branch
    region             = var.scylla_datacenter_name != null ? var.scylla_datacenter_name : (var.region != null ? replace(var.region, "-1", "") : "")
    aws_region         = var.region != null ? var.region : ""
    ddc_region         = var.scylla_keyspace_suffix != null ? var.scylla_keyspace_suffix : (var.region != null ? replace(var.region, "-", "_") : "")
    token              = var.ddc_bearer_token != null ? var.ddc_bearer_token : ""
    nlb_arn            = var.nlb_arn != null ? var.nlb_arn : ""
    target_group_arn   = var.nlb_target_group_arn != null ? var.nlb_target_group_arn : ""
    replication_factor = var.replication_factor
    replication_enabled = var.ddc_replication_region_url != null
  }

  base_values = var.unreal_cloud_ddc_helm_base_infra_chart != null ? [templatefile(var.unreal_cloud_ddc_helm_base_infra_chart, local.helm_config)] : [
    templatefile("${path.module}/../../assets/submodules/ddc-services/unreal_cloud_ddc_consolidated.yaml", local.helm_config)
  ]

  replication_values = var.unreal_cloud_ddc_helm_replication_chart != null ? [
    templatefile(var.unreal_cloud_ddc_helm_replication_chart, merge(local.helm_config, {
      ddc_replication_region_url = var.ddc_replication_region_url
    }))
  ] : null
}