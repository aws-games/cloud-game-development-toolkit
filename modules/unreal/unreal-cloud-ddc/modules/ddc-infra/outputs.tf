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

output "peer_security_group_id" {
  value       = aws_security_group.scylla_security_group.id
  description = "ID of the Peer Security Group"
}

output "scylla_seed_instance_id" {
  value       = var.create_seed_node ? aws_instance.scylla_ec2_instance_seed[0].id : null
  description = "Instance ID of scylla seed node"

}

output "scylla_seed" {
  value       = var.create_seed_node ? aws_instance.scylla_ec2_instance_seed[0].private_ip : null
  description = "IP of the Scylla Seed"
}

output "scylla_ips" {
  value       = var.create_seed_node ? (concat([aws_instance.scylla_ec2_instance_seed[0].private_ip], flatten(aws_instance.scylla_ec2_instance_other_nodes[*].private_ip))) : flatten(aws_instance.scylla_ec2_instance_other_nodes[*].private_ip)
  description = "IPs of the Scylla EC2 instances"
}

output "scylla_security_group" {
  value       = aws_security_group.scylla_security_group.id
  description = "ScyllaDB security group id"

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

################################################################################
# Region Output
################################################################################

output "region" {
  value       = var.region
  description = "AWS region where resources are deployed"
}

################################################################################
# New DDC NLB Outputs (FIXES circular dependency)
################################################################################

output "nlb_arn" {
  value       = aws_lb.ddc_nlb.arn
  description = "ARN of the DDC Network Load Balancer"
}

output "nlb_dns_name" {
  value       = aws_lb.ddc_nlb.dns_name
  description = "DNS name of the DDC Network Load Balancer"
}

output "nlb_zone_id" {
  value       = aws_lb.ddc_nlb.zone_id
  description = "Zone ID of the DDC Network Load Balancer"
}

output "nlb_target_group_arn" {
  value       = aws_lb_target_group.ddc_nlb_tg.arn
  description = "ARN of the DDC NLB target group"
}

output "nlb_security_group_id" {
  value       = aws_security_group.ddc_nlb.id
  description = "ID of the DDC NLB security group"
}



################################################################################
# SSM Document Outputs
################################################################################

output "ssm_document_name" {
  value       = !var.create_seed_node ? aws_ssm_document.scylla_keyspace_update[0].name : null
  description = "Name of the SSM document for keyspace configuration"
}

output "ssm_keyspace_replication_fix_name" {
  value       = var.is_multi_region ? aws_ssm_document.scylla_keyspace_replication_fix[0].name : null
  description = "Name of the SSM document for multi-region keyspace replication fix"
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
