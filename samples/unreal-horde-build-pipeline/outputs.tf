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

output "fsxn_iscsi_portals" {
  description = "Comma-separated SVM iSCSI portal addresses. Pass as -set:IscsiPortals. NOTE: the agent scripts connect exactly ONE of these unless the Windows MPIO feature is installed - two portals without MPIO make Windows enumerate a single LUN as two disks, which is a corruption trap."
  value       = local.fsxn_iscsi_portals
}

output "fsxn_workspace_lun_path" {
  description = "ONTAP path of the workspace LUN that hosts attach over iSCSI. The volume is only a container; this LUN is the thing that carries NTFS."
  value       = "/vol/${local.fsxn_source_volume_name}/${local.fsxn_lun_name}"
}

output "fsxn_hydrator_igroup" {
  description = "SINGLE-HOST igroup owning the source LUN. Never add build agents to it: NTFS has exactly one legitimate writer, so two initiators on this LUN means silent corruption."
  value       = local.fsxn_hydrator_igroup
}

output "fsxn_agent_igroup" {
  description = "Shared igroup for per-job clone LUNs. Safe to share because each clone is used by exactly one job on one agent; build agents self-register here at job time."
  value       = local.fsxn_agent_igroup
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
  value       = var.horde_p4_credentials_secret_arn
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
