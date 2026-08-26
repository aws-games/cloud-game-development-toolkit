##################################################
# Outputs — JT-12
##################################################

output "horde_server_url" {
  description = "Browser URL for the Horde server (external ALB, HTTPS). Ingress is locked to the deployer /32."
  value       = "https://${local.horde_public_fqdn}"
}

output "perforce_endpoint" {
  description = "P4PORT for client configuration (ssl:<host>:1666)."
  value       = local.perforce_endpoint
}

output "fsxn_nfs_endpoint" {
  description = "FSx for ONTAP SVM NFS DNS name (mount target for the source volume)."
  value       = aws_fsx_ontap_storage_virtual_machine.workspace.endpoints[0].nfs[0].dns_name
}

output "fsxn_source_volume_junction" {
  description = "Junction path of the FSxN source volume (mount as <nfs_endpoint>:<junction>)."
  value       = local.fsxn_source_junction_path
}

output "fsxn_management_endpoint" {
  description = "FSx for ONTAP file system management DNS name (ONTAP REST API target)."
  value       = aws_fsx_ontap_file_system.workspace.endpoints[0].management[0].dns_name
}

output "fsxn_svm_management_endpoint" {
  description = "FSx for ONTAP SVM management DNS name."
  value       = aws_fsx_ontap_storage_virtual_machine.workspace.endpoints[0].management[0].dns_name
}

output "sync_agent_launch_template_id" {
  description = "Launch template ID for the Sync Agent pool (Linux)."
  value       = module.horde.agent_launch_template_ids["sync-agent"]
}

output "build_agent_launch_template_id" {
  description = "Launch template ID for the Build Agent pool (Windows)."
  value       = module.horde.agent_launch_template_ids["build-agent"]
}

output "agent_instance_role_name" {
  description = "IAM role name attached to Horde agent instances (secrets-read policy attached in iam.tf)."
  value       = module.horde.agent_instance_role_name
}

output "horde_p4_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the Horde P4 username/password (JSON)."
  value       = local.deploy_perforce ? aws_secretsmanager_secret.horde_p4_credentials[0].arn : null
  sensitive   = true
}

output "fsxn_password_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the FSxN fsxadmin password."
  value       = aws_secretsmanager_secret.fsxn_admin.arn
  sensitive   = true
}

output "agent_config_bucket" {
  description = "S3 bucket holding agent configuration playbooks/scripts (Phase 2)."
  value       = aws_s3_bucket.agent_config.id
}
