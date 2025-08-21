# Active Directory Integration
# Handles domain joining and optional user management
# Uses AMI's smart DCV configuration that auto-detects authentication method

# Direct AWS domain join using AWS-managed document
resource "aws_ssm_association" "domain_join" {
  for_each = {
    for user, config in var.vdi_config : user => config
    if config.join_ad && var.enable_ad_integration
  }

  name             = "AWS-JoinDirectoryServiceDomain"
  association_name = "${var.project_prefix}-${each.key}-domain-join"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.vdi_instances[each.key].id]
  }

  max_concurrency = "1"
  max_errors      = "0"

  parameters = {
    directoryId   = var.directory_id
    directoryName = var.directory_name
    directoryOU   = var.directory_ou != null ? var.directory_ou : ""
  }

  depends_on = [aws_instance.vdi_instances]

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${each.key}-domain-join"
  })
}

########################################
# OPTIONAL AD USER MANAGEMENT
########################################

# AD User Creation (optional - controlled by manage_ad_users variable)
resource "null_resource" "create_ad_users" {
  for_each = var.manage_ad_users ? {
    for user, config in var.vdi_config : user => config
    if config.join_ad && var.enable_ad_integration
  } : {}

  triggers = {
    username      = lower(each.key)
    directory_id  = var.directory_id
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

    # Create or update user
    if aws ds-data describe-user --directory-id "${var.directory_id}" --sam-account-name "$USERNAME" &>/dev/null; then
      aws ds reset-user-password --directory-id "${var.directory_id}" --user-name "$USERNAME" --new-password "$PASSWORD"
      echo "✓ Updated $USERNAME"
    else
      aws ds-data create-user --directory-id "${var.directory_id}" --sam-account-name "$USERNAME" \
        --given-name "${lookup(each.value.tags, "given_name", each.key)}" \
        --surname "${lookup(each.value.tags, "family_name", "User")}" \
        --email-address "${lookup(each.value.tags, "email", "${lower(each.key)}@${var.directory_name}")}"
      aws ds reset-user-password --directory-id "${var.directory_id}" --user-name "$USERNAME" --new-password "$PASSWORD"
      echo "✓ Created $USERNAME"
    fi

    # Add to RDP group (ignore if already member)
    aws ds-data add-group-member --directory-id "${var.directory_id}" --group-name "Remote Desktop Users" \
      --member-name "$USERNAME" --member-realm "${var.directory_name}" &>/dev/null || true
  EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws ds-data delete-user --directory-id '${self.triggers.directory_id}' --sam-account-name '${self.triggers.username}' 2>/dev/null || echo 'User cleanup completed'"
  }

  depends_on = [
    aws_ssm_association.domain_join
  ]
}

# Enhanced DCV AD authentication setup with proper session ownership
resource "aws_ssm_document" "configure_dcv_ad_auth" {
  count         = var.enable_ad_integration && anytrue([for user, config in var.vdi_config : config.join_ad]) ? 1 : 0
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
  })
}

# Apply DCV AD configuration after domain join (simplified approach)
resource "aws_ssm_association" "configure_dcv_ad_auth" {
  for_each = var.enable_ad_integration ? {
    for user, config in var.vdi_config : user => config
    if config.join_ad
  } : {}

  name = aws_ssm_document.configure_dcv_ad_auth[0].name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.vdi_instances[each.key].id]
  }

  # Pass the domain user for session ownership
  parameters = {
    Username = "${var.directory_name}\\${lower(each.key)}"
  }

  depends_on = [
    aws_ssm_association.domain_join,
    null_resource.create_ad_users
  ]

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${each.key}-dcv-ad-auth"
  })
}
