# ================
# CORE VDI OUTPUTS
# ================

# VDI Instance Connection Information
output "vdi_instances" {
  description = "VDI instance connection information"
  value = {
    for user in keys(module.vdi.instance_ids) : user => {
      instance_id = module.vdi.instance_ids[user]
      public_ip   = module.vdi.public_ips[user]
      private_ip  = module.vdi.private_ips[user]
      dcv_url     = "https://${module.vdi.public_ips[user]}:8443"
      rdp_address = module.vdi.public_ips[user]
      username    = "${local.directory_name}\\${lower(user)}"
    }
  }
}

# Consolidated Secrets
output "secrets" {
  description = "Consolidated secrets for VDI access"
  value = {
    user_credentials  = aws_secretsmanager_secret.vdi_user_credentials.name
    admin_credentials = aws_secretsmanager_secret.vdi_admin_credentials.name
  }
}

# Quick Access Commands
output "access_commands" {
  description = "Commands to retrieve credentials and access VDI"
  value = {
    list_users         = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.vdi_user_credentials.name} --query 'SecretString' --output text | jq -r 'keys[] | select(endswith(\"_ad_login\"))' | sed 's/_ad_login//'"
    get_user_password  = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.vdi_user_credentials.name} --query 'SecretString' --output text | jq -r '.USERNAME_ad_password'"
    get_user_login     = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.vdi_user_credentials.name} --query 'SecretString' --output text | jq -r '.USERNAME_ad_login'"
    get_admin_password = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.vdi_admin_credentials.name} --query 'SecretString' --output text | jq -r '.ad_admin_password'"
  }
}

# Directory Information
output "directory_info" {
  description = "Active Directory connection information"
  value = {
    directory_id   = aws_directory_service_directory.managed_ad.id
    directory_name = local.directory_name
    dns_ips        = aws_directory_service_directory.managed_ad.dns_ip_addresses
  }
}
