output "cluster_name" {
  value = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.endpoint
}

output "cluster_arn" {
  value = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.arn
}

output "s3_bucket_id" {
  value = aws_s3_bucket.unreal_ddc_s3_bucket.id
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider.arn
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.certificate_authority[0].data
}

output "peer_security_group" {
  value = aws_security_group.scylla_security_group
}
