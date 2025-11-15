output "cluster_name" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  description = "Name of the EKS Cluster"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.endpoint
  description = "EKS Cluster Endpoint"
}

output "eks_access_config" {
  value = {
    public_enabled  = local.eks_public_enabled
    private_enabled = local.eks_private_enabled
    public_cidrs    = local.eks_public_cidrs
    vpc_endpoint_enabled = var.eks_uses_vpc_endpoint
  }
  description = "EKS access configuration details"
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
  value       = var.is_primary_region ? aws_iam_openid_connect_provider.eks_oidc[0].arn : null
  description = "ARN of the EKS OIDC Provider"
}

output "oidc_provider_url" {
  value       = replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")
  description = "OIDC provider URL without https:// prefix (for IAM trust policies)"
}

output "cluster_certificate_authority_data" {
  value       = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.certificate_authority[0].data
  description = "Base64 encoded certificate data required to communicate with the cluster"
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
  value       = var.is_primary_region ? aws_iam_role.unreal_cloud_ddc_sa_iam_role[0].arn : null
  description = "ARN of the service account IAM role"
}

output "ebs_csi_role_arn" {
  value       = null # EKS Auto handles EBS CSI automatically
  description = "ARN of the EBS CSI driver IAM role (handled by EKS Auto)"
}

output "fluent_bit_role_arn" {
  value       = var.is_primary_region && local.ddc_logging_enabled ? aws_iam_role.fluent_bit_role[0].arn : null
  description = "ARN of the Fluent Bit IAM role for centralized logging"
}

output "cert_manager_role_arn" {
  value       = var.is_primary_region && var.enable_certificate_manager ? aws_iam_role.cert_manager_role[0].arn : null
  description = "ARN of the Cert Manager IAM role for HTTPS certificates"
}

output "aws_load_balancer_controller_role_arn" {
  value       = var.is_primary_region ? aws_iam_role.aws_load_balancer_controller_role[0].arn : null
  description = "ARN of the AWS Load Balancer Controller IAM role for NLB/ALB management"
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

################################################################################
# IAM Role ARNs for Multi-Region Sharing
################################################################################

output "eks_cluster_role_arn" {
  value       = aws_iam_role.eks_cluster_role.arn
  description = "ARN of the EKS cluster IAM role"
}

