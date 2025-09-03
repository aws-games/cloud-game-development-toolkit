output "cluster_name" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  description = "Name of the EKS Cluster"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.endpoint
  description = "EKS Cluster Endpoint"
}

output "cluster_version" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
  description = "EKS Cluster Version"
}

output "cluster_arn" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.arn
  description = "ARN of the EKS Cluster"
}

output "s3_bucket_id" {
  value       = aws_s3_bucket.unreal_ddc_s3_bucket.id
  description = "Bucket to be used for the Unreal Cloud DDC assets"
}

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider.arn
  description = "OIDC provider for the EKS Cluster"
}

output "cluster_certificate_authority_data" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.certificate_authority[0].data
  description = "Public key for the EKS Cluster"
}

################################################################################
# Database Connection Abstraction (Primary Output)
################################################################################

output "database_connection" {
  value = local.database_connection
  description = "Database connection information for DDC services"
}

################################################################################
# Scylla-Specific Outputs (Conditional)
################################################################################

output "peer_security_group_id" {
  value       = var.scylla_config != null ? aws_security_group.scylla_security_group.id : null
  description = "ID of the Peer Security Group (Scylla only)"
}

output "scylla_seed_instance_id" {
  value       = var.scylla_config != null && var.create_seed_node && length(aws_instance.scylla_ec2_instance_seed) > 0 ? aws_instance.scylla_ec2_instance_seed[0].id : null
  description = "Instance ID of scylla seed node"
}

output "scylla_instance_ids" {
  value = var.scylla_config != null ? (
    var.create_seed_node && length(aws_instance.scylla_ec2_instance_seed) > 0 ? 
      concat([aws_instance.scylla_ec2_instance_seed[0].id], aws_instance.scylla_ec2_instance_other_nodes[*].id) : 
      aws_instance.scylla_ec2_instance_other_nodes[*].id
  ) : []
  description = "All ScyllaDB instance IDs for SSM access"
}

output "scylla_seed" {
  value       = var.scylla_config != null && var.create_seed_node && length(aws_instance.scylla_ec2_instance_seed) > 0 ? aws_instance.scylla_ec2_instance_seed[0].private_ip : null
  description = "IP of the Scylla Seed"
}

output "scylla_ips" {
  value = var.scylla_config != null ? (
    var.create_seed_node && length(aws_instance.scylla_ec2_instance_seed) > 0 ? 
      concat([aws_instance.scylla_ec2_instance_seed[0].private_ip], flatten(aws_instance.scylla_ec2_instance_other_nodes[*].private_ip)) : 
      flatten(aws_instance.scylla_ec2_instance_other_nodes[*].private_ip)
  ) : []
  description = "IPs of the Scylla EC2 instances"
}

output "scylla_security_group" {
  value       = var.scylla_config != null ? aws_security_group.scylla_security_group.id : null
  description = "ScyllaDB security group id"
}

################################################################################
# Keyspaces-Specific Outputs (Conditional)
################################################################################

output "keyspace_names" {
  value = var.amazon_keyspaces_config != null ? keys(awscc_cassandra_keyspace.keyspaces) : []
  description = "Amazon Keyspaces keyspace names"
}

output "keyspaces_tables" {
  value = var.amazon_keyspaces_config != null ? {
    for keyspace_name in keys(var.amazon_keyspaces_config.keyspaces) :
    keyspace_name => {
      cache_entries = try(aws_keyspaces_table.cache_entries_global[keyspace_name].table_name, aws_keyspaces_table.cache_entries[keyspace_name].table_name)
      s3_objects = aws_keyspaces_table.s3_objects[keyspace_name].table_name
      namespace_config = aws_keyspaces_table.namespace_config[keyspace_name].table_name
      cleanup_tracking = aws_keyspaces_table.cleanup_tracking[keyspace_name].table_name
    }
  } : {}
  description = "Amazon Keyspaces table names by keyspace"
}

output "nvme_node_group_label" {
  value       = var.nvme_node_group_label
  description = "Label for the NVME node group"
}

output "worker_node_group_label" {
  value       = var.worker_node_group_label
  description = "Label for the Worker node group"
}

output "system_node_group_label" {
  value       = var.system_node_group_label
  description = "Label for the System node group"
}

output "cluster_security_group_id" {
  value       = aws_security_group.cluster_security_group.id
  description = "ID of the EKS cluster security group"
}

################################################################################
# Region Output
################################################################################

output "region" {
  value       = var.region
  description = "AWS region where resources are deployed"
}

################################################################################
# Load Balancer Outputs Moved to Parent Module
################################################################################
# NLB outputs removed - parent module now creates and exposes load balancers



################################################################################
# SSM Document Outputs
################################################################################

output "ssm_document_name" {
  value       = var.scylla_config != null && !var.create_seed_node && length(aws_ssm_document.scylla_keyspace_update) > 0 ? aws_ssm_document.scylla_keyspace_update[0].name : null
  description = "Name of the SSM document for keyspace configuration (Scylla only)"
}

################################################################################
# Service Account IAM Role Output
################################################################################

output "service_account_arn" {
  value       = aws_iam_role.unreal_cloud_ddc_sa_iam_role.arn
  description = "ARN of the service account IAM role"
}

output "ebs_csi_role_arn" {
  value       = aws_iam_role.ebs_csi_iam_role.arn
  description = "ARN of the EBS CSI driver IAM role"
}

################################################################################
# ScyllaDB Datacenter Naming Outputs
################################################################################

output "scylla_datacenter_name" {
  value       = local.scylla_datacenter_name
  description = "ScyllaDB datacenter name (region with -1 suffix removed)"
}

output "scylla_keyspace_suffix" {
  value       = local.scylla_keyspace_suffix
  description = "ScyllaDB keyspace suffix (region with dashes replaced by underscores)"
}