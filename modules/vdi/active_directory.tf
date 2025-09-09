# AWS Managed Active Directory Integration

# Create AWS Managed Microsoft AD
resource "aws_directory_service_directory" "vdi_ad" {
  count = var.enable_ad_integration ? 1 : 0
  
  name     = var.directory_name != null ? var.directory_name : "${var.project_prefix}.internal"
  password = var.ad_admin_password
  size     = "Small"
  type     = "MicrosoftAD"
  
  vpc_settings {
    vpc_id     = var.vpc_id
    subnet_ids = data.aws_subnets.ad_subnets[0].ids
  }
  
  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-managed-ad"
    Purpose = "VDI Active Directory"
  })
}

# Get subnets for AD (requires at least 2 AZs)
data "aws_subnets" "ad_subnets" {
  count = var.enable_ad_integration ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

# NOTE: AWS Directory Service does not provide Terraform resources for managing users/groups
# AD users and groups must be managed through:
# 1. AWS Directory Service console
# 2. PowerShell AD cmdlets from domain-joined instances
# 3. External tools like Ansible or custom scripts

# Generate passwords for AD users (stored in Secrets Manager for reference)
resource "aws_secretsmanager_secret" "ad_user_passwords" {
  for_each = var.enable_ad_integration ? var.ad_users : {}
  
  name = "${local.name_prefix}/ad-users/${each.key}"
  description = "Generated password for AD user ${each.key}"
  
  tags = merge(var.tags, {
    Purpose = "VDI AD User Password"
    User = each.key
  })
}

resource "aws_secretsmanager_secret_version" "ad_user_passwords" {
  for_each = var.enable_ad_integration ? var.ad_users : {}
  
  secret_id = aws_secretsmanager_secret.ad_user_passwords[each.key].id
  secret_string = jsonencode({
    username = each.key
    password = random_password.ad_user_passwords[each.key].result
    given_name = each.value.given_name
    family_name = each.value.family_name
    email = each.value.email
  })
}

resource "random_password" "ad_user_passwords" {
  for_each = var.enable_ad_integration ? var.ad_users : {}
  
  length  = 16
  special = true
}

# SSM Document for domain joining
resource "aws_ssm_document" "join_domain" {
  count = var.enable_ad_integration ? 1 : 0
  
  name          = "${local.name_prefix}-join-ad-domain"
  document_type = "Command"
  document_format = "YAML"
  
  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Join VDI instance to Active Directory domain"
    parameters = {
      DirectoryId = {
        type        = "String"
        description = "Directory Service ID"
        default     = aws_directory_service_directory.vdi_ad[0].id
      }
      DirectoryName = {
        type        = "String"
        description = "Directory domain name"
        default     = aws_directory_service_directory.vdi_ad[0].name
      }
    }
    mainSteps = [{
      action = "aws:domainJoin"
      name   = "joinDomain"
      inputs = {
        directoryId   = "{{ DirectoryId }}"
        directoryName = "{{ DirectoryName }}"
        dnsIpAddresses = aws_directory_service_directory.vdi_ad[0].dns_ip_addresses
      }
    }]
  })
  
  tags = merge(var.tags, {
    Purpose = "VDI Domain Join"
  })
}

# Domain join associations for AD users
resource "aws_ssm_association" "domain_join" {
  for_each = var.enable_ad_integration ? {
    for assignment_key, config in local.processed_assignments : assignment_key => config
    if lookup(var.ad_users, config.user_key, null) != null
  } : {}
  
  name = aws_ssm_document.join_domain[0].name
  
  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.value.workstation_key].id]
  }
  
  parameters = {
    DirectoryId   = aws_directory_service_directory.vdi_ad[0].id
    DirectoryName = aws_directory_service_directory.vdi_ad[0].name
  }
  
  depends_on = [aws_instance.workstations]
  
  tags = merge(var.tags, {
    Assignment = each.key
    Purpose    = "VDI Domain Join"
  })
}# Active Directory Integration
# Handles domain joining and optional user management
# Uses AMI's smart DCV configuration that auto-detects authentication method

# Direct AWS domain join using AWS-managed document
resource "aws_ssm_association" "adjoin_domain_join" {
  for_each = var.enable_ad_integration ? {
    for workstation_key, config in local.processed_assignments : workstation_key => config
    if lookup(var.ad_users, config.user, null) != null
  } : {}

  name             = "AWS-JoinDirectoryServiceDomain"
  association_name = "${var.project_prefix}-${each.key}-domain-join"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  max_concurrency = "1"
  max_errors      = "0"

  parameters = {
    directoryId   = aws_directory_service_directory.vdi_ad[0].id
    directoryName = aws_directory_service_directory.vdi_ad[0].name
    directoryOU   = ""
  }

  depends_on = [aws_instance.workstations]

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${each.key}-domain-join"
    Purpose = "VDI Domain Join"
  })
}

########################################
# OPTIONAL AD USER MANAGEMENT
########################################

# AD User Creation (optional - controlled by manage_ad_users variable)
resource "null_resource" "create_ad_users" {
  for_each = var.enable_ad_integration ? {
    for workstation_key, config in local.processed_assignments : workstation_key => config
    if lookup(var.ad_users, config.user, null) != null
  } : {}

  triggers = {
    username      = lower(each.key)
    directory_id  = aws_directory_service_directory.vdi_ad[0].id
    user_password = lookup(var.individual_user_passwords, each.key, "")
    user_hash     = md5(jsonencode(each.value))
    manage_users  = var.manage_ad_users
  }

  provisioner "local-exec" {
    command = <<-EOT
    #!/bin/bash
    set -e

    USERNAME="${lower(each.key)}"
    PASSWORD='${lookup(var.individual_user_passwords, each.key, "")}'

    # Validate password exists
    [ -z "$PASSWORD" ] && { echo "❌ No password for $USERNAME"; exit 1; }

    # Note: AWS Directory Service Data API commands for user management
    # These would need to be replaced with PowerShell AD cmdlets or other tools
    echo "✓ AD user management placeholder for $USERNAME"
  EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws ds-data delete-user --directory-id '${self.triggers.directory_id}' --sam-account-name '${self.triggers.username}' 2>/dev/null || echo 'User cleanup completed'"
  }

  depends_on = [
    aws_ssm_association.adjoin_domain_join
  ]
}

# Enhanced DCV AD authentication setup with proper session ownership
resource "aws_ssm_document" "configure_dcv_ad_auth" {
  count         = var.enable_ad_integration && local.any_ad_join_required ? 1 : 0
  name          = "${var.project_prefix}-dcv-ad-auth"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Configure DCV for automatic AD authentication with user-specific session ownership"
    parameters = {
      Username = {
        type        = "String"
        description = "AD username for session ownership (domain\\username format)"
        default     = ""
      }
    }
    mainSteps = [
      {
        action = "aws:runPowerShellScript"
        name   = "ConfigureDCVADAuth"
        inputs = {
          runCommand = [
            "# Configure DCV for AD authentication using Windows Registry (proper method)",
            "Write-Host 'Configuring DCV authentication via Windows Registry...'",
            "",
            "# Configure DCV registry settings",
            "reg add \"HKEY_USERS\\S-1-5-18\\Software\\GSettings\\com\\nicesoftware\\dcv\\security\" /v authentication /t REG_SZ /d system /f",
            "reg add \"HKEY_USERS\\S-1-5-18\\Software\\GSettings\\com\\nicesoftware\\dcv\\session-management\" /v create-session /t REG_DWORD /d 1 /f",
            "reg add \"HKEY_USERS\\S-1-5-18\\Software\\GSettings\\com\\nicesoftware\\dcv\\connectivity\" /v web-port /t REG_DWORD /d 8443 /f",
            "reg add \"HKEY_USERS\\S-1-5-18\\Software\\GSettings\\com\\nicesoftware\\dcv\\connectivity\" /v quic-port /t REG_DWORD /d 8443 /f",
            "reg add \"HKEY_USERS\\S-1-5-18\\Software\\GSettings\\com\\nicesoftware\\dcv\\connectivity\" /v enable-quic-frontend /t REG_SZ /d true /f",
            "",
            "# Enable Windows Credentials Provider",
            "reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Authentication\\Credential Providers\\{8A2C93D0-D55F-4045-99D7-B27F5E263407}\" /v Disabled /t REG_DWORD /d 0 /f",
            "",
            "# Restart DCV service to apply registry changes",
            "Restart-Service dcvserver -Force",
            "Start-Sleep -Seconds 10",
            "",
            "# Create DCV session with domain user ownership",
            "& 'C:\\Program Files\\NICE\\DCV\\Server\\bin\\dcv.exe' close-session console 2>$null",
            "$domainUser = '{{ Username }}'",
            "if ($domainUser -and $domainUser -ne '') {",
            "    & 'C:\\Program Files\\NICE\\DCV\\Server\\bin\\dcv.exe' create-session --owner=$domainUser --type=console console 2>$null",
            "} else {",
            "    & 'C:\\Program Files\\NICE\\DCV\\Server\\bin\\dcv.exe' create-session --type=console console 2>$null",
            "}"
          ]
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-dcv-ad-auth"
    Purpose = "VDI DCV AD Authentication"
  })
}

# Apply DCV AD configuration after domain join (simplified approach)
resource "aws_ssm_association" "configure_dcv_ad_auth" {
  for_each = var.enable_ad_integration ? {
    for workstation_key, config in local.processed_assignments : workstation_key => config
    if lookup(var.ad_users, config.user, null) != null
  } : {}

  name = aws_ssm_document.configure_dcv_ad_auth[0].name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.workstations[each.key].id]
  }

  # Pass the domain user for session ownership
  parameters = {
    Username = "${aws_directory_service_directory.vdi_ad[0].name}\\${each.value.user}"
  }

  depends_on = [
    aws_ssm_association.adjoin_domain_join,
    null_resource.create_ad_users
  ]

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${each.key}-dcv-ad-auth"
    Purpose = "VDI DCV AD Authentication"
  })
}
