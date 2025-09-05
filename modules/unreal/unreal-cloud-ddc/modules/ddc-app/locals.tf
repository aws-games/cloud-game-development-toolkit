################################################################################
# Local Variables
################################################################################

locals {
  # Naming consistency with other modules
  name_prefix = "${var.project_prefix}-${var.name}"

  # Logging configuration from parent module
  log_base_prefix = var.log_base_prefix
  ddc_logging_enabled = var.ddc_logging_enabled

  # Database connection abstraction (supports both Scylla and Keyspaces)
  database_connection_string = var.database_connection.type == "scylla" ? (
    var.scylla_dns_name != null && var.scylla_dns_name != "" ? var.scylla_dns_name : (
      length(var.scylla_ips) > 0 ? join(",", var.scylla_ips) : var.database_connection.host
    )
  ) : var.database_connection.host

  helm_config = {
    bucket_name        = var.s3_bucket_id != null ? var.s3_bucket_id : ""

    # Database configuration (unified for both Scylla and Keyspaces)
    database_type      = var.database_connection.type
    database_host      = local.database_connection_string
    database_port      = var.database_connection.port
    database_auth_type = var.database_connection.auth_type
    keyspace_name      = var.database_connection.keyspace_name

    # Legacy Scylla fields (for backward compatibility)
    scylla_connection  = local.database_connection_string
    region             = var.scylla_datacenter_name != null ? var.scylla_datacenter_name : (var.region != null ? replace(var.region, "-1", "") : "")
    ddc_region         = var.scylla_keyspace_suffix != null ? var.scylla_keyspace_suffix : (var.region != null ? replace(var.region, "-", "_") : "")
    replication_factor = var.replication_factor

    # Keyspaces credentials (for service-specific auth)
    keyspaces_username = var.database_connection.type == "keyspaces" ? "" : ""
    keyspaces_password = var.database_connection.type == "keyspaces" ? "" : ""

    # Common configuration
    aws_region         = var.region != null ? var.region : ""
    token              = var.ddc_bearer_token != null ? var.ddc_bearer_token : ""
    nlb_arn            = var.nlb_arn != null ? var.nlb_arn : ""
    target_group_arn   = var.nlb_target_group_arn != null ? var.nlb_target_group_arn : ""
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
