
################################################################################
# Local Variables
################################################################################

locals {
  ################################################################################
  # Basic Configuration
  ################################################################################
  tags = merge(var.tags, {
    "environment" = var.environment
  })
  name_prefix = "${var.project_prefix}-${var.name}-${var.environment}"
  namespace = var.unreal_cloud_ddc_namespace != null ? var.unreal_cloud_ddc_namespace : local.name_prefix

  ################################################################################
  # EKS Configuration
  ################################################################################
  eks_public_enabled = var.endpoint_public_access
  eks_private_enabled = var.endpoint_private_access
  eks_public_cidrs = var.public_access_cidrs
  eks_private_config = null
  # OIDC provider URL for IRSA
  oidc_provider_url = replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")

  ################################################################################
  # Logging Configuration
  ################################################################################
  log_group_prefix = var.log_group_prefix
  ddc_logging_enabled = var.enable_centralized_logging
  scylla_logging_enabled = var.enable_centralized_logging

  ################################################################################
  # Database Configuration
  ################################################################################
  database_type = var.scylla_config != null ? "scylla" : "keyspaces"
  scylla_datacenter_name = replace(var.region, "-1", "")
  scylla_keyspace_suffix = replace(var.region, "-", "_")
  keyspace_name = var.keyspace_name

  # Database connection abstraction
  database_connection = var.scylla_config != null ? {
    type = "scylla"
    host = "scylla.${var.region}.compute.internal"
    port = 9042
    auth_type = "credentials"
    keyspace_name = local.keyspace_name
    multi_region = false
  } : {
    type = "keyspaces"
    host = "cassandra.${var.region}.amazonaws.com"
    port = 9142
    auth_type = "iam"
    keyspace_name = local.keyspace_name
    multi_region = var.amazon_keyspaces_config != null ? length([for k, v in var.amazon_keyspaces_config.keyspaces : k if v.enable_cross_region_replication]) > 0 : false
  }

  ################################################################################
  # ScyllaDB Configuration
  ################################################################################
  # ScyllaDB security group rules
  sg_rules_all = [
    { port : 7000, description : "ScyllaDB Inter-node communication (RPC)", protocol : "tcp" },
    { port : 7001, description : "ScyllaDB SSL inter-node communication (RPC)", protocol : "tcp" },
    { port : 7199, description : "ScyllaDB JMX management", protocol : "tcp" },
    { port : 9042, description : "ScyllaDB CQL (native_transport_port)", protocol : "tcp" },
    { port : 9100, description : "ScyllaDB node_exporter (Optionally)", protocol : "tcp" },
    { port : 9142, description : "ScyllaDB SSL CQL (secure client to node)", protocol : "tcp" },
    { port : 9160, description : "Scylla client port (Thrift)", protocol : "tcp" },
    { port : 9180, description : "ScyllaDB Prometheus API", protocol : "tcp" },
    { port : 10000, description : "ScyllaDB REST API", protocol : "tcp" },
    { port : 19042, description : "Native shard-aware transport port", protocol : "tcp" },
    { port : 19142, description : "Native shard-aware transport port (ssl)", protocol : "tcp" }
  ]

  # ScyllaDB cluster configuration
  scylla_variables = {
    scylla-cluster-name = var.name
  }

  # ScyllaDB node IPs
  scylla_node_ips = var.scylla_config != null ? concat(
    [for instance in aws_instance.scylla_ec2_instance_seed : instance.private_ip],
    [for instance in aws_instance.scylla_ec2_instance_other_nodes : instance.private_ip],
    var.existing_scylla_ips
  ) : []
  # ScyllaDB user data configurations
  scylla_user_data_primary_node = jsonencode({
    "scylla_yaml" : {
      "cluster_name" : local.scylla_variables.scylla-cluster-name
    }
    "start_scylla_on_first_boot" : true
  })

  scylla_user_data_other_nodes = jsonencode({
    "scylla_yaml" : {
      "cluster_name" : local.scylla_variables.scylla-cluster-name,
      "seed_provider" : [{
        "parameters" : [{ "seeds" : var.create_seed_node && length(aws_instance.scylla_ec2_instance_seed) > 0 ? aws_instance.scylla_ec2_instance_seed[0].private_ip : var.existing_scylla_seed }]
      }]
    }
    "start_scylla_on_first_boot" : true
  })

  # TODO: ScyllaDB monitoring stack - commented out for now
  # Uncomment when monitoring is needed (adds Docker + Prometheus + Grafana)
  # scylla_monitoring_user_data = <<MONITORING_EOF
  # ... monitoring setup script ...
  # MONITORING_EOF

}


