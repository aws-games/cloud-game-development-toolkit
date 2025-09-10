# VDI Module Essential Outputs

# Instance information
output "instance_ids" {
  description = "Map of workstation instance IDs"
  value = {
    for workstation_key, instance in aws_instance.workstations : workstation_key => instance.id
  }
}

output "public_ips" {
  description = "Map of workstation public IP addresses"
  value = {
    for workstation_key, instance in aws_instance.workstations : workstation_key => instance.public_ip
  }
}

output "ami_id" {
  description = "AMI ID used for workstations"
  value = local.default_ami_id
}

# Connection information
output "connection_info" {
  description = "Complete connection information for VDI workstations"
  value = {
    for workstation_key, instance in aws_instance.workstations : workstation_key => {
      # Primary access methods
      dcv_endpoint = "https://${instance.public_ip}:8443"
      dcv_session_name = "${var.workstation_assignments[workstation_key].user}-session"
      dcv_access_note = "Shared session - admins can join, user owns session"
      
      # Admin access methods  
      rdp_endpoint = "${instance.public_ip}:3389"
      rdp_access_note = "Use for independent admin work (Administrator or VDIAdmin accounts)"
      
      # Instance details
      instance_id = instance.id
      assigned_user = var.workstation_assignments[workstation_key].user
      user_source = "local"
    }
  }
}

# Emergency access
output "private_keys" {
  description = "Private keys for emergency access (sensitive)"
  value = {
    for workstation_key, key in tls_private_key.workstation_keys : workstation_key => key.private_key_pem
  }
  sensitive = true
}

output "emergency_key_paths" {
  description = "S3 paths for emergency private keys"
  value = {
    for workstation_key, obj in aws_s3_object.emergency_private_keys : workstation_key => "s3://${obj.bucket}/${obj.key}"
  }
}

# Password retrieval
output "password_retrieval_commands" {
  description = "Commands to retrieve passwords for each workstation"
  value = {
    for workstation_key, config in local.processed_assignments : workstation_key => {
      ec2_keypair_command = "aws ec2 get-password-data --instance-id ${aws_instance.workstations[workstation_key].id} --priv-launch-key <(echo '${tls_private_key.workstation_keys[workstation_key].private_key_pem}')"
      secrets_manager_command = "aws secretsmanager get-secret-value --secret-id ${var.project_prefix}/users/${var.workstation_assignments[workstation_key].user}"
    }
  }
  sensitive = true
}

# Secrets Manager ARNs
output "secrets_manager_arns" {
  description = "Secrets Manager ARNs for user passwords"
  value = {
    for user_key, secret in aws_secretsmanager_secret.user_passwords : user_key => secret.arn
  }
}

