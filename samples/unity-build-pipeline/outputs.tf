##########################################
# ECS Cluster Outputs
##########################################

output "ecs_cluster_name" {
  description = "The name of the shared ECS cluster"
  value       = aws_ecs_cluster.unity_pipeline_cluster.name
}

##########################################
# Perforce Outputs
##########################################

output "p4_server_connection_string" {
  description = "The connection string for the P4 Server. Set your P4PORT environment variable to this value."
  value       = "ssl:${local.perforce_fqdn}:1666"
}

output "p4_swarm_url" {
  description = "The URL for the P4 Swarm (Code Review) service."
  value       = "https://${local.p4_swarm_fqdn}"
}

output "perforce_super_user_password_secret_arn" {
  description = "ARN of the secret containing Perforce super user password"
  value       = module.perforce.p4_server_super_user_password_secret_arn
}

output "perforce_super_user_username_secret_arn" {
  description = "ARN of the secret containing Perforce super user username"
  value       = module.perforce.p4_server_super_user_username_secret_arn
}

##########################################
# TeamCity Outputs
##########################################

output "teamcity_url" {
  description = "The URL for the TeamCity server."
  value       = "https://${local.teamcity_fqdn}"
}

##########################################
# Unity Accelerator Outputs
##########################################

output "unity_accelerator_url" {
  description = "The URL for the Unity Accelerator dashboard."
  value       = "https://${local.unity_accelerator_fqdn}"
}

output "unity_accelerator_dashboard_username_secret_arn" {
  description = "ARN of the secret containing Unity Accelerator dashboard username"
  value       = module.unity_accelerator.unity_accelerator_dashboard_username_arn
}

output "unity_accelerator_dashboard_password_secret_arn" {
  description = "ARN of the secret containing Unity Accelerator dashboard password"
  value       = module.unity_accelerator.unity_accelerator_dashboard_password_arn
}

##########################################
# Unity License Server Outputs
##########################################

output "unity_license_server_url" {
  description = "The URL for the Unity License Server dashboard (if deployed)."
  value       = var.unity_license_server_file_path != null ? "https://${local.unity_license_fqdn}" : "Not deployed - set unity_license_server_file_path variable to deploy"
}

output "unity_license_server_dashboard_password_secret_arn" {
  description = "ARN of the secret containing Unity License Server dashboard password (if deployed)"
  value       = var.unity_license_server_file_path != null ? module.unity_license_server[0].dashboard_password_secret_arn : null
}

output "unity_license_server_services_config_url" {
  description = "Presigned URL for downloading the services-config.json file (valid for 1 hour, if deployed)"
  value       = var.unity_license_server_file_path != null ? module.unity_license_server[0].services_config_presigned_url : null
}

output "unity_license_server_registration_request_url" {
  description = "Presigned URL for downloading the server-registration-request.xml file (valid for 1 hour, if deployed)"
  value       = var.unity_license_server_file_path != null ? module.unity_license_server[0].registration_request_presigned_url : null
}
