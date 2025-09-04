########################################
# Random ID for Predictable Naming
########################################
resource "random_id" "suffix" {
  byte_length = 1
  keepers = {
    project_prefix = var.project_prefix
    service_name   = "unreal-cloud-ddc"
  }
}

########################################
# Local Variables
########################################
locals {
  # Service name for DNS
  service_name = "ddc"
  
  # Naming with random ID pattern
  name_prefix = var.ddc_infra_config != null ? "${var.project_prefix}-${var.ddc_infra_config.name}" : "${var.project_prefix}-unreal-cloud-ddc"
  name_suffix = random_id.suffix.hex
  
  # Predictable resource names
  nlb_name = "${local.name_prefix}-nlb-${local.name_suffix}"
  logs_bucket_name = "${local.name_prefix}-logs-${local.name_suffix}"
  
  # Regional endpoint pattern for public DNS
  public_dns_name = var.existing_route53_public_hosted_zone_name != null ? "${local.region}.${local.service_name}.${var.existing_route53_public_hosted_zone_name}" : null
  
  # Private zone naming (always create) - standardized pattern
  private_zone_name = var.existing_route53_public_hosted_zone_name != null ? "${local.service_name}.${var.existing_route53_public_hosted_zone_name}" : "${local.service_name}.internal"

  # ECR secret naming
  ecr_secret_suffix = var.ecr_secret_suffix != null ? var.ecr_secret_suffix : "${local.name_prefix}-github-credentials"
  
  # Load balancer resources (always created)
  nlb_arn = aws_lb.nlb.arn
  nlb_dns_name = aws_lb.nlb.dns_name
  nlb_zone_id = aws_lb.nlb.zone_id
  target_group_arn = aws_lb_target_group.nlb_target_group.arn
  
  # Centralized logging configuration
  default_retention = {
    infrastructure = 90  # Longer for troubleshooting AWS services
    application    = 30  # Shorter for cost, app logs are verbose
    service        = 60  # Medium for database analysis
  }
  
  log_base_prefix = var.centralized_logging != null && var.centralized_logging.log_group_prefix != null ? var.centralized_logging.log_group_prefix : "${local.name_prefix}-${local.region}"
  
  # Extract enabled components with retention
  infrastructure_logging = var.centralized_logging != null ? {
    for component, config in var.centralized_logging.infrastructure :
    component => {
      enabled        = try(config.enabled, true)
      retention_days = try(config.retention_days, local.default_retention.infrastructure)
    }
    if try(config.enabled, true)
  } : {}
  
  application_logging = var.centralized_logging != null ? {
    for component, config in var.centralized_logging.application :
    component => {
      enabled        = try(config.enabled, true)
      retention_days = try(config.retention_days, local.default_retention.application)
    }
    if try(config.enabled, true)
  } : {}
  
  service_logging = var.centralized_logging != null ? {
    for component, config in var.centralized_logging.service :
    component => {
      enabled        = try(config.enabled, true)
      retention_days = try(config.retention_days, local.default_retention.service)
    }
    if try(config.enabled, true)
  } : {}
  
  # Component-specific flags
  nlb_logging_enabled = contains(keys(local.infrastructure_logging), "nlb")
  eks_logging_enabled = contains(keys(local.infrastructure_logging), "eks")
  ddc_logging_enabled = contains(keys(local.application_logging), "ddc")
  scylla_logging_enabled = contains(keys(local.service_logging), "scylla")
  
  # Any logging enabled flag
  any_logging_enabled = length(local.infrastructure_logging) > 0 || length(local.application_logging) > 0 || length(local.service_logging) > 0
  
  # Centralized logging bucket
  logs_bucket_id = local.any_logging_enabled ? aws_s3_bucket.logs[0].id : null
  
  # Region configuration
  region = coalesce(var.region, var.ddc_infra_config != null ? var.ddc_infra_config.region : "us-east-1")
  cluster_name = var.ddc_infra_config != null ? module.ddc_infra.cluster_name : null
  
  # Database configuration (controlled by migration mode and target)
  database_type = var.database_migration_mode && var.scylla_config != null && var.amazon_keyspaces_config != null ? var.database_migration_target : (
    var.amazon_keyspaces_config != null && var.scylla_config == null ? "keyspaces" : "scylla"
  )
  
  # ScyllaDB configuration (when scylla_config is provided)
  scylla_config = var.scylla_config != null ? {
    current_datacenter = coalesce(
      var.scylla_config.current_region.datacenter_name,
      regex("^(.+)-[0-9]+$", local.region)[0]
    )
    keyspace_suffix = coalesce(
      var.scylla_config.current_region.keyspace_suffix,
      replace(local.region, "-", "_")
    )
    # DDC expects two keyspaces:
    global_keyspace_name = "jupiter"  # Global/shared keyspace
    local_keyspace_name = "jupiter_local_ddc_${coalesce(
      var.scylla_config.current_region.keyspace_suffix,
      replace(local.region, "-", "_")
    )}"  # Region-specific local keyspace
    current_rf = var.scylla_config.current_region.replication_factor
    current_nodes = var.scylla_config.current_region.node_count
    is_multi_region = length(var.scylla_config.peer_regions) > 0
    replication_map = {
      (coalesce(
        var.scylla_config.current_region.datacenter_name,
        regex("^(.+)-[0-9]+$", local.region)[0]
      )) = var.scylla_config.current_region.replication_factor
    }
    alter_commands = [
      # Create global keyspace if it doesn't exist
      "CREATE KEYSPACE IF NOT EXISTS jupiter WITH replication = {'class': 'NetworkTopologyStrategy', '${coalesce(var.scylla_config.current_region.datacenter_name, regex("^(.+)-[0-9]+$", local.region)[0])}': ${var.scylla_config.current_region.replication_factor}};",
      # Drop the duplicated keyspace
      "DROP KEYSPACE IF EXISTS jupiter_local_ddc_${coalesce(var.scylla_config.current_region.keyspace_suffix, replace(local.region, "-", "_"))}_local_ddc;",
      # Progressive ALTER commands for local keyspace replication (following multi-region pattern)
      "ALTER KEYSPACE jupiter_local_ddc_${coalesce(var.scylla_config.current_region.keyspace_suffix, replace(local.region, "-", "_"))} WITH replication = {'class': 'NetworkTopologyStrategy', '${coalesce(var.scylla_config.current_region.datacenter_name, regex("^(.+)-[0-9]+$", local.region)[0])}': 0};",
      "ALTER KEYSPACE jupiter_local_ddc_${coalesce(var.scylla_config.current_region.keyspace_suffix, replace(local.region, "-", "_"))} WITH replication = {'class': 'NetworkTopologyStrategy', '${coalesce(var.scylla_config.current_region.datacenter_name, regex("^(.+)-[0-9]+$", local.region)[0])}': 1};",
      "ALTER KEYSPACE jupiter_local_ddc_${coalesce(var.scylla_config.current_region.keyspace_suffix, replace(local.region, "-", "_"))} WITH replication = {'class': 'NetworkTopologyStrategy', '${coalesce(var.scylla_config.current_region.datacenter_name, regex("^(.+)-[0-9]+$", local.region)[0])}': ${var.scylla_config.current_region.replication_factor}};"
    ]
  } : null
  
  # Amazon Keyspaces configuration (when amazon_keyspaces_config is provided)
  keyspaces_config = var.amazon_keyspaces_config != null ? {
    keyspace_names = keys(var.amazon_keyspaces_config.keyspaces)
    primary_keyspace = keys(var.amazon_keyspaces_config.keyspaces)[0]
    is_global = length([for k, v in var.amazon_keyspaces_config.keyspaces : k if v.enable_cross_region_replication]) > 0
  } : null
}