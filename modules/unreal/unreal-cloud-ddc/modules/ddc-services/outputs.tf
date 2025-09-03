################################################################################
# DDC Services Module Outputs
################################################################################

output "helm_release_name" {
  description = "Name of the primary Helm release"
  value       = helm_release.unreal_cloud_ddc_initialization.name
}

output "helm_release_namespace" {
  description = "Namespace of the Helm release"
  value       = helm_release.unreal_cloud_ddc_initialization.namespace
}

output "helm_release_version" {
  description = "Version of the Helm release"
  value       = helm_release.unreal_cloud_ddc_initialization.version
}

output "replication_helm_release_name" {
  description = "Name of the replication Helm release"
  value       = length(helm_release.unreal_cloud_ddc_with_replication) > 0 ? helm_release.unreal_cloud_ddc_with_replication[0].name : null
}

output "ecr_repository_url" {
  description = "ECR repository URL for DDC images"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/github/epicgames"
}

################################################################################
# Kubernetes Resources Outputs
################################################################################

output "namespace" {
  value       = kubernetes_namespace.unreal_cloud_ddc.metadata[0].name
  description = "Name of the Kubernetes namespace"
}

output "service_account" {
  value       = kubernetes_service_account.unreal_cloud_ddc_service_account.metadata[0].name
  description = "Name of the Kubernetes service account"
}