################################################################################
# DDC Application Outputs
################################################################################

output "helm_ddc_app_id" {
  description = "ID of the DDC deployment trigger for dependency management"
  value       = terraform_data.deploy_trigger.id
}

output "cleanup_complete_id" {
  description = "ID that signals DDC app deployment has completed (for dependency management)"
  value       = terraform_data.deploy_trigger.id
}