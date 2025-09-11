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
  value = "AMIs specified per template - see template configurations"
}

# Connection information
output "connection_info" {
  description = "Complete connection information for VDI workstations"
  value = {
    for workstation_key, instance in aws_instance.workstations : workstation_key => {
      # IP-based endpoints (actual connectivity)
      dcv_endpoint = var.enable_private_connectivity ? "https://${instance.private_ip}:8443" : "https://${instance.public_ip}:8443"
      rdp_endpoint = var.enable_private_connectivity ? "${instance.private_ip}:3389" : "${instance.public_ip}:3389"
      
      # Custom DNS endpoints (user-friendly names)
      custom_dcv_endpoint = var.enable_private_connectivity ? "https://${var.workstation_assignments[workstation_key].user}.${var.project_prefix}.vdi.internal:8443" : null
      custom_rdp_endpoint = var.enable_private_connectivity ? "${var.workstation_assignments[workstation_key].user}.${var.project_prefix}.vdi.internal:3389" : null
      
      # Connection notes based on connectivity type
      connectivity_type = var.enable_private_connectivity ? "private" : "public"
      connection_note = var.enable_private_connectivity ? "Connect via VPN first" : "Direct internet access"
      
      # Session and access info
      dcv_session_name = "${var.workstation_assignments[workstation_key].user}-session"
      dcv_access_note = "Shared session - admins can join, user owns session"
      rdp_access_note = "Use for independent admin work (Administrator or VDIAdmin accounts)"
      
      # Instance details
      instance_id = instance.id
      assigned_user = var.workstation_assignments[workstation_key].user
      user_source = "local"
      
      # IP addresses and DNS for reference
      public_ip = instance.public_ip
      private_ip = instance.private_ip
      private_dns = instance.private_dns
      custom_dns = var.enable_private_connectivity ? "${var.workstation_assignments[workstation_key].user}.${var.project_prefix}.vdi.internal" : null
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
    for workstation_key, assignment in var.workstation_assignments : workstation_key => {
      ec2_keypair_command = "aws ec2 get-password-data --instance-id ${aws_instance.workstations[workstation_key].id} --priv-launch-key <(echo '${tls_private_key.workstation_keys[workstation_key].private_key_pem}')"
      secrets_manager_command = "aws secretsmanager get-secret-value --secret-id ${var.project_prefix}/users/${assignment.user}"
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

# Private DNS zone for cross-region associations
output "private_zone_id" {
  description = "Private hosted zone ID for creating additional VPC associations"
  value = aws_route53_zone.private.zone_id
}

output "private_zone_name" {
  description = "Private hosted zone name"
  value = aws_route53_zone.private.name
}

# VPN configuration bucket
output "vpn_configs_bucket" {
  description = "S3 bucket name for VPN configuration files"
  value = var.enable_private_connectivity ? aws_s3_bucket.vpn_configs[0].id : null
}