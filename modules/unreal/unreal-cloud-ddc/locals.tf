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
  
  # Region configuration
  region = coalesce(var.region, var.ddc_infra_config != null ? var.ddc_infra_config.region : "us-east-1")
  cluster_name = var.ddc_infra_config != null ? module.ddc_infra[0].cluster_name : null
  
  # Simple ScyllaDB configuration for compatibility
  scylla_config = {
    current_datacenter = coalesce(
      var.scylla_topology_config.current_region.datacenter_name,
      regex("^(.+)-[0-9]+$", local.region)[0]
    )
    keyspace_suffix = coalesce(
      var.scylla_topology_config.current_region.keyspace_suffix,
      replace(local.region, "-", "_")
    )
    keyspace_name = "jupiter_local_ddc_${coalesce(
      var.scylla_topology_config.current_region.keyspace_suffix,
      replace(local.region, "-", "_")
    )}"
    current_rf = var.scylla_topology_config.current_region.replication_factor
    current_nodes = var.scylla_topology_config.current_region.node_count
    is_multi_region = length(var.scylla_topology_config.peer_regions) > 0
    replication_map = {
      (coalesce(
        var.scylla_topology_config.current_region.datacenter_name,
        regex("^(.+)-[0-9]+$", local.region)[0]
      )) = var.scylla_topology_config.current_region.replication_factor
    }
    alter_commands = ["-- Simplified for now"]
  }
}