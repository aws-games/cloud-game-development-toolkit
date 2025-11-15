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
  name_prefix = "${var.project_prefix}-${var.name}-${var.environment}"
  name_suffix = random_id.suffix.hex
  
  # Predictable cluster name for data source lookup
  cluster_name = local.name_prefix

  # Predictable resource names (ultra-short for AWS limits)
  nlb_name         = "${var.project_prefix}-ddc-${var.environment}-nlb-${local.name_suffix}"
  logs_bucket_name = "${var.project_prefix}-ddc-${var.environment}-logs-${local.name_suffix}"

  # DNS Configuration
  # 
  # IMPORTANT: Like subnets (public/private determined by IGW routes), 
  # DNS hostnames are public/private based on which Route53 zones contain records.
  # The hostname itself doesn't determine accessibility - the DNS records do!
  #
  # Service domain (determines hostname structure):
  # - If public hosted zone EXISTS and is SUPPLIED to module (route53_hosted_zone_name = "example.com"):
  #   * service_domain = "dev.ddc.example.com" (enables split-horizon DNS)
  #   * Module creates: Private zone "dev.ddc.example.com" with private records
  #   * Examples create: Public records in existing public zone "example.com"
  #   * Result: Same hostname resolves from internet AND VPC (split-horizon)
  #
  # - If public hosted zone does NOT exist or is NOT SUPPLIED to module (route53_hosted_zone_name = null):
  #   * service_domain = "dev.ddc.cgd.internal" (pure internal DNS)
  #   * Module creates: Private zone "dev.ddc.cgd.internal" with private records
  #   * No public records created anywhere
  #   * Result: Hostname only resolves from VPC (pure internal)
  #
  # The ".internal" suffix makes it obvious it's internal-only.
  # The ".example.com" structure enables split-horizon (same name, different resolution).
  service_domain = var.route53_hosted_zone_name != null ? "${var.environment}.ddc.${var.route53_hosted_zone_name}" : "${var.environment}.ddc.${var.project_prefix}.internal"
  
  # DDC hostname (regional endpoint)
  ddc_hostname = "${local.region}.${local.service_domain}"
  
  # DDC protocol (certificate-based detection)
  # 
  # Protocol is independent of DNS strategy - determined solely by certificate presence:
  # - certificate_arn provided → HTTPS (certificate must be from ACM or Private CA)
  # - certificate_arn = null → HTTP (suitable for trusted internal networks)
  #
  # Certificate Options:
  # - ACM Public Certificate: For public domains (.example.com) with DNS validation
  # - AWS Private CA Certificate: For internal domains (.cgd.internal) or private validation
  # - Self-signed certificates: Not supported (may cause application failures)
  #
  # Examples:
  # - Split-horizon + HTTPS: https://us-east-1.dev.ddc.example.com (ACM public cert)
  # - Split-horizon + HTTP: http://us-east-1.dev.ddc.example.com (no cert, debug only)
  # - Internal + HTTPS: https://us-east-1.dev.ddc.cgd.internal (AWS Private CA cert)
  # - Internal + HTTP: http://us-east-1.dev.ddc.cgd.internal (no cert, trusted internal networks only)
  ddc_protocol = var.certificate_arn != null ? "https" : "http"
  
  # DDC endpoint (complete URL)
  ddc_endpoint = "${local.ddc_protocol}://${local.ddc_hostname}"

  # ECR secret naming (hardcoded - no longer configurable)
  ecr_secret_suffix = "${local.name_prefix}-github-credentials"

  # Load balancer resources - handled by LoadBalancer service + AWS Load Balancer Controller
  nlb_arn          = null  # Created automatically by LoadBalancer service
  nlb_dns_name     = local.ddc_hostname  # Use Route53 DNS name for health checks
  nlb_zone_id      = null  # Available after LoadBalancer service deployment
  target_group_arn = null  # Created automatically by LoadBalancer service

  # Standardized log group naming: /cgd/{module-name}
  log_prefix = var.log_group_prefix != "" ? var.log_group_prefix : "/${var.project_prefix}/unreal-cloud-ddc"

  # Standardized tags for all resources
  default_tags = merge(var.tags, {
    Environment = var.environment
  })

  # Centralized logging bucket
  logs_bucket_id = var.enable_centralized_logging ? aws_s3_bucket.logs[0].id : null

  # Region configuration
  region = coalesce(var.region, data.aws_region.current.id)



  # Database configuration (ScyllaDB only)
  database_type = "scylla"

  # Multi-region replication map for global keyspace (separate to avoid self-reference)
  scylla_global_replication_map = var.ddc_infra_config != null && var.ddc_infra_config.scylla_config != null ? (
    var.ddc_infra_config.scylla_config.peer_regions != null && length(var.ddc_infra_config.scylla_config.peer_regions) > 0 ? merge(
      {
        (coalesce(
          var.ddc_infra_config.scylla_config.current_region.datacenter_name,
          regex("^(.+)-[0-9]+$", local.region)[0]
        )) = var.ddc_infra_config.scylla_config.current_region.replication_factor
      },
      {
        for region_config in var.ddc_infra_config.scylla_config.peer_regions :
        region_config.datacenter_name => region_config.replication_factor
      }
    ) : {
      (coalesce(
        var.ddc_infra_config.scylla_config.current_region.datacenter_name,
        regex("^(.+)-[0-9]+$", local.region)[0]
      )) = var.ddc_infra_config.scylla_config.current_region.replication_factor
    }
  ) : {}





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
    datacenter_name = coalesce(
      var.ddc_infra_config.scylla_config.current_region.datacenter_name,
      regex("^(.+)-[0-9]+$", local.region)[0]
    )
    
    # DDC expects two keyspaces:
    global_keyspace_name = "${var.project_prefix}_${var.environment}_global_ddc" # Global/shared keyspace
    local_keyspace_name = "${var.project_prefix}_${var.environment}_local_ddc_${coalesce(
      var.ddc_infra_config.scylla_config.current_region.keyspace_suffix,
      replace(local.region, "-", "_")
    )}" # Region-specific local keyspace
    current_rf      = var.ddc_infra_config.scylla_config.current_region.replication_factor
    current_nodes   = var.ddc_infra_config.scylla_config.current_region.replication_factor
    is_multi_region = var.ddc_infra_config.scylla_config.peer_regions != null && length(var.ddc_infra_config.scylla_config.peer_regions) > 0
    
    global_replication_map = local.scylla_global_replication_map
    
    replication_map = {
      (coalesce(
        var.ddc_infra_config.scylla_config.current_region.datacenter_name,
        regex("^(.+)-[0-9]+$", local.region)[0]
      )) = var.ddc_infra_config.scylla_config.current_region.replication_factor
    }
    
    # ALTER commands for keyspace replication fix - both local and global
    alter_commands = concat(
      [
        # Local keyspace - single region replication
        "ALTER KEYSPACE ${var.project_prefix}_${var.environment}_local_ddc_${coalesce(
          var.ddc_infra_config.scylla_config.current_region.keyspace_suffix,
          replace(local.region, "-", "_")
        )} WITH replication = {'class': 'NetworkTopologyStrategy', '${coalesce(
          var.ddc_infra_config.scylla_config.current_region.datacenter_name,
          regex("^(.+)-[0-9]+$", local.region)[0]
        )}': ${var.ddc_infra_config.scylla_config.current_region.replication_factor}};"
      ],
      [
        # Global keyspace - multi-region replication
        "ALTER KEYSPACE ${var.project_prefix}_${var.environment}_global_ddc WITH replication = {'class': 'NetworkTopologyStrategy', ${join(", ", [
          for dc, rf in local.scylla_global_replication_map : "'${dc}': ${rf}"
        ])}};"
      ]
    )
  } : null
}