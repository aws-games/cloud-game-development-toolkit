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
  value       = tolist(aws_instance.scylla_ec2_instance[*].private_ip)
  description = "IPs of the Scylla EC2 instances"
}
