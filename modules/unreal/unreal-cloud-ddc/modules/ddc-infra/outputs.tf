################################################################################
# EKS Core Outputs (Primary Infrastructure)
################################################################################

output "cluster_name" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  description = "Name of the EKS Cluster"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.endpoint
  description = "EKS Cluster Endpoint"
}

output "cluster_arn" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.arn
  description = "ARN of the EKS Cluster"
}

output "cluster_certificate_authority_data" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.certificate_authority[0].data
  description = "Base64 encoded certificate data required to communicate with the cluster"
}

output "cluster_security_group_id" {
  value       = aws_security_group.cluster_security_group.id
  description = "ID of the EKS cluster security group"
}

output "oidc_provider_arn" {
  value       = var.is_primary_region ? aws_iam_openid_connect_provider.eks_oidc[0].arn : null
  description = "ARN of the EKS OIDC Provider"
}

################################################################################
# S3 Storage Outputs
################################################################################

output "s3_bucket_id" {
  value       = aws_s3_bucket.unreal_ddc_s3_bucket.id
  description = "Bucket to be used for the Unreal Cloud DDC assets"
}

################################################################################
# IAM Role Outputs (Infrastructure Services)
################################################################################

output "service_account_arn" {
  value       = var.is_primary_region ? aws_iam_role.unreal_cloud_ddc_sa_iam_role[0].arn : null
  description = "ARN of the service account IAM role"
}

output "eks_cluster_role_arn" {
  value       = aws_iam_role.eks_cluster_role.arn
  description = "ARN of the EKS cluster IAM role"
}

################################################################################
# Database Connection (Application Integration)
################################################################################

output "database_connection" {
  value       = local.database_connection
  description = "Database connection information for DDC services"
}

################################################################################
# ScyllaDB Outputs (Optional Component)
################################################################################

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

output "scylla_datacenter_name" {
  value       = local.scylla_datacenter_name
  description = "ScyllaDB datacenter name (region with -1 suffix removed)"
}

output "scylla_keyspace_suffix" {
  value       = local.scylla_keyspace_suffix
  description = "ScyllaDB keyspace suffix (region with dashes replaced by underscores)"
}

################################################################################
# Operational Outputs (SSM, Region)
################################################################################

output "ssm_document_name" {
  value       = var.scylla_config != null && !var.create_seed_node && length(aws_ssm_document.scylla_keyspace_update) > 0 ? aws_ssm_document.scylla_keyspace_update[0].name : null
  description = "Name of the SSM document for keyspace configuration (Scylla only)"
}

output "region" {
  value       = var.region
  description = "AWS region where resources are deployed"
}

