################################################################################
# DDC Application Outputs
################################################################################

# DDC Application outputs for parent module compatibility
output "helm_release_name" {
  description = "Helm release name for DDC application"
  value       = "${local.name_prefix}-app"
}

output "helm_release_namespace" {
  description = "Kubernetes namespace for DDC application"
  value       = var.namespace
}

output "helm_release_version" {
  description = "Helm release version (content hash based)"
  value       = "direct-deployment"
}

output "deployment_status" {
  description = "DDC deployment status"
  value       = "deployed"
}

output "namespace" {
  description = "Kubernetes namespace for DDC application"
  value       = var.namespace
}