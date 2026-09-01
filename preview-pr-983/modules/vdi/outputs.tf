output "public_ips" {
  description = "Map of workstation public IP addresses"
  value = {
    for workstation_key, instance in aws_instance.workstations : workstation_key => instance.public_ip
  }
}

output "ami_id" {
  description = "AMI ID used for workstations"
  value       = "AMIs specified per template - see template configurations"
}

output "connection_info" {
  description = "Complete connection information for VDI workstations"
  value = {
    for workstation_key, instance in aws_instance.workstations : workstation_key => {
      # IP-based endpoints (actual connectivity)
      dcv_endpoint = var.create_client_vpn ? "https://${instance.private_ip}:8443" : "https://${instance.public_ip}:8443"
      rdp_endpoint = var.create_client_vpn ? "${instance.private_ip}:3389" : "${instance.public_ip}:3389"

      # Custom DNS endpoints (user-friendly names) - only when DNS records exist
      custom_dcv_endpoint = contains(keys(aws_route53_record.user_dns_records), workstation_key) ? "https://${var.workstations[workstation_key].assigned_user}.${var.project_prefix}.vdi.internal:8443" : null
      custom_rdp_endpoint = contains(keys(aws_route53_record.user_dns_records), workstation_key) ? "${var.workstations[workstation_key].assigned_user}.${var.project_prefix}.vdi.internal:3389" : null

      # Session info
      dcv_session_name = "${var.workstations[workstation_key].assigned_user}-session"

      # Instance details
      instance_id         = instance.id
      assigned_user       = var.workstations[workstation_key].assigned_user
      user_source         = "local"
      secrets_manager_arn = var.workstations[workstation_key].assigned_user != null ? awscc_secretsmanager_secret.user_passwords["${workstation_key}-${var.workstations[workstation_key].assigned_user}"].id : null

      # IP addresses and DNS for reference
      public_ip   = instance.public_ip
      private_ip  = instance.private_ip
      private_dns = instance.private_dns
      custom_dns  = contains(keys(aws_route53_record.user_dns_records), workstation_key) ? "${var.workstations[workstation_key].assigned_user}.${var.project_prefix}.vdi.internal" : null
    }
  }
}

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

output "private_zone_id" {
  description = "Private hosted zone ID for creating additional VPC associations"
  value       = aws_route53_zone.private.zone_id
}

output "private_zone_name" {
  description = "Private hosted zone name"
  value       = aws_route53_zone.private.name
}

output "vpn_configs_bucket" {
  description = "S3 bucket name for VPN configuration files"
  value       = var.create_client_vpn ? aws_s3_bucket.vpn_configs[0].id : null
}
