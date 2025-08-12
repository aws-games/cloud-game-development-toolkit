# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC being used"
  value       = var.vpc_id
}

output "subnets" {
  description = "The subnet IDs being used"
  value       = var.subnets
}

# Instance Outputs
output "vdi_instances" {
  description = "Map of VDI instances with their details"
  value = {
    for user, instance in aws_instance.vdi_instances : user => {
      id                = instance.id
      private_ip        = instance.private_ip
      public_ip         = instance.public_ip
      private_dns       = instance.private_dns
      public_dns        = instance.public_dns
      instance_type     = instance.instance_type
      availability_zone = instance.availability_zone
    }
  }
}

output "vdi_security_groups" {
  description = "Map of security groups for VDI instances"
  value = {
    for user, sg in aws_security_group.vdi_default_sg : user => {
      id   = sg.id
      name = sg.name
    }
  }
}

output "vdi_launch_templates" {
  description = "Map of launch templates for VDI instances"
  value = {
    for user, lt in aws_launch_template.vdi_launch_templates : user => {
      id             = lt.id
      latest_version = lt.latest_version
      name           = lt.name
    }
  }
}

output "vdi_iam_role_arn" {
  description = "The ARN of the IAM role associated with the VDI instance"
  value       = aws_iam_role.vdi_instance_role.arn
}

output "vdi_iam_role_name" {
  description = "The name of the IAM role associated with the VDI instance"
  value       = aws_iam_role.vdi_instance_role.name
}

output "vdi_iam_instance_profile_name" {
  description = "The name of the IAM instance profile associated with the VDI instance"
  value       = aws_iam_instance_profile.vdi_instance_profile.name
}

output "key_pairs" {
  description = "Map of key pairs used for VDI instances"
  value = {
    for user, config in local.processed_vdi_config : user => {
      name = config.key_pair_name != null ? config.key_pair_name : (
        config.create_key_pair ? aws_key_pair.vdi_key_pairs[user].key_name : null
      )
    }
  }
}

output "secrets_manager_secrets" {
  description = "Map of AWS Secrets Manager secrets containing credentials"
  value = {
    for user, secret in aws_secretsmanager_secret.vdi_secrets : user => {
      id   = secret.id
      name = secret.name
    }
  }
}

output "user_configurations" {
  description = "Summary of user configurations"
  value = {
    for user, config in local.processed_vdi_config : user => {
      instance_type      = config.instance_type
      join_ad            = config.join_ad
      volumes            = config.volumes
      availability_zone  = config.availability_zone
      admin_password_set = config.admin_password != null
    }
  }
  sensitive = true
}

output "ami_info" {
  description = "Information about AMIs used"
  value = {
    default_ami_id            = local.default_ami_id
    default_ami_name          = length(data.aws_ami.windows_server_2025_vdi) > 0 ? data.aws_ami.windows_server_2025_vdi[0].name : null
    default_ami_creation_date = length(data.aws_ami.windows_server_2025_vdi) > 0 ? data.aws_ami.windows_server_2025_vdi[0].creation_date : null
    user_amis = {
      for user, config in local.processed_vdi_config : user => {
        ami_id = config.ami
        source = config.ami != local.default_ami_id ? "custom" : "auto-discovered"
      }
    }
  }
}

# AD Domain Join Outputs
output "domain_join_info" {
  description = "Information about AD domain joining"
  value = {
    any_ad_join_required      = local.any_ad_join_required
    ssm_document_name         = local.any_ad_join_required ? aws_ssm_document.native_domain_join[0].name : null
    directory_id              = var.directory_id
    directory_name            = var.directory_name
    users_joining_ad = [
      for user, config in local.processed_vdi_config : user
      if config.join_ad
    ]
    ad_user_creation_method = length(local.users_joining_ad) > 0 ? "null_resource with ds-data API" : null
  }
}

# DCV Connection Information
output "dcv_connection_info" {
  description = "NICE DCV connection information for each user"
  value = {
    for user, instance in aws_instance.vdi_instances : user => {
      dcv_url               = "https://${instance.private_ip}:8443"
      rdp_address           = "${instance.private_ip}:3389"
      authentication_method = local.processed_vdi_config[user].join_ad ? "Active Directory" : "Local Windows Account"
      username_format       = local.processed_vdi_config[user].join_ad ? "${var.directory_name}\\${lower(user)}" : "Administrator"
      password_info         = local.processed_vdi_config[user].join_ad ? "Use temporary password, will be forced to change on first login" : "Stored in Secrets Manager"
      secret_name           = contains(keys(aws_secretsmanager_secret.vdi_secrets), user) ? aws_secretsmanager_secret.vdi_secrets[user].name : null
    }
  }
}

# AD User Information
output "ad_user_info" {
  description = "Active Directory user information"
  value = length(local.users_joining_ad) > 0 ? {
    domain_name = var.directory_name
    users_created = [
      for user, config in local.users_joining_ad : {
        username     = lower(user)
        display_name = "${lookup(config.tags, "given_name", user)} ${lookup(config.tags, "family_name", "User")}"
        email        = lookup(config.tags, "email", "${lower(user)}@${var.directory_name}")
        login_format = "${var.directory_name}\\${lower(user)}"
      }
    ]
    password_policy      = "Users must change temporary password on first login"
    user_creation_method = "Terraform null_resource with AWS DS-Data API"
    targeting_method     = "Direct API calls from Terraform execution environment"
  } : null
}

output "ssm_associations" {
  description = "Map of SSM associations for domain joining and configuration"
  value = {
    domain_join = {
      for user, assoc in aws_ssm_association.native_domain_join : user => {
        association_id = assoc.association_id
        name           = assoc.name
        target_type    = "VDI Instance"
      }
    }
    ad_user_creation = length(local.users_joining_ad) > 0 ? {
      method      = "Terraform null_resource with DS-Data API"
      target_type = "Terraform execution environment"
      note        = "User creation happens during terraform apply, not via SSM"
    } : null
  }
}

output "user_public_ip" {
  description = "The detected public IP address of the user for security group access"
  value = var.auto_detect_public_ip ? {
    ip_address = chomp(data.http.user_public_ip[0].response_body)
    cidr_block = local.user_public_ip_cidr
    note       = "This IP is automatically added to security groups for DCV, RDP, and HTTPS access"
    } : {
    ip_address = "Not detected (auto_detect_public_ip = false)"
    cidr_block = null
    note       = "Public IP auto-detection is disabled. Configure allowed_cidr_blocks manually."
  }
}

output "security_access_info" {
  description = "Information about security group access configuration"
  value = {
    auto_detect_enabled = var.auto_detect_public_ip
    user_public_ip      = local.user_public_ip_cidr
    allowed_ports = {
      rdp       = 3389
      dcv_https = 8443
      dcv_quic  = 8443
      https     = 443
    }
    access_note       = var.auto_detect_public_ip && local.user_public_ip_cidr != null ? "Your public IP (${local.user_public_ip_cidr}) is automatically allowed for all VDI access" : "Configure allowed_cidr_blocks in vdi_config for network access"
    additional_access = "Configure additional CIDR blocks in vdi_config.allowed_cidr_blocks if needed"
  }
}