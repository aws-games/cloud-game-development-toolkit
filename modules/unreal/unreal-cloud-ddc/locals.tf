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

  # Naming with environment for uniqueness
  name_prefix = "${var.project_prefix}-${var.environment}-unreal-cloud-ddc"
  name_suffix = random_id.suffix.hex
  
  # Predictable cluster name for data source lookup
  cluster_name = "${var.project_prefix}-${var.environment}-unreal-cloud-ddc-cluster-${local.region}"

  # Predictable resource names
  nlb_name         = "${local.name_prefix}-nlb-${local.name_suffix}"
  logs_bucket_name = "${local.name_prefix}-logs-${local.name_suffix}"

  # Regional endpoint pattern with environment hierarchy
  public_dns_name = var.route53_hosted_zone_name != null ? "${local.region}.${var.environment}.${local.service_name}.${var.route53_hosted_zone_name}" : null

  # Private zone naming with environment - standardized pattern
  private_zone_name = var.route53_hosted_zone_name != null ? "${var.environment}.${local.service_name}.${var.route53_hosted_zone_name}" : "${var.environment}.${local.service_name}.internal"

  # ECR secret naming (hardcoded - no longer configurable)
  ecr_secret_suffix = "${local.name_prefix}-github-credentials"

  # Load balancer resources (conditional)
  nlb_arn          = var.load_balancers_config.nlb != null ? aws_lb.nlb[0].arn : null
  nlb_dns_name     = var.load_balancers_config.nlb != null ? aws_lb.nlb[0].dns_name : null
  nlb_zone_id      = var.load_balancers_config.nlb != null ? aws_lb.nlb[0].zone_id : null
  target_group_arn = var.load_balancers_config.nlb != null ? aws_lb_target_group.nlb_target_group[0].arn : null

  # Centralized logging configuration
  default_retention = {
    infrastructure = 90 # Longer for troubleshooting AWS services
    application    = 30 # Shorter for cost, app logs are verbose
    service        = 60 # Medium for database analysis
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
  nlb_logging_enabled    = contains(keys(local.infrastructure_logging), "nlb")
  eks_logging_enabled    = contains(keys(local.infrastructure_logging), "eks")
  ddc_logging_enabled    = contains(keys(local.application_logging), "ddc")
  scylla_logging_enabled = contains(keys(local.service_logging), "scylla")

  # Any logging enabled flag
  any_logging_enabled = length(local.infrastructure_logging) > 0 || length(local.application_logging) > 0 || length(local.service_logging) > 0

  # Centralized logging bucket
  logs_bucket_id = local.any_logging_enabled ? aws_s3_bucket.logs[0].id : null

  # Region configuration
  region = coalesce(var.region, data.aws_region.current.id)

  # VPC Endpoints configuration - Auto-enable for private/hybrid modes
  eks_requires_vpc_endpoint = var.ddc_infra_config != null && var.ddc_infra_config.eks_access_config != null && contains(["private", "hybrid"], var.ddc_infra_config.eks_access_config.mode)
  eks_uses_vpc_endpoint = local.eks_requires_vpc_endpoint || (var.vpc_endpoints != null && var.vpc_endpoints.eks != null && var.vpc_endpoints.eks.enabled)

  # Database configuration (ScyllaDB only)
  database_type = "scylla"

  # ScyllaDB configuration (when scylla_config is provided)
  scylla_config = var.ddc_infra_config != null && var.ddc_infra_config.scylla_config != null ? {
    current_datacenter = coalesce(
      var.ddc_infra_config.scylla_config.current_region.datacenter_name,
      regex("^(.+)-[0-9]+$", local.region)[0]
    )
    keyspace_suffix = coalesce(
      var.ddc_infra_config.scylla_config.current_region.keyspace_suffix,
      replace(local.region, "-", "_")
    )
    # DDC expects two keyspaces:
    global_keyspace_name = "jupiter" # Global/shared keyspace
    local_keyspace_name = "jupiter_local_ddc_${coalesce(
      var.ddc_infra_config.scylla_config.current_region.keyspace_suffix,
      replace(local.region, "-", "_")
    )}" # Region-specific local keyspace
    current_rf      = var.ddc_infra_config.scylla_config.current_region.replication_factor
    current_nodes   = var.ddc_infra_config.scylla_config.current_region.node_count
    is_multi_region = length(var.ddc_infra_config.scylla_config.peer_regions) > 0
    replication_map = {
      (coalesce(
        var.ddc_infra_config.scylla_config.current_region.datacenter_name,
        regex("^(.+)-[0-9]+$", local.region)[0]
      )) = var.ddc_infra_config.scylla_config.current_region.replication_factor
    }
    # ALTER commands for keyspace replication fix
    alter_commands = [
      "ALTER KEYSPACE jupiter_local_ddc_${coalesce(
        var.ddc_infra_config.scylla_config.current_region.keyspace_suffix,
        replace(local.region, "-", "_")
      )} WITH replication = {'class': 'NetworkTopologyStrategy', '${coalesce(
        var.ddc_infra_config.scylla_config.current_region.datacenter_name,
        regex("^(.+)-[0-9]+$", local.region)[0]
      )}': ${var.ddc_infra_config.scylla_config.current_region.replication_factor}};"
    ]
  } : null
}