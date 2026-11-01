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

output "scylla_ips" {
  value       = tolist(concat([aws_instance.scylla_ec2_instance_seed[0].private_ip], flatten(aws_instance.scylla_ec2_instance_other_nodes[*].private_ip)))
  description = "IPs of the Scylla EC2 instances"
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

output "external_alb_dns_name" {
  value       = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? aws_lb.scylla_monitoring_alb[0].dns_name : null
  description = "DNS endpoint of Application Load Balancer (ALB)"
}

output "external_alb_zone_id" {
  value       = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? aws_lb.scylla_monitoring_alb[0].zone_id : null
  description = "Zone ID for internet facing load balancer"
}
